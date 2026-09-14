import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:claim/utils/api_host.dart';

/// สถานะการเชื่อมต่อของแอป อ่านจากผลของ request จริง ไม่ได้ถามระบบว่ามีเน็ตไหม
///
/// ต่อ wifi ที่ไม่มีเน็ตอยู่ก็ใช้งานไม่ได้เหมือนกัน สิ่งที่ผู้ใช้สนใจคือ
/// "ตอนนี้ยิงหาเซิร์ฟเวอร์ได้หรือเปล่า" ไม่ใช่ว่าเครื่องต่อสัญญาณอะไรอยู่
class NetworkStatus {
  NetworkStatus._();

  static final NetworkStatus I = NetworkStatus._();

  /// true = ต่อเซิร์ฟเวอร์ไม่ได้ ให้ขึ้นแถบเตือน
  final ValueNotifier<bool> isOffline = ValueNotifier(false);

  /// dio แยกตัวสำหรับเคาะเซิร์ฟเวอร์ ไม่ผ่าน interceptor ของตัวหลัก
  /// ไม่งั้นผลของการเคาะจะวนกลับมาเรียกตัวเองอีกรอบ
  static final Dio _pingDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      // ตอบอะไรกลับมาก็ถือว่าต่อถึงแล้ว 404 ก็ยังแปลว่าเซิร์ฟเวอร์อยู่
      validateStatus: (_) => true,
    ),
  );

  Timer? _probe;
  bool _checking = false;

  /// เรียกเมื่อ request ล้มเพราะต่อไม่ติด
  ///
  /// ยังไม่ขึ้นแถบทันที เคาะเซิร์ฟเวอร์ยืนยันก่อน กัน alert หลอกเวลาโดนบล็อก
  /// เฉพาะบาง host (เช่นไฟล์ json บน github) ทั้งที่เน็ตยังใช้ได้ปกติ
  void markOffline() {
    if (isOffline.value || _checking) return;
    _checking = true;
    _confirmOffline();
  }

  /// เรียกเมื่อ request ไหนก็ตามได้คำตอบกลับมาจากเซิร์ฟเวอร์
  void markOnline() {
    _probe?.cancel();
    _probe = null;
    isOffline.value = false;
  }

  Future<void> _confirmOffline() async {
    final reachable = await _ping();
    _checking = false;
    if (reachable) return;

    isOffline.value = true;
    // ระหว่างออฟไลน์คอยเคาะเบา ๆ แถบจะได้หายเองเมื่อเน็ตกลับมา
    // โดยผู้ใช้ไม่ต้องกดอะไรก่อน
    _probe?.cancel();
    _probe = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (await _ping()) markOnline();
    });
  }

  /// เคาะ host ที่ใช้อยู่ ถ้าไม่ตอบก็ลองตัวสำรอง
  ///
  /// ต้องลองทั้งสองตัวเพราะ "ออฟไลน์" หมายถึงต่อไม่ได้ทั้งคู่ ไม่ใช่แค่ตัวเดียว
  /// ถ้าตัวสำรองตอบก็ย้ายไปใช้เลย request ถัดไปจะได้ไม่ต้องรอ timeout อีก
  Future<bool> _ping() async {
    if (await _reachable(ApiHost.I.active)) return true;

    final standby = ApiHost.I.standby;
    if (standby == ApiHost.I.active) return false;

    if (await _reachable(standby)) {
      ApiHost.I.switchTo(standby);
      return true;
    }

    return false;
  }

  Future<bool> _reachable(String host) async {
    try {
      await _pingDio.get(host);
      return true;
    } catch (e) {
      debugPrint('network ping failed ($host): $e');
      return false;
    }
  }
}
