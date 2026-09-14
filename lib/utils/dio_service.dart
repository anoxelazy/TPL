import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:claim/utils/api_host.dart';
import 'package:claim/utils/app_logger.dart';
import 'package:claim/utils/network_status.dart';

late final Dio _dio;

/// ต่อไม่ติดใน 10 วินาทีถือว่า host นั้นล่ม
///
/// สั้นกว่าเดิม (30 วิ) เพราะตอนนี้ต่อไม่ติดแล้วยังต้องไปลอง host สำรองอีกตัว
/// ถ้าปล่อยไว้ 30 ผู้ใช้จะรอถึงนาทีนึงก่อนได้คำตอบ
const Duration _connectTimeout = Duration(seconds: 10);

Future<void> initDio() async {
  _dio = Dio(
    BaseOptions(
      baseUrl: ApiHost.I.active,
      connectTimeout: _connectTimeout,
      receiveTimeout: const Duration(seconds: 7),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // สลับ host ที่ไหนก็ได้ baseUrl ของ dio จะตามไปเอง ไม่งั้น request ถัดไป
  // ยังวิ่งไป host เดิมแล้วต้องรอ timeout ใหม่ทุกครั้ง
  ApiHost.I.onSwitched = (host) => _dio.options.baseUrl = host;

  // ต้องมาก่อนตัวรายงานสถานะเน็ต ถ้าสลับ host แล้วยิงซ้ำสำเร็จ
  // จะได้ไม่มี error หลุดไปให้แถบ "ออฟไลน์" ขึ้นทั้งที่ใช้งานได้
  _dio.interceptors.add(_HostFailoverInterceptor());

  // ทุก request รายงานสถานะเน็ตให้แถบเตือนบนสุดของจอ
  _dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        NetworkStatus.I.markOnline();
        handler.next(response);
      },
      onError: (e, handler) {
        if (e.response != null) {
          // เซิร์ฟเวอร์ตอบมาแล้ว แม้จะเป็น error ก็แปลว่าเน็ตใช้ได้
          NetworkStatus.I.markOnline();
        } else if (isConnectionFailure(e)) {
          NetworkStatus.I.markOffline();
        }
        handler.next(e);
      },
    ),
  );

  // log เฉพาะตอน debug เพราะ requestHeader ทำให้ Bearer token
  // ออกมาอยู่ใน log ของเครื่องผู้ใช้ด้วย
  if (kDebugMode) {
    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        compact: false,
        maxWidth: 120,
        filter: (options, args) {
          // body ของการอัปโหลดรูปเป็น base64 ก้อนใหญ่ ปล่อยให้ log จะท่วมจอ
          // และไม่มีอะไรให้อ่าน ข้ามเฉพาะ request ส่วน response (ลิงก์รูป) เก็บไว้
          if (!args.isResponse && _hasBase64Body(options.path)) {
            return false;
          }
          return true;
        },
      ),
    );
  }
}

Dio get dio => _dio;

/// ล้มเพราะต่อไม่ถึงเซิร์ฟเวอร์ ไม่ใช่เพราะเซิร์ฟเวอร์ตอบช้าหรือตอบ error
///
/// receiveTimeout ไม่นับ เพราะต่อติดแล้วแค่เซิร์ฟเวอร์ช้า ไม่ใช่เน็ตหาย
bool isConnectionFailure(DioException e) =>
    e.type == DioExceptionType.connectionError ||
    e.type == DioExceptionType.connectionTimeout ||
    e.error is SocketException;

/// สถานะที่แปลว่าตัวหน้า (IIS/proxy) ต่อ backend ไม่ได้
///
/// คำขอยังไม่ถูกประมวลผล จึงยิงซ้ำที่ host อื่นได้ไม่เสี่ยงบันทึกซ้ำ
/// ต่างจาก 500 ที่แอปฝั่งเซิร์ฟเวอร์รับไปทำแล้วพลาด — ห้ามยิงซ้ำ
/// เพราะอาจบันทึกไปแล้วก่อนพลาด
bool isGatewayDown(int? statusCode) =>
    statusCode == 502 || statusCode == 503 || statusCode == 504;

