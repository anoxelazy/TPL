import 'package:flutter/foundation.dart';

import 'package:claim/utils/app_config.dart';

/// host ที่แอปกำลังยิง API ไปหา สลับไปตัวสำรองได้เมื่อตัวหลักล่ม
///
/// เก็บเป็น state กลางเพราะมีหลายที่ที่ต้องรู้ว่าตอนนี้ยิงไป host ไหน:
/// ตัว dio ที่ยิง request, ตัวเคาะเช็คสถานะเน็ต และตัวต่อ URL ของรูปที่
/// เซิร์ฟเวอร์ตอบมาเป็น path แบบ relative ถ้าใช้ host ต่างกันรูปจะโหลดไม่ขึ้น
///
/// สลับแล้วค้างอยู่ที่ตัวสำรองจนปิดแอป ไม่วนกลับเอง เพื่อไม่ให้ผู้ใช้
/// ต้องรอ timeout ของ host ที่ล่มซ้ำทุก request
class ApiHost {
  ApiHost._();

  static final ApiHost I = ApiHost._();

  String _active = AppConfig.primaryBaseUrl;

  /// ให้ตัวที่ถือ dio รู้ว่าต้องเปลี่ยน baseUrl ตาม ตั้งครั้งเดียวตอน initDio
  ///
  /// ใช้ callback เพราะถ้าเรียก dio จากที่นี่ตรง ๆ จะ import วนกัน
  /// (dio_service ต้องรู้จัก ApiHost อยู่แล้ว)
  void Function(String host)? onSwitched;

  /// host ที่ใช้อยู่ตอนนี้
  String get active => _active;

  /// host อีกตัวที่ยังไม่ได้ใช้ ใช้เป็นเป้าตอนสลับ
  String get standby => _active == AppConfig.primaryBaseUrl
      ? AppConfig.fallbackBaseUrl
      : AppConfig.primaryBaseUrl;

  bool get isUsingFallback => _active == AppConfig.fallbackBaseUrl;

  /// ย้ายไปใช้ host ที่ระบุ คืน true เมื่อค่าเปลี่ยนจริง
  bool switchTo(String host) {
    if (_active == host) return false;
    _active = host;
    onSwitched?.call(host);
    return true;
  }

  @visibleForTesting
  void resetToPrimary() {
    _active = AppConfig.primaryBaseUrl;
  }
}
