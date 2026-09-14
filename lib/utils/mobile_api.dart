import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mobile API ตัวใหม่ของบริษัท (คนละตัวกับ API หลักที่ใช้ login และงานเคลม)
///
/// ตัวนี้เป็น **HTTPS จริง** ต่างจาก API หลักที่เปิดแค่ HTTP ตอนนี้มีแต่ระบบ PM
/// ใช้อยู่ ฟีเจอร์ใหม่ที่ backend ย้ายมาทางนี้ให้เรียกผ่านไฟล์นี้
class MobileApi {
  const MobileApi._();

  static const String baseUrl = 'https://internal.thaiparcels.com:1160';

  /// token กับรหัสพนักงานที่ API ตัวนี้ออกให้ เก็บแยกจาก token ของ API หลัก
  /// เพราะคนละระบบ คนละอายุ ปนกันแล้วจะ debug ไม่ออกว่าตัวไหนหมดอายุ
  static const String tokenKey = 'mobile_api_token';
  static const String empNoKey = 'mobile_api_emp_no';
}

/// dio แยกตัวของ Mobile API
///
/// ห้ามใช้ dio ตัวหลักร่วม เพราะตัวหลักมี interceptor สลับ host สำรองกับตัว
/// รายงานสถานะเน็ตติดอยู่ ถ้า API นี้ล่มจะไปทำให้แถบ "ไม่มีอินเทอร์เน็ต" ขึ้น
/// ทั้งที่ระบบหลักยังใช้ได้ และการสลับ host ก็ไม่มีความหมายกับ API ตัวนี้
final Dio mobileDio = Dio(
  BaseOptions(
    baseUrl: MobileApi.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ),
);

/// ข้อผิดพลาดที่แสดงให้ผู้ใช้อ่านได้ตรง ๆ
class MobileApiException implements Exception {
  final String message;

  /// true เมื่อ token ใช้ไม่ได้แล้ว หน้าจอควรบอกให้เข้าสู่ระบบใหม่
  /// ไม่ใช่บอกให้กดลองใหม่ เพราะกดกี่ทีก็ไม่ผ่าน
  final bool needLogin;

  const MobileApiException(this.message, {this.needLogin = false});

  @override
  String toString() => message;
}

/// session ของ Mobile API
///
/// แอปล็อกอินที่ API หลักเหมือนเดิม ตัวนี้แลก token ของตัวเองเพิ่มด้วยรหัสผ่าน
/// ชุดเดียวกันตอนล็อกอินสำเร็จ ผู้ใช้จึงไม่ต้องกรอกรหัสสองรอบ
///
/// ⚠️ ข้อสมมติที่ต้องยืนยันกับทีม backend: ชื่อผู้ใช้/รหัสผ่านของ API ตัวนี้
/// เป็นชุดเดียวกับของ TPS ถ้าไม่ใช่ ต้องเปลี่ยนมาให้ผู้ใช้กรอกแยกในหน้า PM
class MobileSession {
  MobileSession._();

  static final MobileSession I = MobileSession._();

  String? _token;
  String? _empNo;

  String? get empNo => _empNo;
  bool get isReady => _token != null && _token!.isNotEmpty;

  /// อ่าน token ที่เก็บไว้ เรียกตอนเปิดแอป
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(MobileApi.tokenKey);
    _empNo = prefs.getString(MobileApi.empNoKey);
  }

  /// แลก token ด้วยรหัสผ่านที่ผู้ใช้เพิ่งกรอกตอนล็อกอิน
  ///
  /// ล้มเหลวไม่ถือว่าล็อกอินไม่สำเร็จ แค่ทำให้เมนูที่ใช้ API ตัวนี้ใช้ไม่ได้
  /// จึงคืน bool แทนการโยน ให้หน้า login เดินต่อได้เสมอ
  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final response = await mobileDio.post(
        '/api/Auth/login',
        data: {'username': username, 'password': password},
        options: Options(validateStatus: (_) => true),
      );

      final body = response.data;
      if (response.statusCode != 200 || body is! Map) {
        debugPrint('mobile api login failed: ${response.statusCode}');
        return false;
      }

      final token = body['token']?.toString() ?? '';
      if (token.isEmpty) return false;

      _token = token;
      _empNo = body['empNo']?.toString() ?? '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MobileApi.tokenKey, token);
      await prefs.setString(MobileApi.empNoKey, _empNo ?? '');
      return true;
    } catch (e) {
      debugPrint('mobile api login error: $e');
      return false;
    }
  }

  Future<void> clear() async {
    _token = null;
    _empNo = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(MobileApi.tokenKey);
    await prefs.remove(MobileApi.empNoKey);
  }

  /// header สำหรับยิง request คืน null เมื่อยังไม่มี token
  Options? authOptions({Duration? receiveTimeout}) {
    final token = _token;
    if (token == null || token.isEmpty) return null;

    return Options(
      headers: {'Authorization': 'Bearer $token'},
      validateStatus: (_) => true,
      receiveTimeout: receiveTimeout,
    );
  }
}

/// แปลผลลัพธ์ดิบจาก Mobile API เป็นข้อมูลที่ใช้ต่อได้ หรือโยนข้อความภาษาไทย
///
/// รวมไว้ที่เดียวเพราะทุก endpoint ตอบรูปแบบเดียวกัน: 200 = ได้ของ,
/// 401 = token ใช้ไม่ได้, 404 = ไม่พบข้อมูล (ตอบเป็นข้อความไทยตรง ๆ ไม่ใช่ JSON)
dynamic unwrapMobileResponse(Response<dynamic> response) {
  final code = response.statusCode ?? 0;

  if (code == 401 || code == 403) {
    throw const MobileApiException(
      'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
      needLogin: true,
    );
  }

  if (code == 404) {
    // body เป็นข้อความไทยอยู่แล้ว เช่น "ไม่พบข้อมูล" แสดงต่อได้เลย
    final text = response.data?.toString().trim() ?? '';
    throw MobileApiException(text.isEmpty ? 'ไม่พบข้อมูล' : text);
  }

  if (code < 200 || code >= 300) {
    throw MobileApiException('ทำรายการไม่สำเร็จ (HTTP $code)');
  }

  return response.data;
}

String mobileNetworkMessage(Object error) {
  if (error is MobileApiException) return error.message;

  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'เชื่อมต่อเซิร์ฟเวอร์หมดเวลา กรุณาลองใหม่';
    }
  }
  return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
}
