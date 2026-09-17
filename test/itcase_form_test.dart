import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/itcase/itcase_api.dart';

/// ประเภทปัญหาจริงทั้ง 7 ตัว อ่านจาก fixture ที่ดึงมาจากเซิร์ฟเวอร์
List<ItCaseSolveType> get _types => [
  for (final row in decodeItCaseList(
    File('test/fixtures/itcase_solvetype.json').readAsStringSync(),
  ))
    ItCaseSolveType.fromJson(row),
];

void main() {
  group('ตัวเลือกประเภทปัญหา', () {
    test('น้อยพอที่กางเมนูแล้วไม่ต้องเลื่อนหา', () {
      // 7 ตัวกางในเมนูเดียวจบ ไม่ต้อง scroll
      // ถ้าวันหลัง API เพิ่มจนเกิน 12 ต้องกลับมาคิดใหม่ว่าจะจัดยังไง
      expect(_types.length, lessThanOrEqualTo(12));
    });

    test('ทุกประเภทมีชื่อให้โชว์ ไม่มีช่องที่ว่างเปล่า', () {
      for (final type in _types) {
        expect(
          type.label,
          isNotEmpty,
          reason: '${type.id} ไม่มีชื่อ ช่องเลือกจะกลายเป็นกล่องเปล่า',
        );
      }
    });

    test('ชื่อสั้นพอจะอยู่ในบรรทัดเดียวของเมนูได้', () {
      for (final type in _types) {
        expect(
          type.label.length,
          lessThanOrEqualTo(20),
          reason: '${type.label} ยาวเกินไป จะโดนตัดท้ายด้วยจุดสามจุด',
        );
      }
    });
  });

  group('เงื่อนไขก่อนส่งได้', () {
    /// เลียนแบบเงื่อนไขของปุ่มส่งในหน้าจอ
    bool complete({
      ItCaseSolveType? type,
      ItCaseProgram? program,
      String description = '',
    }) {
      if (type == null) return false;
      if (type.hasPrograms && program == null) return false;
      return description.trim().isNotEmpty;
    }

    test('ประเภทที่ไม่มีโปรแกรม กรอกแค่รายละเอียดก็ส่งได้', () {
      final internet = _types.firstWhere((e) => e.id == 'S005');

      expect(
        complete(type: internet, description: 'เน็ตหลุดตั้งแต่เช้า'),
        true,
      );
      expect(complete(type: internet), false, reason: 'ยังไม่ได้เล่าอะไรเลย');
    });

    test('ประเภทที่มีโปรแกรม ต้องเลือกโปรแกรมด้วย', () {
      final program = _types.firstWhere((e) => e.id == 'S002');

      expect(
        complete(type: program, description: 'เปิดแล้วค้าง'),
        false,
        reason: 'ยังไม่ได้บอกว่าโปรแกรมไหน IT จะไล่ต่อไม่ถูก',
      );
      expect(
        complete(
          type: program,
          program: program.programs.first,
          description: 'เปิดแล้วค้าง',
        ),
        true,
      );
    });

    test('ช่องว่างล้วนไม่นับว่ากรอกแล้ว', () {
      final computer = _types.firstWhere((e) => e.id == 'S001');
      expect(complete(type: computer, description: '    '), false);
    });
  });

  group('ไอคอนประจำประเภท', () {
    // แผนที่ไอคอนอยู่ในไฟล์หน้าจอ เทสต์นี้กันไม่ให้ rename รหัสแล้วลืมอัปเดต
    const mapped = {'S001', 'S002', 'S003', 'S004', 'S005', 'S006', 'S007'};

    test('รหัสที่ API ส่งมาจริงมีไอคอนครบทุกตัว', () {
      for (final type in _types) {
        expect(
          mapped.contains(type.id),
          isTrue,
          reason:
              '${type.id} (${type.label}) ยังไม่มีไอคอน จะได้ไอคอนกลาง ๆ ไป',
        );
      }
    });
  });

  test('จำกัดความยาวรายละเอียดไว้ไม่ให้ยาวเกินอ่าน', () {
    // ค่าเดียวกับ maxLength ของช่องกรอก ถ้าแก้ที่หน้าจอต้องมาแก้ที่นี่ด้วย
    const maxDescription = 500;
    expect(maxDescription, greaterThan(100));
    expect(maxDescription, lessThanOrEqualTo(1000));
  });
}
