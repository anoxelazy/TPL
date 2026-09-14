import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:claim/page/tracking/models.dart';

/// ค่า Authorization ที่ส่งไปกับทุก request
///
/// เปลี่ยนได้ตอน build ด้วย `flutter run --dart-define=TRACKING_API_KEY=...`
/// โดยไม่ต้องแก้ไฟล์นี้ ค่า default คือคีย์ที่ใช้งานได้จริงตอนนี้
///
/// ⚠️ กับดักที่ต้องรู้: **คีย์ผิดกับเลขพัสดุผิดตอบข้อความเดียวกัน**
/// - ไม่ส่ง header เลย → `unknow client` (แยกออก)
/// - ส่งคีย์ผิด → `Unknow DocumentNumber` (แยกไม่ออกจากเลขพัสดุผิด)
///
/// แปลว่าวันที่คีย์ถูกเปลี่ยนฝั่งเซิร์ฟเวอร์ ผู้ใช้จะเห็นแค่ "ไม่พบข้อมูลพัสดุ"
/// ทุกใบที่ค้น โดยไม่มีอะไรบอกว่าปัญหาคือคีย์ ถ้าเจออาการนั้นให้มาตรวจที่นี่ก่อน
///
/// คีย์ยังตรงตัวพิมพ์ด้วย (`XXX` ใช้ไม่ได้) และเป็นค่าที่เดาง่ายมาก
/// ควรผลักให้ทีม backend เปลี่ยนเป็นคีย์จริงจังเมื่อมีโอกาส
const String trackingApiKey = String.fromEnvironment(
  'TRACKING_API_KEY',
  defaultValue: 'xxx',
);

const String _endpoint = 'https://tpapi.azurewebsites.net/tracking.aspx';

/// รอไม่เกิน 15 วิ พอสำหรับ cold start ของ Azure โดยที่ผู้ใช้ยังไม่เลิกรอ
const Duration _timeout = Duration(seconds: 15);

/// ประเภทเลขที่ใช้ค้น ตรงกับพารามิเตอร์ `type` ของ API
///
/// ลำดับใน enum คือลำดับที่ [fetchTracking] ไล่ลอง จึงเรียงจากแบบที่คนกรอก
/// บ่อยที่สุดก่อน เพื่อให้กรณีปกติจบในรอบเดียว
enum TrackingType {
  /// เลขพัสดุของ Thai Parcels
  tp('tp'),

  /// เลข tracking ของร้านค้า
  tk('tk');

  final String value;

  const TrackingType(this.value);
}

/// ข้อผิดพลาดที่แสดงให้ผู้ใช้อ่านได้ตรง ๆ
class TrackingException implements Exception {
  final String message;

  /// true เมื่อเซิร์ฟเวอร์บอกว่าไม่พบพัสดุ หน้าจอจะโชว์ empty state
  /// แทนหน้า error ที่มีปุ่มลองใหม่ เพราะกดซ้ำก็ได้ผลเดิม
  final bool notFound;

  const TrackingException(this.message, {this.notFound = false});

  @override
  String toString() => message;
}

/// ดึงสถานะพัสดุโดยไม่ต้องบอกว่าเลขที่กรอกเป็นเลขแบบไหน
///
/// หน้าจอไม่มีตัวเลือกประเภทเลขให้กด จึงไล่ลองตามลำดับใน [TrackingType] เอง
/// เจอที่ไหนคืนที่นั้น เพราะเลขพัสดุกับเลขร้านค้าแยกกันไม่ออกจากรูปแบบ
///
/// API รับพารามิเตอร์ `tel` (4 ตัวท้ายเบอร์ผู้รับ) เป็นตัวกรองได้ด้วย แต่หน้าจอ
/// ไม่ได้ใช้ ถ้าวันหลังต้องใช้ ให้ส่งต่อเข้า [fetchTrackingByType] ที่รับไว้แล้ว
/// และอย่าลืมว่า tel ที่ไม่ตรงตอบ "Unknow DocumentNumber" เหมือนเลขพัสดุผิด
/// จึงต้องบอกผู้ใช้ให้ชัดว่าเบอร์ก็เป็นสาเหตุได้
///
/// โยน [TrackingException] ทุกกรณีที่ไม่สำเร็จ
Future<TrackingResult> fetchTracking({required String code}) async {
  final trimmed = code.trim();
  if (trimmed.isEmpty) {
    throw const TrackingException('กรุณากรอกเลขเอกสาร');
  }

  TrackingException? lastNotFound;
  for (final type in TrackingType.values) {
    try {
      return await fetchTrackingByType(code: trimmed, type: type);
    } on TrackingException catch (e) {
      // เฉพาะ "ไม่พบ" ที่ควรลองแบบถัดไป ถ้าเน็ตพังหรือคีย์ไม่ผ่าน
      // การลองซ้ำก็เจออาการเดิม แค่ทำให้ผู้ใช้รอนานขึ้นเปล่า ๆ
      if (!e.notFound) rethrow;
      lastNotFound = e;
    }
  }
  throw lastNotFound!;
}

