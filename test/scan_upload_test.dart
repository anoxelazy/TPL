import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/scan/scan_api.dart';

bool ok(int? status, dynamic body, {int sent = 1}) =>
    isUploadSuccessful(statusCode: status, body: body, sentCount: sent);

void main() {
  group('เงื่อนไขว่าส่งรูปสำเร็จ', () {
    test('ครบ 3 ข้อจึงถือว่าสำเร็จ', () {
      expect(ok(200, {'success': true, 'saved': 1}), isTrue);
    });

    test('saved มากกว่าจำนวนที่ส่งก็ผ่าน', () {
      expect(ok(200, {'success': true, 'saved': 3}), isTrue);
    });

    test('HTTP 2xx อื่นก็ผ่าน', () {
      expect(ok(201, {'success': true, 'saved': 1}), isTrue);
      expect(ok(204, {'success': true, 'saved': 1}), isTrue);
    });
  });

  group('HTTP 200 แต่ต้องถือว่าล้มเหลว', () {
    test('saved เป็น 0 คือรูปไม่เข้าฐานข้อมูล', () {
      expect(ok(200, {'success': true, 'saved': 0}), isFalse);
    });

    test('saved น้อยกว่าจำนวนที่ส่ง', () {
      expect(ok(200, {'success': true, 'saved': 1}, sent: 2), isFalse);
    });

    test('success เป็น false', () {
      expect(ok(200, {'success': false, 'saved': 1}), isFalse);
    });

    test('ไม่มีคีย์ success', () {
      expect(ok(200, {'saved': 1}), isFalse);
    });

    test('ไม่มีคีย์ saved', () {
      expect(ok(200, {'success': true}), isFalse);
    });
  });

  group('body ที่อ่านไม่ได้ต้องไม่เดาว่าผ่าน', () {
    test('body ว่าง', () {
      expect(ok(200, ''), isFalse);
      expect(ok(200, null), isFalse);
    });

    test('body ไม่ใช่ JSON', () {
      expect(ok(200, '<html>OK</html>'), isFalse);
    });

    test('body เป็น list ไม่ใช่ object', () {
      expect(ok(200, [1, 2, 3]), isFalse);
    });

    test('body เป็นตัวเลข', () {
      expect(ok(200, 1), isFalse);
    });
  });

  group('status code ที่ไม่ใช่ 2xx', () {
    test('null (ยิงไม่ถึงเซิร์ฟเวอร์)', () {
      expect(ok(null, {'success': true, 'saved': 1}), isFalse);
    });

    test('4xx / 5xx', () {
      expect(ok(401, {'success': true, 'saved': 1}), isFalse);
      expect(ok(404, {'success': true, 'saved': 1}), isFalse);
      expect(ok(500, {'success': true, 'saved': 1}), isFalse);
    });
  });

  group('ค่าที่ส่งมาเป็น string', () {
    test('success และ saved มาเป็น string ก็ต้องอ่านได้', () {
      expect(ok(200, {'success': 'true', 'saved': '1'}), isTrue);
    });

    test('saved เป็น string "0" ยังถือว่าล้มเหลว', () {
      expect(ok(200, {'success': 'true', 'saved': '0'}), isFalse);
    });

    test('body ที่มาเป็น JSON string ก็ต้อง decode ให้', () {
      expect(ok(200, '{"success":true,"saved":1}'), isTrue);
      expect(ok(200, '{"success":true,"saved":0}'), isFalse);
    });
  });

  group('ค่าคงที่ที่ใช้ร่วมกัน', () {
    test('TagName กับ module ต้องเป็นค่าเดียวกัน', () {
      // เซิร์ฟเวอร์ใช้ค่านี้แยกประเภทรูป ถ้าสองที่ไม่ตรงกันจะหารูปไม่เจอ
      expect(scanTagName, 'Bar');
    });

    test('ชื่อ permission module ต้องตรงตัวกับที่เซิร์ฟเวอร์ส่งมา', () {
      // canAccess เทียบชื่อคีย์ตรง ๆ พิมพ์ผิดตัวเดียวคือทุกคนเข้าเมนูไม่ได้
      expect(scanModule, 'ScanBar&TakePhoto');
    });
  });
}
