import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/app_logger.dart';
import 'package:claim/utils/dio_service.dart';
import 'package:claim/utils/image_encode.dart';
import 'package:claim/utils/location_service.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/utils/url_utils.dart';

/// ชื่อ module ใน Permissions.Modules ที่ต้องเปิดให้ก่อนใช้ฟีเจอร์นี้
const String meterModule = 'meter';

/// เซิร์ฟเวอร์ต้องอัปโหลดรูปต่อไปยังที่เก็บก่อนตอบกลับ
/// จึงเกิน receiveTimeout 7 วินาทีที่ตั้งไว้ใน [dio] เป็นปกติ
const Duration _apiTimeout = Duration(seconds: 60);

/// รูปไมล์มี 2 ช่วง ใช้เป็นทั้ง suffix ของชื่อไฟล์และป้ายบนหน้าจอ
enum MeterSideKind {
  start('start', 'ไมล์ต้นวัน'),
  end('end', 'ไมล์ปลายวัน');

  final String slug;
  final String label;

  const MeterSideKind(this.slug, this.label);
}

/// ข้อผิดพลาดที่บอกผู้ใช้ได้ตรง ๆ
class MeterApiException implements Exception {
  final String message;

  /// token หมดอายุ หน้าจอต้องบอกให้ไป login ใหม่ ไม่ใช่ให้กดลองใหม่
  final bool isUnauthorized;

  const MeterApiException(this.message, {this.isUnauthorized = false});

  @override
  String toString() => message;
}

/// ข้อมูลผู้ใช้ที่ต้องแนบไปกับการบันทึก
class MeterSession {
  final String token;

  /// ชื่อผู้บันทึก แสดงบนฟอร์ม
  final String name;

  /// รหัสพนักงานที่ login ส่งเป็น EmpRec (ไม่ใช่รหัสคนขับในฟอร์ม)
  final String empId;

  /// สาขาของผู้บันทึก ส่งเป็น BranchEmpID
  final String branchId;

  const MeterSession({
    required this.token,
    required this.name,
    required this.empId,
    required this.branchId,
  });
}

/// อ่านข้อมูล login ที่เก็บไว้ตอนเข้าสู่ระบบ
Future<MeterSession> loadMeterSession() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';

  if (token.isEmpty) {
    throw const MeterApiException(
      'ไม่พบ token กรุณาเข้าสู่ระบบใหม่',
      isUnauthorized: true,
    );
  }

  return MeterSession(
    token: token,
    name: prefs.getString('fullname') ?? '',
    empId: prefs.getString('driverID') ?? '',
    branchId: PermissionService.I.getBranchId() ?? '',
  );
}

/// พิกัดที่แนบมากับข้อมูลไมล์ 1 ช่วง
class MeterGps {
  final double lat;
  final double lon;

  const MeterGps(this.lat, this.lon);

  static MeterGps? fromJson(dynamic value) {
    if (value is! Map) return null;
    final lat = _double(value['lat']);
    final lon = _double(value['lon']);
    // เซิร์ฟเวอร์ส่ง 0,0 มาเมื่อยังไม่มีพิกัด ไม่ใช่พิกัดจริง
    if (lat == 0 && lon == 0) return null;
    return MeterGps(lat, lon);
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};

  GeoPoint toPoint() => GeoPoint(lat, lon);
}

/// ข้อมูลไมล์ 1 ช่วง (ต้นวันหรือปลายวัน)
class MeterSide {
  final int meter;

  /// null เมื่อยังไม่มีรูป เซิร์ฟเวอร์ใช้ทั้ง "" / 0 / "0" สื่อความหมายนี้
  final String? imageUrl;
  final MeterGps? gps;

  const MeterSide({this.meter = 0, this.imageUrl, this.gps});

  factory MeterSide.fromJson(dynamic value) {
    if (value is! Map) return const MeterSide();
    return MeterSide(
      meter: _int(value['Meter']),
      imageUrl: resolveImageUrl(value['MeterURL']),
      gps: MeterGps.fromJson(value['gps']),
    );
  }

  bool get hasMeter => meter > 0;

  bool get hasImage => imageUrl != null;

  /// นับว่าครบต้องมีทั้งเลขไมล์และรูป เลขไมล์มาลอย ๆ ยังเติมรูปได้
  bool get isComplete => hasMeter && hasImage;
}

/// ข้อมูลไมล์ของวันนี้ที่บันทึกไว้แล้ว (ผลจาก /getmeter)
class MeterDay {
  /// ต้องส่งค่านี้กลับตอนบันทึก ถ้าสร้างใหม่เซิร์ฟเวอร์จะมองเป็นอีก record
  final DateTime? tranDate;
  final MeterSide start;
  final MeterSide end;

  const MeterDay({this.tranDate, required this.start, required this.end});

  factory MeterDay.fromJson(Map<String, dynamic> json) {
    final input = json['InputData'];
    final map = input is Map ? input : const {};
    return MeterDay(
      tranDate: _dateTime(json['TranDate']),
      start: MeterSide.fromJson(map['StartMeter']),
      end: MeterSide.fromJson(map['EndMeter']),
    );
  }

