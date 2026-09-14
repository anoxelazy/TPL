/// ระบบ PM อยู่บน Mobile API ตัวใหม่ (HTTPS) ไม่ใช่ API หลักที่ใช้ล็อกอิน
///
/// endpoint ทั้งหมดต้องแนบ Bearer token ที่ได้จาก /api/Auth/login
/// ถ้ายังไม่มี token จะโยน [MobileApiException] ที่ตั้ง needLogin ไว้
library;

import 'dart:io';

import 'package:claim/page/pm/pm_models.dart';
import 'package:claim/utils/image_encode.dart';
import 'package:claim/utils/mobile_api.dart';

/// รูปที่ถ่ายไว้ของหัวข้อหนึ่ง ยังไม่ได้อัปโหลด
class PmTaskPhotos {
  final int subNo;
  final File? before;
  final File? after;

  const PmTaskPhotos({required this.subNo, this.before, this.after});

  bool get isEmpty => before == null && after == null;
}

/// ดึงรายการเครื่องทั้งหมดพร้อมประวัติ PM ทุกปี
///
/// ก้อนใหญ่ (ของจริงราว 600 KB / 134 เครื่อง) แต่ API ไม่มีตัวกรองหรือแบ่งหน้า
/// จึงต้องโหลดทีเดียวแล้วค้นในเครื่อง หน้าจอควรเก็บผลไว้ ไม่ยิงซ้ำทุกครั้ง
Future<List<PmHead>> fetchPmList() async {
  final options = MobileSession.I.authOptions(
    receiveTimeout: const Duration(seconds: 60),
  );
  if (options == null) {
    throw const MobileApiException(
      'ยังไม่ได้เชื่อมต่อระบบ PM กรุณาเข้าสู่ระบบใหม่',
      needLogin: true,
    );
  }

  try {
    final response = await mobileDio.get(
      '/api/PMDetails/list',
      options: options,
    );
    final data = unwrapMobileResponse(response);

    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PmHead.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ดึงเฉพาะหัวข้อของเครื่องเดียว
///
/// [comName] คือชื่อเครื่อง เช่น `TP-COM-300` — ทดสอบแล้วว่า endpoint นี้รับ
/// ชื่อเครื่องเท่านั้น ส่งเลขที่ใบหรือรหัสทรัพย์สินไปจะได้ 404
Future<List<PmDetail>> fetchPmDetails(String comName) async {
  final options = MobileSession.I.authOptions();
  if (options == null) {
    throw const MobileApiException(
      'ยังไม่ได้เชื่อมต่อระบบ PM กรุณาเข้าสู่ระบบใหม่',
      needLogin: true,
    );
  }

  try {
    final response = await mobileDio.get(
      '/api/PMDetails/details/${Uri.encodeComponent(comName)}',
      options: options,
    );
    final data = unwrapMobileResponse(response);

    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PmDetail.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// เปิดใบ PM ใหม่ให้เครื่องที่ยังไม่เคยมีในระบบ
Future<void> insertPmHead({
  required String comName,
  required String fixAsset,
  required String empNo,
  required String location,
  required String remark,
  required int yearCheck,
  required List<PmTaskPhotos> photos,
}) async {
  await _send(
    method: 'POST',
    path: '/api/PMDetails/insert',
    body: {
      'comName': comName,
      'fixAsset': fixAsset,
      'empNo': empNo,
      'location': location,
      'remark': remark,
      'yearCheck': yearCheck,
      'imgList': await _buildImgList(photos),
    },
  );
}

/// บันทึก PM ของปีนี้ลงเครื่องที่มีใบอยู่แล้ว
///
/// [no] คือเลขที่ใบจาก [PmHead.no] ไม่ใช่ subNo ของหัวข้อ
Future<void> updatePmHead({
  required int no,
  required String fixAsset,
  required String empNo,
  required String location,
  required String remark,
  required int yearCheck,
  required List<PmTaskPhotos> photos,
}) async {
  await _send(
    method: 'PUT',
    path: '/api/PMDetails/update-head',
    body: {
      'no': no,
      'fixAsset': fixAsset,
      'empNo': empNo,
      'location': location,
      'remark': remark,
      'yearCheck': yearCheck,
      'imgList': await _buildImgList(photos),
    },
  );
}

/// แปลงรูปที่ถ่ายไว้เป็นรายการที่ API รับ
///
/// ⚠️ **ข้อสมมติที่ต้องยืนยันกับทีม backend**: `beforeLink`/`afterLink` ส่งเป็น
/// base64 ของไฟล์รูป ไม่ใช่ URL
///
/// ที่เชื่อแบบนั้นเพราะ (1) schema มี `beforeExtension` คู่มาด้วย ถ้าเป็น URL
/// ก็ไม่ต้องบอกนามสกุลไฟล์ และ (2) URL ของรูปที่มีอยู่จริงเป็นรูปแบบ
/// `SiteImages/FixAsset/<ddMMyyyy><empNo>/<guid>_<empNo>.png` ซึ่ง guid
/// ต้องถูกสร้างฝั่งเซิร์ฟเวอร์ แอปจึงส่ง URL มาเองไม่ได้อยู่แล้ว
///
/// ถ้าปรากฏว่าต้องอัปโหลดรูปที่อื่นก่อนแล้วส่ง URL มา ให้แก้เฉพาะฟังก์ชันนี้
/// ส่วนอื่นไม่ต้องแตะ
Future<List<Map<String, dynamic>>> _buildImgList(
  List<PmTaskPhotos> photos,
) async {
  final list = <Map<String, dynamic>>[];

  for (final photo in photos) {
    if (photo.isEmpty) continue;

    list.add({
      'subNo': photo.subNo,
      'beforeLink': await _encode(photo.before),
      'beforeExtension': _extensionOf(photo.before),
      'afterLink': await _encode(photo.after),
      'afterExtension': _extensionOf(photo.after),
    });
  }

  return list;
}

/// ย่อรูปก่อนแปลงเป็น base64 เสมอ
///
/// รูปจากกล้องมือถือใบละ 3-5 MB ถ้าส่งดิบ ๆ หกหัวข้อพร้อมกันคือเกิน 30 MB
/// ต่อการบันทึกหนึ่งครั้ง ช่างที่ใช้เน็ตมือถือจะส่งไม่ผ่าน
Future<String?> _encode(File? file) async {
  if (file == null) return null;
  final bytes = await compressImageForUpload(file, maxEdge: 1280, quality: 80);
  return encodeBase64InBackground(bytes);
}

/// นามสกุลไฟล์แบบไม่มีจุด ให้ตรงกับที่เซิร์ฟเวอร์เอาไปตั้งชื่อไฟล์
///
/// ย่อรูปแล้วได้ jpg เสมอไม่ว่าไฟล์ต้นทางจะเป็นอะไร จึงตอบ jpg ตายตัว
/// ไม่ได้อ่านจากชื่อไฟล์เดิม ไม่งั้นจะได้ .png ที่ข้างในเป็น jpeg
String? _extensionOf(File? file) => file == null ? null : 'jpg';

Future<void> _send({
  required String method,
  required String path,
  required Map<String, dynamic> body,
}) async {
  final options = MobileSession.I.authOptions(
    // เซิร์ฟเวอร์ต้องเขียนไฟล์รูปลงดิสก์ก่อนตอบ หกหัวข้อพร้อมกันใช้เวลานาน
    receiveTimeout: const Duration(seconds: 120),
  );
  if (options == null) {
    throw const MobileApiException(
      'ยังไม่ได้เชื่อมต่อระบบ PM กรุณาเข้าสู่ระบบใหม่',
      needLogin: true,
    );
  }

  try {
    final response = method == 'POST'
        ? await mobileDio.post(path, data: body, options: options)
        : await mobileDio.put(path, data: body, options: options);

    unwrapMobileResponse(response);
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}
