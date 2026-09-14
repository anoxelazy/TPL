import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/dio_service.dart';

const String kPmJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/pm.json';

const String _cacheKey = 'pm_access_json';

/// รหัสพิเศษที่แปลว่าเปิดให้ทุกคน
const String _all = '*';

/// รายชื่อรหัสพนักงานที่เข้าเมนู PM ได้ อ่านจาก pm.json
///
/// แยกจาก [PermissionService] เพราะฝั่ง API พนักงานยังไม่มี module ให้ผูก
/// และแยกจาก [RoleService] เพราะสิทธิ์ IT ของระบบแจ้งซ่อมเป็นคนละเรื่องกัน
class PmAccessService {
  PmAccessService._();

  static final PmAccessService I = PmAccessService._();

  /// เมนู PM กดได้หรือไม่ หน้าหลัก listen ตัวนี้เพื่ออัปเดตเมื่อโหลดเสร็จ
  final ValueNotifier<bool> allowed = ValueNotifier(false);

  /// อ่านรายชื่อที่ cache ไว้ให้ใช้ทันที แล้วดึงของใหม่เบื้องหลัง
  ///
  /// โหลดไม่ได้จะใช้รายชื่อล่าสุดที่เคยได้ ไม่รีเซ็ตเป็นห้ามทุกคน
  /// ไม่งั้นคนที่เคยเข้าได้จะเข้าไม่ได้ตอนเน็ตหลุด
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('driverID') ?? '';

    if (empId.isEmpty) {
      allowed.value = false;
      return;
    }

    final cached = _parse(prefs.getString(_cacheKey));
    if (cached != null) allowed.value = _match(cached, empId);

    try {
      final response = await dio.get(
        kPmJsonUrl,
        options: Options(
          headers: {'Accept': 'application/json'},
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = response.data is String
          ? response.data as String
          : jsonEncode(response.data);

      final parsed = _parse(body);
      if (parsed == null) throw Exception('รูปแบบไฟล์ไม่ถูกต้อง');

      allowed.value = _match(parsed, empId);
      await prefs.setString(_cacheKey, body);
    } catch (e) {
      debugPrint('pm.json error: $e');
    }
  }

  /// ล้างสิทธิ์ออกจากหน้าจอตอน logout คนถัดไปต้องถูกเช็คใหม่
  void forgetCurrentUser() => allowed.value = false;

  bool _match(List<String> ids, String empId) =>
      ids.contains(_all) || ids.contains(empId.trim());

  /// คืน null เมื่ออ่านไม่ได้ ผู้เรียกจะได้แยกออกจาก "อ่านได้แต่ลิสต์ว่าง"
  /// ซึ่งแปลว่าตั้งใจปิดทุกคน
  List<String>? _parse(String? body) {
    if (body == null || body.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;

      final list = decoded['pm'];
      if (list is! List) return null;

      return [
        for (final item in list)
          if (item != null) item.toString().trim(),
      ];
    } catch (e) {
      debugPrint('pm.json parse error: $e');
      return null;
    }
  }
}
