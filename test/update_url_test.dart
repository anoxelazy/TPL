import 'package:flutter_test/flutter_test.dart';

import 'package:claim/utils/update_service.dart';

void main() {
  group('ที่อยู่ของ update.json', () {
    test('ลอง raw ก่อน เพราะเห็นการแก้ทันทีที่ commit', () {
      expect(
        kUpdateJsonUrls.first,
        'https://raw.githubusercontent.com/anoxelazy/TPL/main/update.json',
      );
    });

    test('Pages ยังอยู่เป็นตัวสำรอง', () {
      // เอาออกเมื่อไหร่ แอปจะเงียบสนิทถ้า raw.githubusercontent ล่ม
      expect(
        kUpdateJsonUrls,
        contains('https://anoxelazy.github.io/TPL/update.json'),
      );
    });

    test('ทั้งสองชี้ repo เดียวกัน เพื่อให้เป็นไฟล์เดียวกันจริง', () {
      // คนละ repo เมื่อไหร่ = กลายเป็นสองไฟล์ที่ต้องอัปคู่กันตลอด
      // ลืมอัปอันใดอันหนึ่งแล้วเครื่องที่อ่านอันนั้นจะค้างเวอร์ชันเดิมถาวร
      for (final url in kUpdateJsonUrls) {
        expect(url, contains('anoxelazy'), reason: 'ต้องเป็นบัญชีเดียวกัน');
        expect(url, contains('TPL'), reason: 'ต้องเป็น repo TPL ทั้งคู่');
      }
    });

    test('มีสองที่ ไม่ซ้ำกัน และเป็น https ทั้งคู่', () {
      expect(kUpdateJsonUrls, hasLength(2));
      expect(kUpdateJsonUrls.toSet(), hasLength(2));
      for (final url in kUpdateJsonUrls) {
        expect(url, startsWith('https://'));
        expect(url, endsWith('update.json'), reason: 'ต่อ ?t= ท้ายตอนยิงจริง');
        expect(url, isNot(contains('?')), reason: 'ห้ามมี query ติดมาก่อน');
      }
    });
  });
}