/// ดึงสถานะพัสดุตามประเภทเลขที่ระบุ
///
/// [tel] คือ 4 ตัวท้ายของเบอร์ผู้รับ ใส่มาเพื่อกรองผลให้แคบลง ไม่ใส่ก็ได้
Future<TrackingResult> fetchTrackingByType({
  required String code,
  required TrackingType type,
  String? tel,
}) async {
  // ไม่มี request body — พารามิเตอร์ทั้งหมดไปทาง query string อย่างเดียว
  // และ GET ให้ผลเหมือน POST (ทดสอบแล้ว) จึงใช้ GET ที่ตรงความหมายกว่า
  final uri = Uri.parse(_endpoint).replace(
    queryParameters: {
      'type': type.value,
      'code': code,
      if (tel != null) 'tel': tel,
    },
  );

  final http.Response response;
  try {
    response = await http
        .get(uri, headers: {'Authorization': trackingApiKey})
        .timeout(_timeout);
  } catch (e) {
    throw TrackingException(_networkMessage(e));
  }

  // เซิร์ฟเวอร์ประกาศ charset=utf-8 แต่ถ้าอ่านผ่าน response.body แพ็กเกจ http
  // จะถอดเป็น latin1 เมื่อ header ไม่ครบ ภาษาไทยจะกลายเป็นขยะ จึงถอดเอง
  final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();

  return decodeTrackingBody(body, statusCode: response.statusCode);
}

/// แปลง body ที่ได้จาก API เป็นผลลัพธ์ แยกออกมาเพื่อเทสต์ได้โดยไม่ต้องต่อเน็ต
///
/// ⚠️ API ตอบ error เป็น **plain text พร้อม HTTP 200** ไม่ใช่ JSON และไม่ใช่
/// 4xx จึงต้องดูรูปร่างของ body ก่อน ห้ามเชื่อ status code
TrackingResult decodeTrackingBody(String body, {int statusCode = 200}) {
  if (!body.startsWith('{')) {
    throw _errorFromPlainText(body, statusCode);
  }

  final Map<String, dynamic> json;
  try {
    final decoded = jsonDecode(repairJsonEscapes(body));
    if (decoded is! Map) {
      throw const TrackingException('ข้อมูลที่ได้จากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }
    json = Map<String, dynamic>.from(decoded);
  } on TrackingException {
    rethrow;
  } catch (_) {
    throw const TrackingException(
      'ข้อมูลที่ได้จากเซิร์ฟเวอร์อ่านไม่ได้ กรุณาลองใหม่',
    );
  }

  final result = TrackingResult.fromJson(json);
  if (result.isEmpty) {
    throw const TrackingException('ไม่พบข้อมูลพัสดุ', notFound: true);
  }
  return result;
}

/// ซ่อม escape ที่ JSON ไม่รู้จัก ให้ jsonDecode อ่านผ่าน
///
/// ⚠️ จำเป็นจริง ไม่ใช่การกันไว้ก่อน: JSON ฝั่งเซิร์ฟเวอร์สร้างด้วยการต่อ
/// string ไม่ได้ escape ค่าที่ใส่เข้าไป พัสดุที่ส่งถึงแล้วจะมี URL รูปที่มี
/// backslash ดิบ (`.../11092026\Success/...`) ซึ่ง `\S` ไม่ใช่ escape ที่ JSON
/// รู้จัก jsonDecode จะโยน FormatException ทันที = ใบที่มีรูปทุกใบอ่านไม่ได้
///
/// วิธีซ่อมคือหา backslash ที่ตามด้วยตัวอักษรนอกชุด escape ที่ถูกต้อง
/// (`" \ / b f n r t u`) แล้ว escape ตัวมันเองเพิ่มให้ ส่วน `\\` ที่ถูกอยู่แล้ว
/// จะไม่ถูกแตะ เพราะตัวที่ตามมาคือ `\` ซึ่งอยู่ในชุดที่ถูกต้อง
String repairJsonEscapes(String source) {
  const valid = r'"\/bfnrtu';

  return source.replaceAllMapped(RegExp(r'\\(.)', dotAll: true), (match) {
    final next = match.group(1)!;
    if (valid.contains(next)) return match.group(0)!;
    return '\\\\$next';
  });
}

/// แปลข้อความ error แบบ plain text เป็นข้อความภาษาไทย
///
/// เทียบแบบ contains และไม่สนตัวพิมพ์ เพราะข้อความฝั่งเซิร์ฟเวอร์เขียนไม่
/// สม่ำเสมอ (สะกด "unknow" ตกตัว n) และอาจมีช่องว่างติดมา
TrackingException _errorFromPlainText(String body, int statusCode) {
  final text = body.toLowerCase();

  if (text.contains('unknow documentnumber')) {
    return const TrackingException('ไม่พบข้อมูลพัสดุ', notFound: true);
  }
  if (text.contains('unknow client')) {
    return const TrackingException(
      'ไม่ได้รับอนุญาตให้เข้าถึงข้อมูล กรุณาแจ้งผู้ดูแลระบบ',
    );
  }
  if (text.contains('please check data')) {
    return const TrackingException(
      'ข้อมูลที่ส่งไปไม่ครบ กรุณาตรวจสอบเลขเอกสาร',
    );
  }
  if (body.isEmpty) {
    return TrackingException(
      'เซิร์ฟเวอร์ไม่ได้ส่งข้อมูลกลับมา (code $statusCode)',
    );
  }
  return TrackingException('เช็คสถานะไม่สำเร็จ: $body');
}

String _networkMessage(Object error) {
  if (error is TrackingException) return error.message;
  final name = error.runtimeType.toString();
  if (name.contains('Timeout')) {
    return 'เชื่อมต่อเซิร์ฟเวอร์หมดเวลา กรุณาลองใหม่';
  }
  return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
}
