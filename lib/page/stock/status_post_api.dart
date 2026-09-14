import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/dio_service.dart';

/// StatusCode ที่ส่งไปตอนพักสถานะสินค้า
///
/// 2 = ส่งข้อมูลไม่สำเร็จ ซึ่งฝั่งระบบถือว่าเป็นการพักสถานะ
///
/// ระวัง: StatusCode ของ endpoint นี้เป็นรหัส "คนละชุด" กับ jobstatusid
/// ที่ /api/Bill_Stock ส่งกลับมา เลข 2 ของสองชุดจึงคนละความหมายกัน
/// (jobstatusid 2 = ต้นทาง ดู status.json ที่ kStatusJsonUrl)
/// อย่าเอาสองชุดมา map ถึงกัน
///
/// ReasonCode ไม่ได้ hardcode ดึงจาก [fetchHoldReasons] ให้ผู้ใช้เลือก
const String kParkStatusCode = '2';

class HoldReason {
  final String id;
  final String reasonName;

  final String flagName;

  const HoldReason({
    required this.id,
    required this.reasonName,
    required this.flagName,
  });

  factory HoldReason.fromJson(Map<String, dynamic> json) => HoldReason(
    id: _str(json['id']),
    reasonName: _str(json['reasonname']),
    flagName: _str(json['flagname']),
  );
}

/// ดึงรายการเหตุผลที่พักสินค้า
Future<List<HoldReason>> fetchHoldReasons() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null || token.isEmpty) {
    throw Exception('ไม่พบ token กรุณาเข้าสู่ระบบใหม่');
  }

  try {
    final response = await dio.get(
      '/api/GetHoldReason',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('ดึงเหตุผลไม่สำเร็จ (HTTP ${response.statusCode})');
    }

    dynamic decoded = response.data;
    if (decoded is String) {
      final trimmed = decoded.trim();
      if (trimmed.isEmpty) return const [];
      decoded = jsonDecode(trimmed);
    }
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((e) => HoldReason.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  } on DioException catch (e) {
    debugPrint('GetHoldReason error: ${e.type} ${e.message}');

    if (e.response?.statusCode == 401) {
      throw Exception('token หมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }

    throw Exception('โหลดเหตุผลไม่สำเร็จ กรุณาลองใหม่');
  }
}

String _str(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

/// บันทึกการโทรติดต่อผู้รับ 1 ครั้ง ส่งไปในฟิลด์ records
class CallRecord {
  final DateTime dateTime;
  final bool answered;
  final int durationSeconds;
  final String number;

  const CallRecord({
    required this.dateTime,
    required this.answered,
    required this.durationSeconds,
    required this.number,
  });

  Map<String, dynamic> toJson() => {
    'datetime': dateTime.toIso8601String(),
    'answered': answered,
    'durationSeconds': durationSeconds,
    'number': number,
  };
}

/// สร้าง body ที่ส่งไปที่ /api/StatusPost_new
///
/// แยกออกมาเพื่อเทสได้ว่าคีย์และค่าตรงตามที่ฝั่งเซิร์ฟเวอร์รับจริง
@visibleForTesting
Map<String, dynamic> buildStatusPayload({
  required String a1,
  required String statusCode,
  required String user,
  required DateTime timestamp,
  String? reasonCode,
  String? remark,
  List<CallRecord> records = const [],
  double lat = 0,
  double long = 0,
}) => {
  'A1': a1,
  'StatusCode': statusCode,
  'Lat': lat,
  'Long': long,
  'Timestemp': timestamp.toIso8601String(),
  'records': records.map((e) => e.toJson()).toList(),
  'Signature': null,
  'User': user,
  'ReasonCode': reasonCode,
  'Relationship': null,
  'Remark': remark,
  'image1': null,
  'image2': null,
  'image3': null,
  'image4': null,
  'image5': null,
  'TypeAddr': null,
  'pod_img': null,
};

/// ส่งสถานะของบิลไปที่ /api/StatusPost_new
///
/// รูป payload ตรงตาม cURL ที่ได้รับ รวมถึงชื่อฟิลด์ `Timestemp` ที่สะกดแบบนี้
/// ฝั่งเซิร์ฟเวอร์ จึงเปลี่ยนไม่ได้ ฟิลด์ที่แอปยังไม่ได้ใช้ส่ง null ไปตามเดิม
///
/// [lat] / [long] ยังส่ง 0 เพราะโปรเจกต์ยังไม่มี package อ่านพิกัด
/// (โค้ดเดิมในหน้าเคลมก็ส่ง 0.0 เหมือนกัน)
Future<String> postBillStatus({
  required String a1,
  required String statusCode,
  String? reasonCode,
  String? remark,
  List<CallRecord> records = const [],
  double lat = 0,
  double long = 0,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final user = prefs.getString('driverID');

  if (token == null || token.isEmpty) {
    throw Exception('ไม่พบ token กรุณาเข้าสู่ระบบใหม่');
  }
  if (user == null || user.isEmpty) {
    throw Exception('ไม่พบรหัสพนักงานของผู้ใช้ กรุณาเข้าสู่ระบบใหม่');
  }
  if (a1.isEmpty) {
    throw Exception('ไม่พบเลขบิลของรายการนี้');
  }

  try {
    final response = await dio.post(
      '/api/StatusPost_new',
      data: buildStatusPayload(
        a1: a1,
        statusCode: statusCode,
        user: user,
        timestamp: DateTime.now(),
        reasonCode: reasonCode,
        remark: remark,
        records: records,
        lat: lat,
        long: long,
      ),
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('บันทึกไม่สำเร็จ (HTTP ${response.statusCode})');
    }

    return response.data?.toString() ?? '';
  } on DioException catch (e) {
    debugPrint('StatusPost_new error: ${e.type} ${e.message}');

    if (e.response?.statusCode == 401) {
      throw Exception('token หมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw Exception('เชื่อมต่อเซิร์ฟเวอร์หมดเวลา กรุณาลองใหม่');
    }

    throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่');
  }
}
