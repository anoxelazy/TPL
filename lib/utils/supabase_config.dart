import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ลิงก์ที่เก็บคีย์ Supabase ไว้
///
/// แก้คีย์ที่ไฟล์นี้ไฟล์เดียว แอปทุกเครื่องตามทันทีที่เปิดครั้งถัดไป
/// ไม่ต้อง build APK ใหม่แล้วไล่ให้พนักงานอัปเดตทีละคน
const String kSupabaseKeyUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/key_sapu.json';

const String _cacheKey = 'supabase_anon_key';

/// ชื่อฟิลด์ที่ยอมรับใน json รองรับหลายแบบเผื่อคนแก้ไฟล์เขียนไม่ตรงกัน
const List<String> _keyFields = ['SUPABASE_ANON_KEY', 'anonKey', 'key'];

/// ค่าตั้งค่าและ client ของ Supabase (ระบบแจ้งซ่อม/ทะเบียนเครื่อง)
///
/// เป็นคนละระบบกับ API หลักของแอป ใช้แค่เป็นแหล่งข้อมูลเสริม
/// การล็อกอินยังทำที่ API หลักเหมือนเดิม ดู `ApiHost`
class SupabaseConfig {
  const SupabaseConfig._();

  static const String baseUrl = 'https://qzqumefhywgsfplfuqag.supabase.co';

  /// คีย์ที่ฝังมาตอน build ด้วย --dart-define
  ///
  /// ปกติไม่ต้องใส่ แอปดึงจาก [kSupabaseKeyUrl] เอง ใส่ไว้สำหรับตอนทดสอบ
  /// ที่อยากชี้ไปคีย์อื่นโดยไม่ต้องไปแก้ไฟล์กลางที่คนอื่นใช้อยู่
  static const String _buildKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String _key = _buildKey;

  /// คีย์ที่ใช้อยู่ตอนนี้ ว่าง = ยังโหลดไม่ได้
  static String get anonKey => _key;

  /// มีคีย์พร้อมใช้แล้วหรือยัง เป็นการเช็คแบบไม่รอ
  ///
  /// ก่อนยิง Supabase ให้ใช้ [ensureKey] แทน ตัวนี้ไว้ดูสถานะเฉย ๆ
  static bool get isConfigured => _key.isNotEmpty;

  /// กันโหลดซ้อนตอนหลายหน้ายิงพร้อมกัน โหลดจริงครั้งเดียวแล้วรอคิวเดียวกัน
  static Future<bool>? _loading;

  /// dio เปล่า ๆ ไม่ผูก interceptor ของใคร
  ///
  /// ตัวหลักมีระบบสลับ host กับตัวรายงานสถานะเน็ตติดอยู่ ส่วน [supabaseDio]
  /// ก็ต้องรอคีย์จากตรงนี้อีกที ใช้ร่วมกันไม่ได้ทั้งคู่
  ///
  /// เปิดให้เทสต์สลับตัวได้ เทสต์จะได้ไม่ต้องยิงเน็ตจริง
  @visibleForTesting
  static Dio loaderDio = Dio();

  /// ให้แน่ใจว่ามีคีย์ก่อนคุยกับ Supabase เรียกกี่ครั้งก็ได้
  ///
  /// คืน false เมื่อหาคีย์ไม่เจอจริง ๆ ผู้เรียกค่อยตัดสินใจว่าจะเงียบหรือฟ้อง
  static Future<bool> ensureKey() {
    if (isConfigured) return Future.value(true);
    return _loading ??= _fetch().whenComplete(() => _loading = null);
  }

  /// ถามคีย์ล่าสุดจากลิงก์ ใช้ตอนเปิดแอปเพื่อรับคีย์ที่เพิ่งเปลี่ยน
  ///
  /// คีย์ที่ฝังมาตอน build ถือว่าผู้ใช้ตั้งใจ ไม่ไปทับ
  static Future<void> refresh() async {
    if (_buildKey.isNotEmpty) return;
    await (_loading ??= _fetch().whenComplete(() => _loading = null));
  }

