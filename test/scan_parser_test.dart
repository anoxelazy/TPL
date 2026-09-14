import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/scan/scan_image_parser.dart';

const String _baseUrl = 'http://147.50.36.66:1152';

ParsedImageResponse parse(dynamic body) =>
    parseImageResponse(body, baseUrl: _baseUrl);

void main() {
  group('คีย์ Message ที่เป็นลิงก์รูป', () {
    test('ลิงก์ในคีย์ Message ต้องนับเป็นรูป ไม่ใช่ข้อความ', () {
      final result = parse({
        'Message':
            'https://internal.thaiparcels.com:4433/Tps/Bar/2026/09/xxx.png',
      });

      expect(result.images, hasLength(1));
      expect(
        result.images.single,
        'https://internal.thaiparcels.com:4433/Tps/Bar/2026/09/xxx.png',
      );
      // ตัดสินจากค่า ไม่ใช่ชื่อคีย์ จึงต้องไม่มี message
      expect(result.message, isNull);
    });

    test('ข้อความในคีย์ Message ต้องเป็น message ไม่ใช่รูป', () {
      final result = parse({'Message': 'ไม่มีการบันทึกรูปมาก่อน'});

      expect(result.images, isEmpty);
      expect(result.message, 'ไม่มีการบันทึกรูปมาก่อน');
    });

    test('Message ที่เป็น list ของลิงก์ ต้องได้รูปครบทุกใบ', () {
      final result = parse({
        'Message': ['http://x/a.png', 'https://x/b.png'],
      });

      expect(result.images, hasLength(2));
      expect(result.images, ['http://x/a.png', 'https://x/b.png']);
      expect(result.message, isNull);
    });
  });

  group('body ที่ไม่ใช่ JSON object ต้องไม่ throw', () {
    test('string เปล่า', () {
      final result = parse('');
      expect(result.images, isEmpty);
      expect(result.message, isNull);
    });

    test('null', () {
      final result = parse(null);
      expect(result.images, isEmpty);
      expect(result.message, isNull);
    });

    test('number', () {
      final result = parse(404);
      expect(result.images, isEmpty);
      expect(result.message, isNull);
    });

    test('string ที่ไม่ใช่ JSON', () {
      final result = parse('<html>Server Error</html>');
      expect(result.images, isEmpty);
      expect(result.message, isNull);
    });

    test('list เปล่า', () {
      final result = parse(<dynamic>[]);
      expect(result.images, isEmpty);
    });
  });

  group('รูปแบบของค่าที่นับเป็นรูป', () {
    test('relative path ต้องต่อ baseUrl ให้เป็น URL เต็ม', () {
      final result = parse({'Message': '/Tps/Bar/2026/09/x.png'});

      expect(result.images.single, '$_baseUrl/Tps/Bar/2026/09/x.png');
    });

    test('path แบบ ~/ ต้องตัด ~ ออกก่อนต่อ', () {
      final result = parse({'Message': '~/Tps/Bar/x.png'});

      expect(result.images.single, '$_baseUrl/Tps/Bar/x.png');
    });

    test('ต่อ path แล้วต้องไม่มี slash ซ้อน', () {
      final result = parseImageResponse({
        'Message': '//Tps/x.png',
      }, baseUrl: '$_baseUrl/');

      expect(result.images.single, '$_baseUrl/Tps/x.png');
    });

    test('data:image ปล่อยผ่านทั้งก้อน', () {
      const uri = 'data:image/png;base64,iVBORw0KGgo=';
      final result = parse({'Message': uri});

      expect(result.images.single, uri);
    });

    test('base64 ยาวเกิน 100 ตัวอักษรนับเป็นรูป', () {
      final base64 = 'A' * 120;
      final result = parse({'Message': base64});

      expect(result.images.single, base64);
      expect(result.message, isNull);
    });

    test('base64 ที่มี newline คั่นก็ยังนับเป็นรูป', () {
      final base64 = '${'A' * 76}\n${'B' * 76}';
      final result = parse({'Message': base64});

      expect(result.images, hasLength(1));
    });

    test('ข้อความไทยยาว ๆ ต้องไม่ถูกนับเป็น base64', () {
      final text = 'ไม่พบข้อมูลรูปของบาร์โค้ดนี้ ' * 10;
      final result = parse({'Message': text});

      expect(result.images, isEmpty);
      expect(result.message, isNotNull);
    });

    test('ข้อความอังกฤษยาวที่มีเว้นวรรคไม่ใช่ base64', () {
      const text =
          'No HTTP resource was found that matches the request URI and '
          'no action was found on the controller that matches the request.';
      final result = parse({'Message': text});

      expect(result.images, isEmpty);
      expect(result.message, text);
    });
  });

  group('โครงสร้างซ้อนกัน', () {
    test('เดินลงไปหารูปใน map ที่ซ้อนหลายชั้น', () {
      final result = parse({
        'data': {
          'result': {
            'items': [
              {'url': 'http://x/a.png'},
              {'url': 'http://x/b.png'},
            ],
          },
        },
      });

      expect(result.images, hasLength(2));
    });

    test('อ่าน message จากคีย์อื่นในชุดที่กำหนด', () {
      for (final key in ['msg', 'error', 'errorMessage', 'detail', 'remark']) {
        final result = parse({key: 'พบข้อผิดพลาด'});
        expect(result.message, 'พบข้อผิดพลาด', reason: 'คีย์ $key');
      }
    });

    test('คีย์ที่ไม่อยู่ในชุด message ไม่ถูกเก็บเป็นข้อความ', () {
      final result = parse({'status': 'ok', 'name': 'somchai'});

      expect(result.message, isNull);
      expect(result.images, isEmpty);
    });

    test('มีทั้งรูปและข้อความในก้อนเดียวได้', () {
      final result = parse({
        'Message': 'บาร์โค้ดนี้เคยถ่ายรูปไว้แล้ว',
        'images': ['http://x/a.png'],
      });

      expect(result.images, hasLength(1));
      expect(result.message, 'บาร์โค้ดนี้เคยถ่ายรูปไว้แล้ว');
    });

    test('body ที่มาเป็น JSON string ก็ต้อง decode ให้', () {
      final result = parse('{"Message":"http://x/a.png"}');

      expect(result.images.single, 'http://x/a.png');
    });
  });
}