  /// ไม่มีอะไรบันทึกไว้เลย ถือว่ายังไม่มีข้อมูลของวันนี้
  bool get isEmpty =>
      !start.hasMeter && !start.hasImage && !end.hasMeter && !end.hasImage;
}

/// ผลคำนวณเงินชดเชยจาก /InputMeter
///
/// ชื่อ key ฝั่งเซิร์ฟเวอร์เล็กใหญ่ปนกัน และไมล์ปลายสะกดว่า endtMeter
/// (typo ฝั่งเซิร์ฟเวอร์) map ตามที่ส่งมาจริง ห้ามแก้ให้สวย
class MeterResult {
  final DateTime? tranDate;
  final String driverId;
  final String truckId;
  final String truckLicense;

  final int startMeter;
  final String? startMeterUrl;
  final int endMeter;
  final String? endMeterUrl;

  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;

  final double standardFuelPrice;
  final double currentFuelPrice;
  final double fuelConsumptionRate;
  final double distanceDifference;
  final double fuelPriceDifference;
  final double fuelCompensation;
  final double compensationRate;

  final String recBranchEmp;
  final String recEmp;
  final DateTime? recDate;

  const MeterResult({
    required this.tranDate,
    required this.driverId,
    required this.truckId,
    required this.truckLicense,
    required this.startMeter,
    required this.startMeterUrl,
    required this.endMeter,
    required this.endMeterUrl,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.standardFuelPrice,
    required this.currentFuelPrice,
    required this.fuelConsumptionRate,
    required this.distanceDifference,
    required this.fuelPriceDifference,
    required this.fuelCompensation,
    required this.compensationRate,
    required this.recBranchEmp,
    required this.recEmp,
    required this.recDate,
  });

  factory MeterResult.fromJson(Map<String, dynamic> json) => MeterResult(
    tranDate: _dateTime(json['TranDate']),
    driverId: _str(json['DriverID']),
    truckId: _str(json['TruckID']),
    truckLicense: _str(json['TruckLicesen']),
    startMeter: _int(json['startMeter']),
    startMeterUrl: resolveImageUrl(json['StartMeterURL']),
    endMeter: _int(json['endtMeter']),
    endMeterUrl: resolveImageUrl(json['EndMeterURL']),
    startLat: _double(json['SLat']),
    startLon: _double(json['SLon']),
    endLat: _double(json['ELat']),
    endLon: _double(json['ELon']),
    standardFuelPrice: _double(json['standardFuelPrice']),
    currentFuelPrice: _double(json['currentFuelPrice']),
    fuelConsumptionRate: _double(json['fuelConsumptionRate']),
    distanceDifference: _double(json['distanceDifference']),
    fuelPriceDifference: _double(json['fuelPriceDifference']),
    fuelCompensation: _double(json['fuelCompensation']),
    compensationRate: _double(json['compensationRate']),
    recBranchEmp: _str(json['RecBranchEmp']),
    recEmp: _str(json['RecEmp']),
    recDate: _dateTime(json['RecDate']),
  );
}

/// เช็คว่าวันนี้บันทึกไมล์ของคนขับ+รถคู่นี้ไปแล้วหรือยัง
///
/// คืน null เมื่อยังไม่มีข้อมูลของวันนี้
Future<MeterDay?> fetchTodayMeter({
  required String driverId,
  required String truckId,
  required MeterSession session,
}) async {
  final data = await _post(
    path: '/api/getmeter',
    token: session.token,
    // key เล็กใหญ่ปนกันตามที่เซิร์ฟเวอร์รับ ห้ามแก้ให้เหมือนกัน
    body: {
      'trandate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'driverID': driverId,
      'TruckID': truckId,
    },
  );

  final list = _asList(data);
  if (list.isEmpty) return null;

  final first = list.first;
  if (first is! Map) return null;

  final day = MeterDay.fromJson(Map<String, dynamic>.from(first));
  // InputData เป็น null จะได้ side ว่างทั้งคู่ = ยังไม่มีข้อมูลวันนี้
  return day.isEmpty ? null : day;
}

/// อัปโหลดรูปหน้าปัดไมล์ คืน URL ที่ normalize แล้ว
///
/// [driverId] คือรหัสคนขับที่กรอกในฟอร์ม ไม่ใช่รหัสของผู้ที่ login
/// เพราะหลังบ้านใช้ค่านี้จัดโฟลเดอร์
Future<String> uploadMeterImage({
  required String driverId,
  required File file,
  required MeterSideKind side,
  required MeterSession session,
}) async {
  final now = DateTime.now();
  final base64Image = await _compressToBase64(file);

  final data = await _post(
    path: '/api/GETImageLink_Folder',
    token: session.token,
    body: {
      'empId': driverId,
      'folderName': 'meter/${DateFormat('yyyyMMdd').format(now)}/$driverId',
      'imageName': '${DateFormat('yyyyMMddHHmm').format(now)}_${side.slug}',
      'image1': base64Image,
      // พิกัดจริงส่งไปกับ InputMeter ตัวนี้เซิร์ฟเวอร์ไม่ได้ใช้
      'lat': 0.0,
      'lon': 0.0,
    },
    // log ขนาดพอ ไม่ log base64 ทั้งก้อน
    logData: {'side': side.slug, 'base64Length': base64Image.length},
  );

  // endpoint นี้ตอบ URL เป็น string ล้วน ไม่ได้ห่อ JSON
  final url = resolveImageUrl(data is String ? data : data?.toString());
  if (url == null) {
    throw const MeterApiException('อัปโหลดรูปไม่สำเร็จ กรุณาถ่ายใหม่');
  }
  return url;
}

