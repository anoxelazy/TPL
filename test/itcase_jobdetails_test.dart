import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:claim/page/itcase/itcase_api.dart';
import 'package:claim/page/itcase/itcase_job_card.dart';
import 'package:claim/utils/mobile_api.dart';

/// รายการสถานะเป็น response จริงจากเซิร์ฟเวอร์ ใช้ทดสอบการแปลรหัส
List<ItCaseStatus> get _statuses => [
  for (final row in decodeItCaseList(
    File('test/fixtures/itcase_statuslist.json').readAsStringSync(),
  ))
    ItCaseStatus.fromJson(row),
];

List<ItCaseSolveType> get _types => [
  for (final row in decodeItCaseList(
    File('test/fixtures/itcase_solvetype.json').readAsStringSync(),
  ))
    ItCaseSolveType.fromJson(row),
];

/// ⚠️ แถวของ jobdetails ข้างล่างนี้เขียนขึ้นเอง ไม่ใช่ response จริง
///
/// ชื่อช่องอ้างจากป้ายในป๊อปอัปรายละเอียดของเว็บ (เลขเอกสาร วันที่แจ้ง ผู้แจ้ง
/// ประเภทปัญหา ระบบหรือโปรแกรม รายละเอียด ภาพประกอบ รายละเอียดการแก้ไข
/// รูปภาพปิดงาน ผู้รับงาน) ส่วนตัวสะกดจริงยังไม่ยืนยัน เทสต์นี้จึงคุมว่าตัวแปลง
/// รับได้หลายแบบ และช่องที่เดาไม่ถูกต้องไม่หายไปไหน
void main() {
  // itCaseFieldText จัดวันที่เป็นภาษาไทย ไม่โหลดไว้ก่อนจะโยน
  setUpAll(() => initializeDateFormatting('th', null));

  group('แกะแถวจาก body', () {
    test('ตอบเป็น array ตรง ๆ', () {
      final rows = itCaseDetailRows([
        {'job_id': 'IT2026106446'},
      ]);

      expect(rows.length, 1);
      expect(rows.first['job_id'], 'IT2026106446');
    });

    test('ตอบเป็นก้อนที่ห่อ array ไว้ข้างใน', () {
      final rows = itCaseDetailRows({
        'jobNo': 'IT2026106446',
        'details': [
          {'status_id': 'CF'},
        ],
      });

      expect(rows.length, 1);
      expect(rows.first['status_id'], 'CF');
    });

    test('ตอบเป็น object เดี่ยว นับเป็นหนึ่งแถว', () {
      final rows = itCaseDetailRows({'job_id': 'IT2026106446'});

      expect(rows.length, 1);
    });

    test('ตอบเป็นข้อความ json ที่ content-type ไม่ใช่ json', () {
      expect(itCaseDetailRows('[{"status_id":"CF"}]').length, 1);
    });

    test('ของที่อ่านไม่ออกคืนรายการเปล่า ไม่โยน', () {
      expect(itCaseDetailRows(null), isEmpty);
      expect(itCaseDetailRows(''), isEmpty);
      expect(itCaseDetailRows('ไม่ใช่ json'), isEmpty);
      expect(itCaseDetailRows(const []), isEmpty);
    });
  });

  group('อ่านรายละเอียดเคส', () {
    final detail = ItCaseJobDetail.fromJson(const {
      'job_id': 'IT2026106446',
      'inform_date': '15-09-2026 23:11',
      'informer_name': 'พัฒนพงษ์ อุ่นทรัพย์',
      'status_id': 'CF',
      'job_type': 'S001',
      'program_id': 'P000',
      'description': 'น่าจะรอบท้ายละ',
      'image_link': '/upload/it/IT2026106446.jpg',
      'solve_description': 'ดำเนินการเรียบร้อยครับ',
      'officer_name': 'ทักษิณ โพงจ่าม',
    });

    test('อ่านช่องที่เว็บโชว์ในป๊อปอัปได้ครบ', () {
      final job = detail;

      expect(job.id, 'IT2026106446');
      expect(job.informer, 'พัฒนพงษ์ อุ่นทรัพย์');
      expect(job.description, 'น่าจะรอบท้ายละ');
      expect(job.solveNote, 'ดำเนินการเรียบร้อยครับ');
      expect(job.officer, 'ทักษิณ โพงจ่าม');
      expect(job.image, '/upload/it/IT2026106446.jpg');
    });

    test('วันที่แบบ 15-09-2026 23:11 ที่เว็บโชว์ อ่านออก', () {
      expect(detail.createdAt, DateTime(2026, 9, 15, 23, 11));
    });

    test('แปลรหัสสถานะกับประเภทปัญหาจากตารางอ้างอิง', () {
      final job = detail;

      expect(job.statusTextFrom(_statuses), 'ตรวจสอบเรียบร้อยแล้ว');
      expect(job.stage, ItCaseStage.done);
      expect(job.typeTextFrom(_types), 'คอมพิวเตอร์');
    });

    test('เคสที่ไม่ได้ผูกโปรแกรม คืนค่าว่างให้หน้าจอไปโชว์ว่าไม่ระบุ', () {
      expect(detail.programTextFrom(_types), isEmpty);
    });

    test('ช่องที่ไม่รู้จักไม่หาย ไปโผล่ท้ายหน้า', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'branch': 'สำนักงานใหญ่',
        'some_code': 'X1',
      });

      expect(job.extras.map((e) => e.label), ['สาขา', 'some_code']);
    });

    test('ช่องที่หน้าจอโชว์แล้ว ไม่โผล่ซ้ำท้ายหน้า', () {
      expect(detail.extras, isEmpty);
    });
  });

  group('ช่อง job_description', () {
    test('มีแต่ job_description ก็ขึ้นเป็นรายละเอียดได้เลย', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'job_description': 'น่าจะรอบท้ายละ',
      });

      expect(job.description, 'น่าจะรอบท้ายละ');
      expect(
        job.extras,
        isEmpty,
        reason: 'ขึ้นในข้อมูลการแจ้งแล้ว ไม่ต้องไปโผล่ท้ายหน้าอีก',
      );
    });

    test('ส่งมาทั้งสองช่องและเขียนต่างกัน เก็บไว้ทั้งคู่', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'description': 'เข้าโปรแกรมไม่ได้',
        'job_description': 'ลงโปรแกรมใหม่ให้',
      });

      expect(job.description, 'เข้าโปรแกรมไม่ได้');
      expect(job.jobDescription, 'ลงโปรแกรมใหม่ให้');
    });

    test('ส่งมาทั้งสองช่องแต่ค่าเดียวกัน ไม่ต้องโชว์ซ้ำ', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'description': 'เข้าโปรแกรมไม่ได้',
        'job_description': 'เข้าโปรแกรมไม่ได้',
      });

      expect(job.jobDescription, job.description);
    });
  });

  group('รูปของเคส', () {
    test('img_close เป็นรูปปิดงาน ไม่ใช่ภาพประกอบ', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'img_open': '/upload/it/open.jpg',
        'img_close': '/upload/it/close.jpg',
      });

      expect(job.image, '/upload/it/open.jpg');
      expect(job.solveImage, '/upload/it/close.jpg');
    });

    test('รูปที่โชว์แล้วไม่ไปโผล่ท้ายหน้าเป็นข้อความยาว ๆ', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'img_close': '/upload/it/close.jpg',
      });

      expect(job.extras, isEmpty);
    });
  });

  group('ช่องที่ยังไม่รู้จัก', () {
    test('ค่าที่เป็นวันที่ถูกจัดให้อ่านง่าย ไม่ใช่โชว์ดิบ', () {
      const withTime = ItCaseField(
        key: 'finish_date',
        label: 'เสร็จเมื่อ',
        value: '2026-09-15T13:05:00',
      );
      const dateOnly = ItCaseField(
        key: 'doc_date',
        label: 'วันที่',
        value: '2026-09-15',
      );
      const text = ItCaseField(
        key: 'branch',
        label: 'สาขา',
        value: 'ลาดกระบัง',
      );

      expect(itCaseFieldText(withTime), '15 ก.ย. 2026 13:05');
      expect(
        itCaseFieldText(dateOnly),
        '15 ก.ย. 2026',
        reason: 'ไม่มีเวลามาก็ไม่ต้องโชว์ 00:00 ให้งง',
      );
      expect(itCaseFieldText(text), 'ลาดกระบัง');
    });

    test('ข้อความสถานะฝั่ง IT ไม่เอามาโชว์ให้ผู้แจ้ง', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'job_s_details_i': 'แก้ไขเสร็จสิ้น กรุณาตรวจสอบความเรียบร้อย',
        'job_s_details_o': 'แก้ไขเสร็จสิ้น อยู่ระหว่างผู้แจ้งยืนยันปิดงาน',
      });

      expect(job.statusLabel, 'แก้ไขเสร็จสิ้น กรุณาตรวจสอบความเรียบร้อย');
      expect(job.extras, isEmpty);
    });
  });

  group('ปิดงาน', () {
    test('desc_close_job คือรายละเอียดการแก้ไขที่ทีม IT ส่งกลับมา', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'desc_close_job': 'ดำเนินการเรียบร้อยครับ',
      });

      expect(job.solveNote, 'ดำเนินการเรียบร้อยครับ');
      expect(
        job.extras,
        isEmpty,
        reason: 'ขึ้นในการดำเนินงานแล้ว ไม่ต้องไปโผล่ท้ายหน้าอีก',
      );
    });

    test('FN คือรอผู้แจ้งตรวจ ปุ่มปิดงานขึ้นตอนนี้', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'job_status': 'FN',
      });

      expect(job.statusId, kItCaseWaitConfirmStatusId);
      expect(job.stage, ItCaseStage.review);
    });

    test('CF คือปิดงานแล้ว ไม่มีอะไรให้ยืนยันอีก', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'job_status': 'CF',
      });

      expect(job.statusId, kItCaseClosedStatusId);
      expect(job.stage, ItCaseStage.done);
      expect(job.progress, 100);
    });

    test('ไม่มีเลขเคสก็ปิดงานไม่ได้ ไม่ต้องยิงเน็ตให้เสียเที่ยว', () {
      expect(
        () => closeCaseJob('  '),
        throwsA(
          isA<MobileApiException>().having(
            (e) => e.message,
            'message',
            contains('เลขเคส'),
          ),
        ),
      );
    });

    test('ยังไม่ได้ล็อกอินระบบนี้ ต้องบอกให้เข้าสู่ระบบใหม่', () {
      expect(
        () => closeCaseJob('IT2026106446'),
        throwsA(
          isA<MobileApiException>().having(
            (e) => e.needLogin,
            'needLogin',
            isTrue,
          ),
        ),
      );
    });
  });

  group('คะแนนที่ผู้แจ้งให้', () {
    test('อ่าน ratingjob 1-5 ได้', () {
      final job = ItCaseJobDetail.fromJson(const {
        'job_id': 'IT2026106446',
        'ratingjob': 4,
      });

      expect(job.rating, 4);
      expect(
        job.extras,
        isEmpty,
        reason: 'ขึ้นเป็นดาวในข้อมูลการแจ้งแล้ว ไม่ต้องไปโผล่ท้ายหน้าอีก',
      );
    });

    test('ส่งมาเป็นข้อความหรือทศนิยมก็อ่านออก', () {
      expect(itCaseRatingOf('5'), 5);
      expect(itCaseRatingOf('4.0'), 4);
      expect(itCaseRatingOf(' 3 '), 3);
    });

    test('ยังไม่ได้ให้คะแนนคืน 0 หน้าจอจะซ่อนแถวไปเลย', () {
      expect(itCaseRatingOf(''), 0);
      expect(itCaseRatingOf('-'), 0);
      expect(
        itCaseRatingOf('0'),
        0,
        reason: '0 คือยังไม่ให้ ไม่ใช่ให้ศูนย์ดาว',
      );
    });

    test('ค่านอกช่วง 1-5 ไม่เอา ดาวมีแค่ห้าดวง', () {
      expect(itCaseRatingOf('6'), 0);
      expect(itCaseRatingOf('-2'), 0);
      expect(itCaseRatingOf('99'), 0);
    });
  });
}
