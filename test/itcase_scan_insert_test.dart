import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/itcase/itcase_form_page.dart';

void main() {
  group('สแกนเลขแล้ววางลงรายละเอียด', () {
    test('พิมพ์ไว้ก่อนแล้วสแกน ตัวหนังสือเดิมไม่หาย', () {
      const typed = 'ทำสถานะเอกสารไม่ได้ เลขที่';
      final result = insertScannedCode(typed, typed.length, 'A1234567');

      expect(result.text, 'ทำสถานะเอกสารไม่ได้ เลขที่ A1234567');
      expect(result.text, contains(typed), reason: 'ของเดิมต้องอยู่ครบ');
    });

    test('เคอร์เซอร์อยู่กลางข้อความ ท้ายข้อความก็ไม่หาย', () {
      const typed = 'เอกสาร ส่งไม่ผ่าน';
      final result = insertScannedCode(typed, 6, 'A1234567');

      expect(result.text, 'เอกสาร A1234567 ส่งไม่ผ่าน');
      expect(result.text, endsWith('ส่งไม่ผ่าน'));
    });

    test('ช่องว่างเปล่า ไม่มีช่องว่างนำหน้า', () {
      expect(insertScannedCode('', 0, 'A1234567').text, 'A1234567');
    });

    test('พิมพ์เว้นวรรคไว้แล้ว ไม่เติมซ้ำ', () {
      expect(insertScannedCode('เลขที่ ', 7, 'A1').text, 'เลขที่ A1');
    });

    test('เคอร์เซอร์เพี้ยนเกินความยาว ก็ยังไม่ทำข้อความหาย', () {
      final result = insertScannedCode('เลขที่', 999, 'A1');

      expect(result.text, 'เลขที่ A1');
    });

    test('เคอร์เซอร์ไปอยู่หลังเลขที่เพิ่งวาง พิมพ์ต่อได้เลย', () {
      final result = insertScannedCode('เลขที่', 6, 'A1');

      expect(result.selection.baseOffset, result.text.length);
    });
  });
}
