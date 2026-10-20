import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/utils/mobile_api.dart';

Response<dynamic> _response(int code, dynamic body) => Response<dynamic>(
  requestOptions: RequestOptions(path: '/api/AssetTransfer/approver'),
  statusCode: code,
  data: body,
);

/// ก้อน error ที่กลุ่ม AssetTransfer ตอบมาจริงเมื่อ 24 ก.ย. 2026
///
/// ได้มาจากการตั้งผู้อนุมัติซ้ำคนเดิม — เซิร์ฟเวอร์ตอบ HTTP 409 พร้อมประโยค
/// ภาษาไทยที่บอกตรง ๆ ว่าทำไมไม่ผ่าน
const _duplicateBody = {
  'success': false,
  'code': 'DUPLICATE',
  'message': 'นายพัฒนพงษ์ อุ่นทรัพย์ เป็นผู้อนุมัติของแผนก F0001 อยู่แล้ว',
  'id': null,
};

void main() {
  group('unwrapMobileResponse', () {
    test('409 ต้องเอาข้อความไทยของเซิร์ฟเวอร์มาโชว์ ไม่ใช่เลข HTTP', () {
      // เคยโชว์ว่า "ทำรายการไม่สำเร็จ (HTTP 409)" ซึ่งผู้ใช้ทำอะไรต่อไม่ได้เลย
      expect(
        () => unwrapMobileResponse(_response(409, _duplicateBody)),
        throwsA(
          isA<MobileApiException>().having(
            (e) => e.message,
            'message',
            'นายพัฒนพงษ์ อุ่นทรัพย์ เป็นผู้อนุมัติของแผนก F0001 อยู่แล้ว',
          ),
        ),
      );
    });

    test('ไม่มีข้อความมาด้วย ค่อยถอยไปใช้เลข HTTP', () {
      expect(
        () => unwrapMobileResponse(_response(500, null)),
        throwsA(
          isA<MobileApiException>().having(
            (e) => e.message,
            'message',
            'ทำรายการไม่สำเร็จ (HTTP 500)',
          ),
        ),
      );
    });

    test('404 ยังคงพฤติกรรมเดิม ข้อความมีคำว่า "ไม่พบ" ให้หน้าจอเช็คต่อได้', () {
      // หลายหน้าเช็ค message.contains('ไม่พบ') เพื่อแยก "ค้นไม่เจอ" ออกจาก
      // "พัง" การแก้ข้อความ error ต้องไม่ทำให้เงื่อนไขนั้นหลุด
      expect(
        () => unwrapMobileResponse(_response(404, 'ไม่พบข้อมูลทรัพย์สิน')),
        throwsA(
          isA<MobileApiException>().having(
            (e) => e.message,
            'message',
            contains('ไม่พบ'),
          ),
        ),
      );
    });

    test('404 ที่ body ว่าง ต้องได้ข้อความกลางที่ยังมีคำว่า "ไม่พบ"', () {
      expect(
        () => unwrapMobileResponse(_response(404, '')),
        throwsA(
          isA<MobileApiException>().having(
            (e) => e.message,
            'message',
            'ไม่พบข้อมูล',
          ),
        ),
      );
    });

    test('401 ต้องตั้ง needLogin ให้หน้าจอบอกล็อกอินใหม่แทนปุ่มลองใหม่', () {
      expect(
        () => unwrapMobileResponse(_response(401, _duplicateBody)),
        throwsA(
          isA<MobileApiException>().having((e) => e.needLogin, 'needLogin', isTrue),
        ),
      );
    });

    test('201 ที่ POST /approver ตอบมา ต้องถือว่าสำเร็จ ไม่ใช่ error', () {
      // swagger ประกาศไว้แค่ 200 แต่ของจริงตอบ 201 ตอนสร้างสำเร็จ
      final data = unwrapMobileResponse(
        _response(201, {'success': true, 'message': 'เรียบร้อยแล้ว'}),
      );

      expect(data, isA<Map>());
    });
  });

  group('mobileErrorMessage', () {
    test('อ่าน message จากก้อน JSON ของกลุ่ม AssetTransfer', () {
      expect(mobileErrorMessage(_duplicateBody), contains('อยู่แล้ว'));
    });

    test('อ่านสตริง JSON ที่ถูก encode มาอีกชั้น', () {
      expect(
        mobileErrorMessage('{"success":false,"message":"ซ้ำ"}'),
        'ซ้ำ',
      );
    });

    test('ข้อความเปล่า ๆ แบบที่ endpoint กลุ่มเก่าตอบ ใช้ได้ตรง ๆ', () {
      expect(mobileErrorMessage('ไม่พบข้อมูล'), 'ไม่พบข้อมูล');
    });

    test('ไม่มีอะไรให้อ่านคืนค่าว่าง ผู้เรียกจะได้ถอยไปใช้ข้อความกลาง', () {
      expect(mobileErrorMessage(null), '');
      expect(mobileErrorMessage('   '), '');
      expect(mobileErrorMessage({'success': false, 'code': 'X'}), '');
    });
  });
}
