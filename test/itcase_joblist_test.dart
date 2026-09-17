import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/itcase/itcase_api.dart';

/// รายการอ้างอิงสองตัวนี้เป็น response จริงจากเซิร์ฟเวอร์ ใช้ทดสอบการแปลรหัส
String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

List<ItCaseStatus> get _statuses => [
  for (final row in decodeItCaseList(_fixture('itcase_statuslist.json')))
    ItCaseStatus.fromJson(row),
];

List<ItCaseSolveType> get _types => [
  for (final row in decodeItCaseList(_fixture('itcase_solvetype.json')))
    ItCaseSolveType.fromJson(row),
];

/// ⚠️ แถวของ joblist ข้างล่างนี้เขียนขึ้นเอง ไม่ใช่ response จริง
///
/// swagger บอกแค่ว่า endpoint ตอบ "Success" ไม่ได้บอกชื่อช่อง และยิงดูตรง ๆ
/// ไม่ได้เพราะต้องมี token ของผู้ใช้ ตัวแปลงจึงรับชื่อช่องได้หลายแบบ
/// เทสต์นี้คุมว่ารับได้ทั้ง snake_case และ camelCase ไม่ใช่ยืนยันชื่อช่องจริง
///
/// ได้ response จริงมาเมื่อไหร่ ให้บันทึกเป็น fixture แล้วเพิ่มเทสต์ทับอันนี้
void main() {
  group('อ่านแถวเคส', () {
    test('อ่าน snake_case แบบที่ endpoint อื่นของ ITRepair ใช้', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'status_id': 'IN',
        'job_type': 'S002',
        'program_id': 'P001',
        'description': 'เข้าโปรแกรมไม่ได้',
        'create_date': '2026-09-15T10:30:00',
        'officer_name': 'สมชาย',
      });

      expect(job.id, 'IT2500123');
      expect(job.statusId, 'IN');
      expect(job.typeId, 'S002');
      expect(job.description, 'เข้าโปรแกรมไม่ได้');
      expect(job.officer, 'สมชาย');
      expect(job.createdAt, DateTime(2026, 9, 15, 10, 30));
    });

    test('อ่าน camelCase แบบที่ระบบ PM ใช้ ได้ค่าเดียวกัน', () {
      final job = ItCaseJob.fromJson(const {
        'jobId': 'IT2500123',
        'statusId': 'IN',
        'jobType': 'S002',
        'programId': 'P001',
        'description': 'เข้าโปรแกรมไม่ได้',
        'createDate': '2026-09-15 10:30:00',
        'officerName': 'สมชาย',
      });

      expect(job.id, 'IT2500123');
      expect(job.statusId, 'IN');
      expect(job.createdAt, DateTime(2026, 9, 15, 10, 30));
      expect(job.officer, 'สมชาย');
    });

    test('ช่องที่ไม่มีเป็นค่าว่าง ไม่ใช่ null และไม่พัง', () {
      final job = ItCaseJob.fromJson(const {'job_id': 'IT2500123'});

      expect(job.description, isEmpty);
      expect(job.officer, isEmpty);
      expect(job.typeId, isEmpty);
      expect(job.createdAt, isNull);
      expect(job.isUsable, isTrue);
    });

    test('แถวที่ไม่มีทั้งเลขเคสและรายละเอียด ถือว่าใช้ไม่ได้', () {
      expect(
        ItCaseJob.fromJson(const {'status_id': 'OP'}).isUsable,
        isFalse,
        reason: 'โชว์แล้วจะเป็นการ์ดเปล่า ไม่มีอะไรให้อ่าน',
      );
    });

    test('ช่องที่เป็นก้อนซ้อนไม่ถูกหยิบมาเป็นข้อความ', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'details': {'a': 1},
      });

      expect(
        job.description,
        isEmpty,
        reason: 'เอา Map มาโชว์จะได้วงเล็บปีกกาติดมาทั้งก้อน',
      );
    });
  });

  group('แปลรหัสเป็นข้อความ', () {
    test('เทียบสถานะจาก repairstatuslist เมื่อแถวส่งมาแต่รหัส', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'status_id': 'FN',
      });

      expect(
        job.statusTextFrom(_statuses),
        'แก้ไขเสร็จสิ้น กรุณาตรวจสอบความเรียบร้อย',
      );
    });

    test('ใช้ข้อความที่ติดมากับแถวก่อน ถ้ามี', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'status_id': 'FN',
        'status_details': 'ปิดงานแล้ว',
      });

      expect(job.statusTextFrom(_statuses), 'ปิดงานแล้ว');
    });

    test('รหัสที่ไม่มีในรายการ โชว์รหัสดิบ ไม่ใช่ช่องว่าง', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'status_id': 'ZZ',
      });

      expect(job.statusTextFrom(_statuses), 'ZZ');
      expect(job.statusTextFrom(const []), 'ZZ');
    });

    test('เทียบประเภทปัญหาและชื่อโปรแกรมจาก repairsolvetype', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'job_type': 'S002',
        'program_id': 'P001',
      });

      expect(job.typeTextFrom(_types), 'โปรแกรม');
      expect(job.programTextFrom(_types), 'ทีพีเอส(รถเขียว TPS)');
    });

    test('เคสที่ไม่ได้ผูกกับโปรแกรม ไม่ต้องโชว์บรรทัดโปรแกรม', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'job_type': 'S001',
        'program_id': kItCaseNoProgramId,
      });

      expect(job.programTextFrom(_types), isEmpty);
    });
  });

  group('ขั้นของเคส', () {
    test('เปิดเอกสารคือรอรับเรื่อง ปิดงานคือจบ', () {
      expect(itCaseStageOf('OP'), ItCaseStage.waiting);
      expect(itCaseStageOf('FN'), ItCaseStage.review);
      expect(itCaseStageOf('CF'), ItCaseStage.done);
    });

    test('รหัสระหว่างทางทั้งหมดคือกำลังดำเนินการ', () {
      for (final id in const ['RC', 'AS1', 'AS2', 'IN', 'IN2']) {
        expect(itCaseStageOf(id), ItCaseStage.working, reason: id);
      }
    });

    test('รหัสที่ไม่รู้จักเดาว่ายังไม่จบ ไม่ใช่จบแล้ว', () {
      expect(itCaseStageOf(''), ItCaseStage.working);
      expect(itCaseStageOf('XX'), ItCaseStage.working);
    });
  });

  group('วันที่', () {
    test('อ่านรูปแบบที่ .NET ส่งมา', () {
      expect(
        itCaseDateOf('2026-09-15T10:30:00'),
        DateTime(2026, 9, 15, 10, 30),
      );
      expect(itCaseDateOf('2026-09-15 10:30'), DateTime(2026, 9, 15, 10, 30));
      expect(itCaseDateOf('2026-09-15'), DateTime(2026, 9, 15));
    });

    test('วันที่แบบไทยปี พ.ศ. แปลงเป็น ค.ศ.', () {
      expect(itCaseDateOf('15/09/2569 10:30'), DateTime(2026, 9, 15, 10, 30));
      expect(itCaseDateOf('15/09/2026'), DateTime(2026, 9, 15));
    });

    test('อ่านไม่ออกคืน null การ์ดจะซ่อนบรรทัดวันที่ไปเอง', () {
      expect(itCaseDateOf(''), isNull);
      expect(itCaseDateOf('-'), isNull);
      expect(itCaseDateOf('null'), isNull);
    });
  });

  test('เรียงใหม่สุดขึ้นก่อน แถวไม่มีวันที่ไปต่อท้าย', () {
    final jobs = [
      ItCaseJob.fromJson(const {'job_id': 'A', 'create_date': '2026-09-01'}),
      ItCaseJob.fromJson(const {'job_id': 'B'}),
      ItCaseJob.fromJson(const {'job_id': 'C', 'create_date': '2026-09-15'}),
    ];

    sortItCaseJobs(jobs);

    expect(jobs.map((e) => e.id), ['C', 'A', 'B']);
  });

  group('ช่องที่ยังไม่รู้จักในแถว', () {
    test('ช่องที่หน้าจอโชว์อยู่แล้ว ไม่โผล่ซ้ำท้ายการ์ด', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'status_id': 'IN',
        'job_type': 'S002',
        'program_id': 'P001',
        'description': 'เข้าโปรแกรมไม่ได้',
        'create_date': '2026-09-15T10:30:00',
        'officer_name': 'สมชาย',
      });

      expect(job.extras, isEmpty);
    });

    test('ช่องที่ไม่รู้จักไม่ถูกทิ้ง แต่เอามาโชว์ต่อท้าย', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2500123',
        'branch': 'สำนักงานใหญ่',
        'priority': 'ด่วน',
        'weird_field': 'ค่าอะไรสักอย่าง',
      });

      expect(job.extras.map((e) => e.label), [
        'สาขา',
        'ความเร่งด่วน',
        'weird_field',
      ]);
      expect(job.extras.first.value, 'สำนักงานใหญ่');
      expect(
        job.extras.last.label,
        'weird_field',
        reason: 'ไม่รู้จักชื่อช่องก็ยังต้องเห็นค่า ดีกว่าหายไปเงียบ ๆ',
      );
    });

    test('รหัสภายในกับรูป base64 ไม่ต้องเอามาโชว์', () {
      final job = ItCaseJob.fromJson({
        'job_id': 'IT2500123',
        'emp_no': '12345',
        'imageBase64': 'A' * 500,
        'image_extension': '.jpg',
      });

      expect(job.extras, isEmpty);
    });

    test('ก้อนซ้อนกับค่ายาวเกินไม่เอามาโชว์บนการ์ด', () {
      final job = ItCaseJob.fromJson({
        'job_id': 'IT2500123',
        'log': 'x' * 300,
        'nested': const {'a': 1},
        'flag': true,
      });

      expect(job.extras, isEmpty);
    });
  });

  group('สถานะที่ส่งรหัสกับคำอธิบายติดกันมา', () {
    test('เว็บโชว์ CF:ตรวจสอบเรียบร้อยแล้ว แยกรหัสออกได้', () {
      expect(itCaseStatusIdIn('CF:ตรวจสอบเรียบร้อยแล้ว'), 'CF');
      expect(itCaseStatusIdIn('RC:รับทราบปัญหาแล้ว'), 'RC');
      expect(itCaseStatusIdIn('AS1:ผู้รับงานดำเนินการด้วยตนเอง'), 'AS1');
      expect(itCaseStatusIdIn('CF'), 'CF');
      expect(itCaseStatusIdIn('ตรวจสอบเรียบร้อยแล้ว'), isEmpty);
    });

    test('ป้ายสถานะตัดรหัสนำหน้าออก ไม่โชว์ CF: ซ้ำ', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2026106446',
        'status': 'CF:ตรวจสอบเรียบร้อยแล้ว',
      });

      expect(job.statusId, 'CF');
      expect(job.statusTextFrom(const []), 'ตรวจสอบเรียบร้อยแล้ว');
      expect(
        job.stage,
        ItCaseStage.done,
        reason: 'แยกรหัสไม่ออกแล้วสีป้ายจะเป็นเหลืองทั้งที่เคสปิดแล้ว',
      );
    });

    test('ส่งมาแต่รหัสเปล่า ๆ ยังไปเทียบคำอธิบายจากตารางอ้างอิงได้', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2026106446',
        'status_id': 'CF',
        'status_details': 'CF',
      });

      expect(job.statusTextFrom(_statuses), 'ตรวจสอบเรียบร้อยแล้ว');
    });
  });

  test('วันที่แบบ 15-09-2026 23:11 ที่เว็บโชว์ อ่านออก', () {
    expect(itCaseDateOf('15-09-2026 23:11'), DateTime(2026, 9, 15, 23, 11));
    expect(itCaseDateOf('15-09-2026'), DateTime(2026, 9, 15));
    expect(itCaseDateOf('15.09.2026 23:11'), DateTime(2026, 9, 15, 23, 11));
  });

  group('เปอร์เซ็นต์ความคืบหน้า', () {
    test('เดินหน้าไปตามลำดับที่เอกสารเดิน', () {
      expect(itCaseProgressOf('OP'), 10);
      expect(itCaseProgressOf('RC'), 25);
      expect(itCaseProgressOf('AS1'), 40);
      expect(itCaseProgressOf('AS2'), 40);
      expect(itCaseProgressOf('IN'), 60);
      expect(itCaseProgressOf('FN'), 90);
      expect(itCaseProgressOf('CF'), 100);
    });

    test('งานที่ถูกตีกลับถอยลงมา ไม่ใช่เดินหน้าต่อจากรอตรวจรับ', () {
      expect(itCaseProgressOf('IN2'), lessThan(itCaseProgressOf('IN')));
      expect(itCaseProgressOf('IN2'), lessThan(itCaseProgressOf('FN')));
    });

    test('ปิดงานแล้วเต็ม 100 ไม่มีสถานะไหนเกินหน้า', () {
      for (final id in const ['OP', 'RC', 'AS1', 'AS2', 'IN', 'IN2', 'FN']) {
        expect(itCaseProgressOf(id), lessThan(100), reason: id);
      }
    });

    test('รหัสที่ไม่รู้จักคืน 0 หน้าจอจะซ่อนแถบไปเลย', () {
      expect(itCaseProgressOf(''), 0);
      expect(itCaseProgressOf('ZZ'), 0);
    });

    test('อ่าน % จากแถวเคสได้ตรงกับสถานะ', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2026106446',
        'job_status': 'FN',
      });

      expect(job.progress, 90);
    });
  });

  group('เคสที่เพิ่งแจ้งสำเร็จ', () {
    test('ปั้นแถวจากเลขเคสได้ ใช้เปิดหน้ารายละเอียดต่อทันที', () {
      final job = ItCaseJob.justSent('IT2026106446');

      expect(job.id, 'IT2026106446');
      // หน้ารายการไม่ยอมเปิดรายละเอียดให้แถวที่ไม่มีเลขเคส
      expect(job.isUsable, isTrue);
    });

    test('เคสที่เพิ่งเปิดอยู่ขั้นรอทีม IT รับเรื่อง ไม่ใช่กำลังทำอยู่', () {
      expect(ItCaseJob.justSent('IT2026106446').stage, ItCaseStage.waiting);
    });

    test('ไม่มีช่องอื่นติดมา หัวหน้ารายละเอียดจะได้ไม่โชว์ของที่ยังไม่รู้', () {
      expect(ItCaseJob.justSent('IT2026106446').extras, isEmpty);
    });
  });

  group('ช่องค้นหาในหน้าขั้นตอนการดำเนินงาน', () {
    final job = ItCaseJob.fromJson(const {
      'job_id': 'IT2026106446',
      'job_status': 'IN',
      'job_description': 'เข้าโปรแกรม TMS ไม่ได้',
      'job_type_details': 'โปรแกรม',
      'receive_by': 'ทักษิณ โพงจ่าม',
    });

    test('ค้นด้วยเลขเคสได้ ทั้งเลขเต็มและท่อนท้ายที่คนจำได้', () {
      expect(job.searchIndex, contains('it2026106446'));
      expect(job.searchIndex, contains('106446'));
    });

    test('ค้นด้วยอาการที่พิมพ์ไว้ตอนแจ้งได้', () {
      expect(job.searchIndex, contains('tms'));
    });

    test('ค้นด้วยชื่อผู้รับงานและประเภทปัญหาได้', () {
      expect(job.searchIndex, contains('ทักษิณ'));
      expect(job.searchIndex, contains('โปรแกรม'));
    });

    test('พิมพ์ใหญ่เล็กไม่ต้องตรง ช่องค้นหาเทียบด้วยตัวพิมพ์เล็กล้วน', () {
      expect(job.searchIndex, isNot(contains('IT2026106446')));
      expect(job.searchIndex, job.searchIndex.toLowerCase());
    });

    test('แถวที่ช่องว่างเยอะ ไม่พังและไม่ไปตรงกับคำค้นมั่ว ๆ', () {
      final bare = ItCaseJob.justSent('IT2026106447');

      expect(bare.searchIndex, contains('it2026106447'));
      expect(bare.searchIndex.contains('เข้าโปรแกรม'), isFalse);
    });
  });
}
