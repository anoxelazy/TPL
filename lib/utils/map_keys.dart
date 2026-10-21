import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/supabase_config.dart' show kSupabaseKeyUrl;

/// ลิงก์ JSON ที่เก็บคีย์แผนที่ หน้าตาไฟล์
///
/// ```json
/// { "ORS_API_KEY": "...", "LONGDO_API_KEY": "..." }
/// ```
///
/// ตอนนี้ชี้ไฟล์เดียวกับคีย์ Supabase ([kSupabaseKeyUrl]) ใส่สองฟิลด์นี้เพิ่ม
/// ในไฟล์นั้นได้เลย จะย้ายไป host ที่อื่นก็เปลี่ยนลิงก์ตรงนี้ที่เดียว
const String kMapKeysUrl = kSupabaseKeyUrl;

/// คีย์ของบริการแผนที่ (OpenRouteService กับ Longdo Map)
///
/// ดึงจาก [kMapKeysUrl] ฟิลด์ `ORS_API_KEY`
/// กับ `LONGDO_API_KEY` เดิมต้องฝังตอน build ด้วย `--dart-define-from-file`
/// ลืมใส่ทีไรแผนที่ถอยไปใช้ของสาธารณะเงียบ ๆ และเปลี่ยนคีย์ทีต้อง build ใหม่
///
/// คีย์ที่ใส่ตอน build ยังชนะไฟล์เสมอ ไว้ทดสอบด้วยคีย์อื่นโดยไม่กวนไฟล์กลาง
///
/// ทั้งสองตัวเป็นคีย์ฟรีที่ฝั่งเครื่องผู้ใช้ต้องถืออยู่แล้ว (ฝังใน APK ก็แกะได้
/// เหมือนกัน) อยู่ในไฟล์สาธารณะจึงไม่ได้เสี่ยงกว่าเดิม ต่างจาก secret ของ
/// Supabase ที่ห้ามขึ้นไปอยู่ตรงนั้นเด็ดขาด
class MapKeys {
  const MapKeys._();

  static const String _buildOrs = String.fromEnvironment('ORS_API_KEY');
  static const String _buildLongdo = String.fromEnvironment('LONGDO_API_KEY');

  static const String _orsField = 'ORS_API_KEY';
  static const String _longdoField = 'LONGDO_API_KEY';
  static const String _orsCache = 'map_key_ors';
  static const String _longdoCache = 'map_key_longdo';

  static String _ors = _buildOrs;
  static String _longdo = _buildLongdo;

  /// คีย์ OpenRouteService ว่าง = ข้ามไปใช้ OSRM สาธารณะ
  static String get ors => _ors;

  /// คีย์ Longdo Map ว่าง = แผนที่ OSM และไม่หาที่อยู่ให้
  static String get longdo => _longdo;

  static Future<void>? _loading;

  /// dio เปล่า ๆ แบบเดียวกับ [SupabaseConfig.loaderDio] เปิดให้เทสต์สลับได้
  @visibleForTesting
  static Dio loaderDio = Dio();

  /// โหลดคีย์ครั้งเดียวต่อการเปิดแอป เรียกกี่ครั้งก็รอคิวเดียวกัน
  ///
  /// ใช้ของที่ cache ไว้ไปพลางก่อน แล้วค่อยถามไฟล์ล่าสุด ถ้ารอบนี้ไม่ได้คีย์
  /// สักตัว (เน็ตหลุดตอนเปิดแอปครั้งแรก) ครั้งถัดไปที่เรียกจะลองใหม่
  static Future<void> ensureLoaded() {
    if (_buildOrs.isNotEmpty && _buildLongdo.isNotEmpty) return Future.value();
    return _loading ??= _load().then((_) {
      if (_ors.isEmpty && _longdo.isEmpty) _loading = null;
    });
  }

  @visibleForTesting
  static void resetForTest() {
    _ors = _buildOrs;
    _longdo = _buildLongdo;
    _loading = null;
  }

  static Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    if (_buildOrs.isEmpty) _ors = prefs.getString(_orsCache) ?? _ors;
    if (_buildLongdo.isEmpty) {
      _longdo = prefs.getString(_longdoCache) ?? _longdo;
    }

    try {
      final response = await loaderDio.get<dynamic>(
        kMapKeysUrl,
        options: Options(
          headers: const {'Accept': 'application/json'},
          // raw.githubusercontent ส่งมาเป็น text/plain รับดิบแล้วแกะเอง
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final fields = readMapKeyFields(response.data);

      final ors = fields[_orsField] ?? '';
      if (_buildOrs.isEmpty && ors.isNotEmpty) {
        _ors = ors;
        await prefs.setString(_orsCache, ors);
      }

      final longdo = fields[_longdoField] ?? '';
      if (_buildLongdo.isEmpty && longdo.isNotEmpty) {
        _longdo = longdo;
        await prefs.setString(_longdoCache, longdo);
      }
    } catch (e) {
      debugPrint('map keys: โหลดจากลิงก์ไม่ได้ $e');
    }
  }
}

/// แกะฟิลด์คีย์แผนที่จาก body ของไฟล์คีย์ ช่องที่ไม่มีหรือว่างไม่ใส่มา
@visibleForTesting
Map<String, String> readMapKeyFields(dynamic body) {
  dynamic decoded = body;
  if (body is String) {
    try {
      decoded = jsonDecode(body.trim());
    } catch (_) {
      return const {};
    }
  }
  if (decoded is! Map) return const {};

  return {
    for (final field in const ['ORS_API_KEY', 'LONGDO_API_KEY'])
      if ((decoded[field]?.toString().trim() ?? '').isNotEmpty)
        field: decoded[field].toString().trim(),
  };
}
