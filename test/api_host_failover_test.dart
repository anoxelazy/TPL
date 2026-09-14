import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/utils/api_host.dart';
import 'package:claim/utils/app_config.dart';
import 'package:claim/utils/dio_service.dart';

DioException error(DioExceptionType type, {Object? cause, int? status}) {
  final options = RequestOptions(path: '/api/x');
  return DioException(
    requestOptions: options,
    type: type,
    error: cause,
    response: status == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: status),
  );
}

void main() {
  setUp(() => ApiHost.I.resetToPrimary());

  group('ApiHost สลับ host', () {
    test('เริ่มที่ host หลักเสมอ', () {
      expect(ApiHost.I.active, AppConfig.primaryBaseUrl);
      expect(ApiHost.I.standby, AppConfig.fallbackBaseUrl);
      expect(ApiHost.I.isUsingFallback, isFalse);
    });

    test('สลับไปตัวสำรองแล้ว standby กลับเป็นตัวหลัก', () {
      expect(ApiHost.I.switchTo(AppConfig.fallbackBaseUrl), isTrue);

      expect(ApiHost.I.active, AppConfig.fallbackBaseUrl);
      expect(ApiHost.I.standby, AppConfig.primaryBaseUrl);
      expect(ApiHost.I.isUsingFallback, isTrue);
    });

    test('สลับไป host เดิมคืน false ไม่แจ้งซ้ำ', () {
      var switched = 0;
      ApiHost.I.onSwitched = (_) => switched++;
      addTearDown(() => ApiHost.I.onSwitched = null);

      expect(ApiHost.I.switchTo(AppConfig.primaryBaseUrl), isFalse);
      expect(switched, 0);

      expect(ApiHost.I.switchTo(AppConfig.fallbackBaseUrl), isTrue);
      expect(switched, 1);
    });

    test('แจ้ง host ใหม่ให้ตัวที่ถือ dio รู้', () {
      String? notified;
      ApiHost.I.onSwitched = (host) => notified = host;
      addTearDown(() => ApiHost.I.onSwitched = null);

      ApiHost.I.switchTo(AppConfig.fallbackBaseUrl);

      expect(notified, AppConfig.fallbackBaseUrl);
    });

    test('host หลักกับสำรองต้องไม่ใช่ตัวเดียวกัน', () {
      // ถ้าตั้งซ้ำกัน failover จะกลายเป็นการยิงซ้ำ host เดิมเปล่า ๆ
      expect(AppConfig.primaryBaseUrl, isNot(AppConfig.fallbackBaseUrl));
    });
  });

  group('เคสที่ถือว่าต่อไม่ถึงเซิร์ฟเวอร์ (สลับ host ได้)', () {
    test('connectionError และ connectionTimeout', () {
      expect(
        isConnectionFailure(error(DioExceptionType.connectionError)),
        isTrue,
      );
      expect(
        isConnectionFailure(error(DioExceptionType.connectionTimeout)),
        isTrue,
      );
    });

    test('SocketException ที่ห่อมาใน unknown (DNS/หาเส้นทางไม่ได้)', () {
      expect(
        isConnectionFailure(
          error(
            DioExceptionType.unknown,
            cause: const SocketException('no route to host'),
          ),
        ),
        isTrue,
      );
    });
  });

  group('เคสที่ห้ามยิงซ้ำ เพราะเซิร์ฟเวอร์อาจรับไปทำแล้ว', () {
    test('receiveTimeout — ส่งถึงแล้ว รอผลอยู่ ยิงซ้ำเสี่ยงบันทึกซ้ำ', () {
      expect(
        isConnectionFailure(error(DioExceptionType.receiveTimeout)),
        isFalse,
      );
    });

    test('sendTimeout — ส่ง body ไปได้บางส่วนแล้ว', () {
      expect(isConnectionFailure(error(DioExceptionType.sendTimeout)), isFalse);
    });

    test('badResponse ที่เซิร์ฟเวอร์ตอบมาเอง', () {
      expect(
        isConnectionFailure(error(DioExceptionType.badResponse, status: 401)),
        isFalse,
      );
    });

    test('cancel', () {
      expect(isConnectionFailure(error(DioExceptionType.cancel)), isFalse);
    });
  });

  group('status ที่แปลว่าตัวหน้าต่อ backend ไม่ได้', () {
    test('502 / 503 / 504 สลับ host ได้', () {
      expect(isGatewayDown(502), isTrue);
      expect(isGatewayDown(503), isTrue);
      expect(isGatewayDown(504), isTrue);
    });

    test('500 ห้ามสลับ เพราะแอปฝั่งเซิร์ฟเวอร์รับไปทำแล้วพลาด', () {
      expect(isGatewayDown(500), isFalse);
    });

    test('2xx / 4xx และ null ไม่เข้าเกณฑ์', () {
      expect(isGatewayDown(200), isFalse);
      expect(isGatewayDown(401), isFalse);
      expect(isGatewayDown(404), isFalse);
      expect(isGatewayDown(null), isFalse);
    });
  });
}
