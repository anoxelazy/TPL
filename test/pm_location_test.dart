import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/pm/pm_location.dart';

void main() {
  group('parseLocations', () {
    test('อ่านไฟล์จริงที่จะเอาไปวางบนลิงก์ได้', () {
      final raw = File('supabase/pmlocations.json').readAsStringSync();
      final list = parseLocations(raw);

      expect(list, isNotNull);
      expect(list, hasLength(26));
      expect(list!.first.code, '0');
      expect(list.firstWhere((l) => l.code == '2').name, 'IT');
      expect(list.firstWhere((l) => l.code == '25').name, 'WH5');
    });

    test('ไฟล์ที่วางบนลิงก์ต้องตรงกับค่าสำรองในแอป', () {
      // ถ้าไม่ตรง คนแก้ไฟล์บนลิงก์แล้วลืมแก้ค่าสำรอง เครื่องที่โหลดไฟล์ไม่ได้
      // จะเห็นชื่อคนละชุดกับเครื่องที่โหลดได้
      final list = parseLocations(
        File('supabase/pmlocations.json').readAsStringSync(),
      )!;

      expect(list.length, kFallbackLocations.length);
      for (var i = 0; i < list.length; i++) {
        expect(list[i].code, kFallbackLocations[i].code);
        expect(list[i].name, kFallbackLocations[i].name);
      }
    });

    test('ข้ามรายการที่ code หรือ name ว่าง ไม่ทิ้งทั้งไฟล์', () {
      final body = jsonEncode({
        'locations': [
          {'code': '1', 'name': 'เลขา'},
          {'code': '', 'name': 'ไม่มีรหัส'},
          {'code': '2', 'name': ''},
          {'code': '3', 'name': 'Sale'},
        ],
      });

      final list = parseLocations(body);
      expect(list, hasLength(2));
      expect(list!.map((l) => l.code).toList(), ['1', '3']);
    });

    test('ไฟล์พังหรือผิดรูปแบบคืน null ไม่ throw', () {
      expect(parseLocations(null), isNull);
      expect(parseLocations(''), isNull);
      expect(parseLocations('{'), isNull);
      expect(parseLocations('[]'), isNull);
      expect(parseLocations('{"locations":[]}'), isNull);
      expect(parseLocations('{"locations":"ไม่ใช่ลิสต์"}'), isNull);
    });

    test('code ที่เป็นตัวเลขใน json ก็ยังอ่านเป็นสตริงได้', () {
      // เผื่อคนแก้ไฟล์เขียน code: 2 แทน "2"
      final list = parseLocations('{"locations":[{"code":2,"name":"IT"}]}');

      expect(list, hasLength(1));
      expect(list!.first.code, '2');
    });
  });

  group('แปลงรหัสเป็นชื่อ', () {
    test('รหัสที่รู้จักได้ชื่อ', () {
      expect(PmLocations.I.nameOf('2'), 'IT');
      expect(PmLocations.I.labelOf('2'), 'IT');
      expect(PmLocations.I.labelOf('15'), 'WH1');
    });

    test('เว้นวรรครอบรหัสไม่ทำให้หาไม่เจอ', () {
      expect(PmLocations.I.nameOf(' 2 '), 'IT');
    });

    test('รหัสที่ไม่รู้จักบอกเลขไป ไม่ปล่อยว่าง', () {
      expect(PmLocations.I.nameOf('999'), isNull);
      expect(PmLocations.I.labelOf('999'), 'รหัส 999');
    });

    test('ไม่มีรหัสเลยแสดงขีด', () {
      expect(PmLocations.I.labelOf(null), '-');
      expect(PmLocations.I.labelOf(''), '-');
      expect(PmLocations.I.labelOf('   '), '-');
    });
  });
}