/// บันทึกไมล์และรับผลคำนวณเงินชดเชยกลับมา
Future<MeterResult> saveMeter({
  required String driverId,
  required String truckId,
  required MeterSession session,
  required DateTime? tranDate,
  required int startMeter,
  required String? startImageUrl,
  required GeoPoint? startGps,
  required int endMeter,
  required String? endImageUrl,
  required GeoPoint? endGps,
}) async {
  final data = await _post(
    path: '/api/InputMeter',
    token: session.token,
    body: {
      // ใช้ TranDate เดิมของวันนี้ถ้ามี ไม่งั้นเซิร์ฟเวอร์จะเปิด record ใหม่
      'TranDate': (tranDate ?? DateTime.now()).toIso8601String(),
      'DriverID': driverId,
      'TruckID': truckId,
      // เซิร์ฟเวอร์สะกดผิด และฟอร์มไม่มีช่องนี้ ส่งค่าว่างเสมอ
      'TruckLicesen': '',
      'EmpRec': session.empId,
      'BranchEmpID': session.branchId,
      'StartMeter': {
        'Meter': startMeter,
        'MeterURL': startImageUrl ?? '',
        'gps': startGps?.toJson(),
      },
      'EndMeter': {
        'Meter': endMeter,
        'MeterURL': endImageUrl ?? '',
        'gps': endGps?.toJson(),
      },
    },
  );

  final map = _asMap(data);
  if (map == null) {
    throw const MeterApiException('บันทึกแล้วแต่อ่านผลคำนวณไม่ได้');
  }
  return MeterResult.fromJson(map);
}

/// ยิง POST JSON ผ่าน dio ตัวกลาง แนบ Bearer และแปลง error เป็นข้อความไทย
Future<dynamic> _post({
  required String path,
  required String token,
  required Map<String, dynamic> body,
  Map<String, dynamic>? logData,
}) async {
  try {
    final response = await dio.post(
      path,
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        receiveTimeout: _apiTimeout,
        sendTimeout: _apiTimeout,
      ),
    );

    await AppLogger.I.log(
      'meter_api_ok',
      data: {'path': path, 'status': response.statusCode, ...?logData},
    );

    if (response.statusCode != 200) {
      throw MeterApiException(
        'เชื่อมต่อไม่สำเร็จ (HTTP ${response.statusCode})',
      );
    }

    return response.data;
  } on DioException catch (e) {
    await AppLogger.I.log(
      'meter_api_error',
      data: {
        'path': path,
        'type': e.type.name,
        'status': e.response?.statusCode,
      },
    );

    if (e.response?.statusCode == 401) {
      throw const MeterApiException(
        'token หมดอายุ กรุณาเข้าสู่ระบบใหม่',
        isUnauthorized: true,
      );
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw const MeterApiException('เชื่อมต่อเซิร์ฟเวอร์หมดเวลา กรุณาลองใหม่');
    }

    throw const MeterApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่');
  }
}

/// ย่อรูปแล้วแปลงเป็น base64 พร้อมส่งขึ้น API
Future<String> _compressToBase64(File file) async {
  if (await file.length() > maxUploadFileBytes) {
    throw const MeterApiException('ไฟล์รูปใหญ่เกินไป กรุณาถ่ายใหม่');
  }

  final compressed = await compressImageForUpload(file);
  return encodeBase64InBackground(compressed);
}

List<dynamic> _asList(dynamic data) {
  dynamic decoded = data;

  if (decoded is String) {
    final trimmed = decoded.trim();
    if (trimmed.isEmpty) return const [];
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return const [];
    }
  }

  if (decoded is List) return decoded;
  if (decoded is Map) return [decoded];
  return const [];
}

Map<String, dynamic>? _asMap(dynamic data) {
  dynamic decoded = data;

  if (decoded is String) {
    final trimmed = decoded.trim();
    if (trimmed.isEmpty) return null;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  if (decoded is List) {
    decoded = decoded.isEmpty ? null : decoded.first;
  }
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return null;
}

String _str(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

/// ตัวเลขจากเซิร์ฟเวอร์มาได้ทั้ง int, double และ string
int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return double.tryParse(_str(value).replaceAll(',', ''))?.round() ?? 0;
}

double _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(_str(value).replaceAll(',', '')) ?? 0;
}

DateTime? _dateTime(dynamic value) {
  if (value is DateTime) return value;
  final text = _str(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
