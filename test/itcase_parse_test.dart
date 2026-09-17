import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/itcase/itcase_api.dart';

/// response จริงที่ดึงมาจากเซิร์ฟเวอร์ ไม่ใช่ตัวอย่างที่เขียนขึ้นเอง
String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

List<ItCaseSolveType> get _solveTypes => [
  for (final row in decodeItCaseList(_fixture('itcase_solvetype.json')))
    ItCaseSolveType.fromJson(row),
];

List<ItCaseStatus> get _statuses => [
  for (final row in decodeItCaseList(_fixture('itcase_statuslist.json')))
    ItCaseStatus.fromJson(row),
];

void main() {
  group('ประเภทปัญหา', () {
    test('อ่านครบทั้ง 7 ประเภทจาก response จริง', () {
      final types = _solveTypes;

      expect(types.length, 7);
      expect(types.map((e) => e.id), [
        'S001',
        'S002',
        'S003',
        'S004',
        'S005',
        'S006',
        'S007',
      ]);
      expect(types.first.label, 'คอมพิวเตอร์');
      expect(types.first.nameEn, 'Computer');
    });

    test('มีแค่ S002 กับ S003 ที่มีโปรแกรมให้เลือก', () {
      final withPrograms = _solveTypes.where((e) => e.hasPrograms);

      expect(withPrograms.map((e) => e.id), ['S002', 'S003']);
      for (final type in _solveTypes.where((e) => !e.hasPrograms)) {
        expect(
          type.programs,
          isEmpty,
          reason: '${type.id} ไม่ควรมีโปรแกรม หน้าจอจะได้ซ่อนช่องนั้น',
        );
      }
    });

    test('โปรแกรมของ S002 อ่านชื่อออก ทั้งที่ API สะกด deatils ตกไป', () {
      final programs = _solveTypes.firstWhere((e) => e.id == 'S002').programs;

      expect(programs.length, 9);
      expect(programs.first.id, 'P001');
      expect(programs.first.name, 'ทีพีเอส(รถเขียว TPS)');
      expect(programs.last.id, 'P999');
      expect(
        programs.every((e) => e.name.isNotEmpty),
        isTrue,
        reason: 'ชื่อว่างแปลว่าอ่านฟิลด์ program_deatils ไม่เจอ',
      );
    });

    test('ไม่มีชื่อไทย ถอยไปใช้อังกฤษ แล้วค่อยใช้รหัส', () {
      expect(
        ItCaseSolveType.fromJson(const {
          'solve_id': 'S009',
          'details_en': 'Network',
        }).label,
        'Network',
      );
      expect(
        ItCaseSolveType.fromJson(const {'solve_id': 'S009'}).label,
        'S009',
      );
    });
  });

  group('ขั้นตอนสถานะ', () {
    test('อ่านครบทั้ง 8 ขั้นจาก response จริง', () {
      final statuses = _statuses;

      expect(statuses.length, 8);
      expect(statuses.map((e) => e.id), [
        'OP',
        'RC',
        'AS1',
        'AS2',
        'IN',
        'FN',
        'CF',
        'IN2',
      ]);
    });

    test('โชว์ข้อความฝั่งผู้แจ้ง เพราะคนใช้แอปคือผู้แจ้ง', () {
      final finished = _statuses.firstWhere((e) => e.id == 'FN');

      expect(finished.label, 'แก้ไขเสร็จสิ้น กรุณาตรวจสอบความเรียบร้อย');
      expect(
        finished.officer,
        'แก้ไขเสร็จสิ้น อยู่ระหว่างผู้แจ้งยืนยันปิดงาน',
        reason: 'ของเจ้าหน้าที่เก็บไว้โชว์เป็นบรรทัดรอง',
      );
    });

    test('มีแต่ข้อความเจ้าหน้าที่ ก็ยังมีอะไรให้โชว์', () {
      expect(
        ItCaseStatus.fromJson(const {
          'status_id': 'XX',
          'officer_details': 'รับงาน',
        }).label,
        'รับงาน',
      );
    });
  });

  group('แกะ body', () {
    test(
      'รับ String ได้ เผื่อ dio ไม่ decode ให้เพราะ content-type ไม่ตรง',
      () {
        expect(decodeItCaseList('[{"solve_id":"S001"}]').length, 1);
      },
    );

    test('รับ List ที่ decode มาแล้วได้ด้วย', () {
      expect(
        decodeItCaseList([
          const {'solve_id': 'S001'},
        ]).length,
        1,
      );
    });

    test('ของที่อ่านไม่ได้คืนลิสต์ว่าง ไม่ throw', () {
      expect(decodeItCaseList(null), isEmpty);
      expect(decodeItCaseList(''), isEmpty);
      expect(decodeItCaseList('ไม่ใช่ json'), isEmpty);
      expect(decodeItCaseList(const {'error': 'x'}), isEmpty);
      expect(decodeItCaseList(42), isEmpty);
    });

    test('แถวที่ไม่มีรหัสถูกตัดทิ้ง กัน dropdown ค่าซ้ำ', () {
      final rows = decodeItCaseList('[{"details_th":"ไม่มีรหัส"}]');

      expect(rows.length, 1, reason: 'แกะเป็นแถวได้');
      expect(
        ItCaseSolveType.fromJson(rows.first).id,
        isEmpty,
        reason: 'แต่ไม่มีรหัส fetchSolveTypes จะกรองออกก่อนถึงหน้าจอ',
      );
    });
  });

  group('รหัสโปรแกรมที่ส่งไปกับเคส', () {
    test('ไม่ได้เลือกโปรแกรม ส่ง P000 ไม่ใช่ค่าว่าง', () {
      expect(itCaseProgramIdOf(null), kItCaseNoProgramId);
      expect(itCaseProgramIdOf(''), 'P000');
      expect(itCaseProgramIdOf('   '), 'P000');
    });

    test('เลือกแล้วส่งรหัสที่เลือก', () {
      expect(itCaseProgramIdOf('P001'), 'P001');
      expect(itCaseProgramIdOf(' P999 '), 'P999', reason: 'ตัดช่องว่างให้ด้วย');
    });

    test('ประเภทที่ไม่มีโปรแกรมทุกตัวจะได้ P000', () {
      for (final type in _solveTypes.where((e) => !e.hasPrograms)) {
        expect(
          itCaseProgramIdOf(null),
          'P000',
          reason: '${type.id} (${type.label}) ไม่มีโปรแกรมให้เลือก',
        );
      }
    });
  });

  /// ป๊อปอัปตอนส่งสำเร็จเอาค่านี้ไปโชว์ตรง ๆ หลุดมาทั้งก้อนเมื่อไหร่
  /// ผู้ใช้จะเห็น "{success: true, message: ...}" เต็ม ๆ กลางจอ
  group('ข้อความตอบกลับตอนส่งเคส', () {
    test('ห่อมาเป็น json เอาเฉพาะ message', () {
      expect(
        itCaseResultOf({
          'success': true,
          'message': 'บันทึกเอกสารสำเร็จ',
        }).message,
        'บันทึกเอกสารสำเร็จ',
      );
    });

    test('ห่อมาเป็น json ที่ยังเป็นข้อความ ก็แกะให้', () {
      expect(
        itCaseResultOf(
          '{"success":true,"message":"บันทึกเอกสารสำเร็จ"}',
        ).message,
        'บันทึกเอกสารสำเร็จ',
      );
    });

    test('ตอบข้อความเปล่า ๆ มาก็ใช้ได้เลย', () {
      expect(
        itCaseResultOf('บันทึกเอกสารสำเร็จ').message,
        'บันทึกเอกสารสำเร็จ',
      );
      expect(itCaseResultOf('  บันทึกแล้ว  ').message, 'บันทึกแล้ว');
    });

    test('ชื่อช่องตัวพิมพ์ใหญ่เล็กไม่ตรงก็ยังเจอ', () {
      expect(itCaseResultOf({'Message': 'สำเร็จ'}).message, 'สำเร็จ');
      expect(itCaseResultOf({'MSG': 'สำเร็จ'}).message, 'สำเร็จ');
      expect(itCaseResultOf({'Result': 'สำเร็จ'}).message, 'สำเร็จ');
    });

    test('ตอบเป็น array แถวเดียวก็แกะแถวแรก', () {
      expect(
        itCaseResultOf([
          {'message': 'สำเร็จ'},
        ]).message,
        'สำเร็จ',
      );
    });

    test('ไม่มีข้อความให้ ก็ใช้ข้อความสำรอง ไม่ปล่อยป๊อปอัปหัวโล้น', () {
      for (final body in [
        null,
        '',
        'null',
        {'success': true},
        <dynamic>[],
      ]) {
        expect(
          itCaseResultOf(body).message,
          'ส่งเรื่องแจ้งเคสแล้ว',
          reason: 'body = $body',
        );
      }
    });

    test('ช่องที่ห่อของซ้อนอีกชั้นไม่นับเป็นข้อความ', () {
      expect(
        itCaseResultOf({
          'result': {'jobNo': 'IT1234567'},
          'message': 'สำเร็จ',
        }).message,
        'สำเร็จ',
        reason: 'result เป็น Map ต้องข้ามไปหา message ไม่ใช่โชว์ปีกกา',
      );
    });

    test('json พังก็คืนข้อความดิบ ดีกว่าเงียบ', () {
      expect(itCaseResultOf('{ไม่ใช่ json').message, '{ไม่ใช่ json');
    });
  });

  /// ป๊อปอัปยกเลขเคสออกมาเป็นช่องของตัวเองให้กดคัดลอก
  /// ไม่รู้ว่าเซิร์ฟเวอร์จะแยกช่องให้หรือพ่วงมาในข้อความ จึงต้องรับได้ทั้งคู่
  group('เลขเคสจาก response', () {
    test('แยกช่องมาให้ ก็หยิบจากช่องนั้น', () {
      final result = itCaseResultOf({
        'success': true,
        'message': 'บันทึกเอกสารสำเร็จ',
        'jobNo': 'IT1234567',
      });

      expect(result.caseNumber, 'IT1234567');
      expect(result.hasCaseNumber, isTrue);
      expect(result.message, 'บันทึกเอกสารสำเร็จ');
    });

    test('ชื่อช่องอะไรก็ได้ ไม่ต้องเดาให้ถูก', () {
      for (final key in ['jobNo', 'job_no', 'caseNo', 'docNo', 'ticket']) {
        expect(
          itCaseResultOf({'message': 'สำเร็จ', key: 'IT1234567'}).caseNumber,
          'IT1234567',
          reason: 'ช่อง $key',
        );
      }
    });

    test('พ่วงมาในข้อความเลยก็ดึงออกมาได้', () {
      final result = itCaseResultOf({
        'message': 'บันทึกเอกสารสำเร็จ เลขเคส IT1234567',
      });

      expect(result.caseNumber, 'IT1234567');
      expect(
        result.message,
        'บันทึกเอกสารสำเร็จ',
        reason: 'ยกไปโชว์ในช่องคัดลอกแล้ว ไม่ต้องค้างอยู่ในข้อความอีก',
      );
    });

    test('ตัดเลขเคสแล้วไม่เหลือคำนำหน้าห้อยอยู่', () {
      for (final message in [
        'บันทึกเอกสารสำเร็จ เลขเคส IT1234567',
        'บันทึกเอกสารสำเร็จ เลขที่เคส IT1234567',
        'บันทึกเอกสารสำเร็จ เคส IT1234567',
        'บันทึกเอกสารสำเร็จ IT1234567',
        'บันทึกเอกสารสำเร็จ : IT1234567',
      ]) {
        expect(
          itCaseResultOf({'message': message}).message,
          'บันทึกเอกสารสำเร็จ',
          reason: message,
        );
      }
    });

    test('ข้อความมีแต่เลขเคส ตัดแล้วว่างก็คืนของเดิม', () {
      final result = itCaseResultOf({'message': 'IT1234567'});

      expect(result.caseNumber, 'IT1234567');
      expect(result.message, 'IT1234567', reason: 'ดีกว่าโชว์ป๊อปอัปหัวว่าง');
    });

    test('ตัวพิมพ์เล็กกับขีดคั่นก็ยังจับได้ แล้วปรับเป็นตัวใหญ่', () {
      expect(itCaseResultOf({'jobNo': 'it1234567'}).caseNumber, 'IT1234567');
      expect(itCaseResultOf({'jobNo': 'IT-1234567'}).caseNumber, 'IT-1234567');
    });

    test('ไม่มีเลขเคสมา ก็ไม่ต้องโชว์ช่องคัดลอก', () {
      final result = itCaseResultOf({'message': 'บันทึกเอกสารสำเร็จ'});

      expect(result.caseNumber, isEmpty);
      expect(result.hasCaseNumber, isFalse);
    });

    test('เลขอื่นที่ไม่ใช่รูปแบบเลขเคส ไม่โดนจับมาผิดตัว', () {
      expect(itCaseResultOf({'message': 'สำเร็จ 12345'}).caseNumber, isEmpty);
      expect(itCaseResultOf({'message': 'ITEM123'}).caseNumber, isEmpty);
      expect(
        itCaseResultOf({'message': 'สำเร็จ'}).caseNumber,
        isEmpty,
        reason: 'ไม่มีตัวเลขเลย',
      );
    });
  });

  test('นามสกุลรูปตรงกับไบต์จริงที่ส่ง คือ JPEG', () {
    // ตัวอย่าง body ที่ได้มาตอนแรกเขียน .png แต่ตัวย่อรูปของแอป encode เป็น JPEG
    // ส่ง .png ไปเซิร์ฟเวอร์จะเซฟไฟล์ที่เปิดไม่ขึ้น
    expect(kItCaseImageExtension, '.jpg');
  });
}