/// ต่อ host หลักไม่ได้ ให้ยิงซ้ำที่ host สำรองให้อัตโนมัติ
///
/// ยิงซ้ำแค่ครั้งเดียวและเฉพาะกรณีที่แน่ใจว่าเซิร์ฟเวอร์ยังไม่ได้รับคำขอไปทำ
/// เพราะ endpoint ส่วนใหญ่ของแอปนี้เป็นการบันทึก (InputMeter, TrackingImg,
/// StatusPost) ยิงซ้ำมั่วจะได้ข้อมูลซ้ำในฐานข้อมูล
class _HostFailoverInterceptor extends Interceptor {
  /// ธงกันวนซ้ำ request ที่สลับ host ไปแล้วจะไม่สลับอีก
  static const String _retriedKey = 'api_host_failover_retried';

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    // หลาย endpoint ตั้ง validateStatus ให้รับทุก status เอง 502/503 จึงมาถึง
    // ทางนี้ไม่ใช่ onError ต้องเช็คซ้ำที่นี่ด้วย
    if (!isGatewayDown(response.statusCode)) {
      return handler.next(response);
    }

    final retried = await _retryOnStandby(
      response.requestOptions,
      reason: 'http ${response.statusCode}',
    );
    if (retried == null) return handler.next(response);
    return handler.resolve(retried);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final canFailover =
        isConnectionFailure(err) || isGatewayDown(err.response?.statusCode);
    if (!canFailover) return handler.next(err);

    final retried = await _retryOnStandby(
      err.requestOptions,
      reason: isConnectionFailure(err)
          ? err.type.name
          : 'http ${err.response?.statusCode}',
    );
    if (retried == null) return handler.next(err);
    return handler.resolve(retried);
  }

  /// สลับไป host สำรองแล้วยิงคำขอเดิมซ้ำ คืน null เมื่อยิงซ้ำไม่ได้หรือไม่สำเร็จ
  Future<Response<dynamic>?> _retryOnStandby(
    RequestOptions options, {
    required String reason,
  }) async {
    if (!_canRetry(options)) return null;

    final target = ApiHost.I.standby;
    final from = ApiHost.I.active;

    await AppLogger.I.log(
      'api_host_failover',
      data: {'path': options.path, 'from': from, 'to': target, 'why': reason},
    );

    ApiHost.I.switchTo(target);

    try {
      final response = await _dio.fetch(
        options.copyWith(
          baseUrl: target,
          extra: {...options.extra, _retriedKey: true},
        ),
      );

      // endpoint ที่ตั้ง validateStatus รับทุก status จะไม่ throw ตอนได้ 503
      // ต้องเช็คเองว่าตัวสำรองก็ล่มเหมือนกัน ไม่งั้นจะค้างอยู่ที่ตัวที่ใช้ไม่ได้
      if (isGatewayDown(response.statusCode)) {
        ApiHost.I.switchTo(from);
        debugPrint('failover to $target also down: ${response.statusCode}');
        return null;
      }

      return response;
    } on DioException catch (e) {
      // ล่มทั้งสองตัว ถอยกลับไปตั้งต้นที่ host หลัก ครั้งหน้าจะได้เริ่มจากตัวเดิม
      ApiHost.I.switchTo(from);
      debugPrint('failover to $target failed: ${e.type.name}');
      return null;
    }
  }

  bool _canRetry(RequestOptions options) {
    // ยิงซ้ำไปแล้วรอบหนึ่ง ไม่วนต่อ
    if (options.extra[_retriedKey] == true) return false;

    // path เป็น URL เต็ม (เช่นไฟล์ json บน github, Google Script)
    // ไม่ได้ใช้ baseUrl ของแอป สลับ host ไปก็ไม่ช่วยอะไร
    if (options.path.startsWith('http')) return false;

    // FormData เป็น stream ที่อ่านไปแล้ว ส่งซ้ำไม่ได้
    if (options.data is FormData) return false;

    return ApiHost.I.standby != ApiHost.I.active;
  }
}

/// endpoint ที่ส่งรูปเป็น base64 มาใน body
///
/// ปล่อยให้ log จะได้ก้อนตัวอักษรเป็นเมกะไบต์จนอ่าน log อื่นไม่ออก
/// และไม่มีอะไรให้อ่านอยู่แล้ว
bool _hasBase64Body(String path) {
  return path.contains('GETImageLink_Folder') || path.contains('TrackingImg');
}