  /// ล้างคีย์ในหน่วยความจำ ใช้ในเทสต์เท่านั้น
  ///
  /// คีย์เป็น static เทสต์แต่ละเคสเลยต้องเริ่มจากศูนย์ ไม่งั้นเคสก่อนหน้าค้างมา
  @visibleForTesting
  static void resetForTest() {
    _key = _buildKey;
    _loading = null;
  }

  static Future<bool> _fetch() async {
    final prefs = await SharedPreferences.getInstance();

    // ของที่เคยโหลดได้ใช้ไปพลางก่อน เปิดแอปแบบเน็ตไม่ดีจะได้ยังแจ้งซ่อมได้
    final cached = _clean(prefs.getString(_cacheKey));
    if (cached.isNotEmpty) _key = cached;

    try {
      final response = await loaderDio.get<dynamic>(
        kSupabaseKeyUrl,
        options: Options(
          headers: const {'Accept': 'application/json'},
          // รับเป็นข้อความดิบแล้วแกะเอง raw.githubusercontent ส่ง content-type
          // มาเป็น text/plain ปล่อยให้ dio เดาเองจะได้ผลไม่เหมือนกันแต่ละที่
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final fetched = _clean(_readKey(response.data));
      if (fetched.isNotEmpty && fetched != _key) {
        _key = fetched;
        await prefs.setString(_cacheKey, fetched);
      }
    } catch (e) {
      debugPrint('supabase key: โหลดจากลิงก์ไม่ได้ $e');
    }

    return isConfigured;
  }

  /// แกะคีย์ออกจาก body รับได้ทั้ง json object และสตริงคีย์เปล่า ๆ
  static String _readKey(dynamic body) {
    if (body == null) return '';

    dynamic decoded = body;
    if (body is String) {
      final text = body.trim();
      if (!text.startsWith('{')) return text;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        return '';
      }
    }

    if (decoded is! Map) return '';
    for (final field in _keyFields) {
      final value = decoded[field]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// กันคีย์ที่เอามาใส่ผิดตัว
  ///
  /// sb_secret_ (ตัวที่มาแทน service_role) ข้าม policy ทุกอย่างของฐานข้อมูล
  /// มีไว้ใช้ฝั่งเซิร์ฟเวอร์เท่านั้น หลุดมาถึงเครื่องผู้ใช้เมื่อไหร่คือใครก็ลบ
  /// ทั้งฐานข้อมูลได้ ถึงจะมีคนเผลอเอาไปใส่ในลิงก์ แอปก็ต้องไม่หยิบมาใช้
  static String _clean(String? value) {
    final key = value?.trim() ?? '';
    if (key.isEmpty) return '';

    if (key.startsWith('sb_secret_') || key.contains('service_role')) {
      debugPrint('supabase key: เจอ secret key ในแหล่งคีย์ ไม่เอามาใช้');
      return '';
    }
    return key;
  }
}

/// dio แยกตัวสำหรับ Supabase โดยเฉพาะ
///
/// ห้ามใช้ dio ตัวหลักร่วมกัน เพราะตัวหลักมี interceptor สลับ host สำรอง
/// กับตัวรายงานสถานะเน็ตติดอยู่ ถ้า Supabase ล่มจะไปทำให้แถบ "ไม่มีอินเทอร์เน็ต"
/// ขึ้นทั้งที่ระบบหลักยังใช้งานได้ปกติ
final Dio supabaseDio =
    Dio(
        BaseOptions(
          baseUrl: SupabaseConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        ),
      )
      // คีย์มาทีหลังตอนโหลดจากลิงก์เสร็จ ใส่ตอนยิงจริงทุกครั้งแทนการตั้งค้างไว้
      // ใน BaseOptions ไม่งั้น request แรก ๆ จะออกไปแบบไม่มีคีย์
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final key = SupabaseConfig.anonKey;
            if (key.isNotEmpty) {
              options.headers['apikey'] = key;
              options.headers['Authorization'] = 'Bearer $key';
            }
            handler.next(options);
          },
        ),
      );
