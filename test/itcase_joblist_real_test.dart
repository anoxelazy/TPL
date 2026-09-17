import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/itcase/itcase_api.dart';

/// response จริงจาก `/api/ITRepair/joblist` ที่ดึงมาจากเบราว์เซอร์
///
/// ไม่ใช่ตัวอย่างที่เขียนขึ้นเอง เทสต์ในไฟล์นี้จึงเป็นตัวยืนยันว่าชื่อช่องที่
/// ตัวแปลงไล่หาอยู่ ตรงกับที่เซิร์ฟเวอร์ส่งมาจริง
List<ItCaseJob> get _jobs => [
  for (final row in decodeItCaseList(
    File('test/fixtures/itcase_joblist.json').readAsStringSync(),
  ))
    ItCaseJob.fromJson(row),
];

List<ItCaseStatus> get _statuses => [
  for (final row in decodeItCaseList(
    File('test/fixtures/itcase_statuslist.json').readAsStringSync(),
  ))
    ItCaseStatus.fromJson(row),
];

void main() {
  test('อ่านครบทุกแถวจาก response จริง', () {
    expect(_jobs.length, 4);
    expect(_jobs.every((e) => e.isUsable), isTrue);
  });

  group('ห้าอย่างที่ต้องขึ้นบนการ์ด', () {
    test('1 เลขเคส จาก job_id', () {
      expect(_jobs.first.id, 'IT2026106475');
    });

    test('2 รายละเอียด จาก job_description', () {
      expect(_jobs.map((e) => e.description), [
        'test',
        'น่าจะรอบท้ายละ',
        'เทสๆๆอีก',
        'เทสๆ',
      ]);
    });

    test('3 เวลา จาก create_date แบบ 16-09-2026 17:34', () {
      expect(_jobs.first.createdAt, DateTime(2026, 9, 16, 17, 34));
      expect(
        _jobs.every((e) => e.createdAt != null),
        isTrue,
        reason: 'อ่านวันที่ไม่ออกสักแถวเดียวก็ถือว่ารูปแบบเปลี่ยนไปแล้ว',
      );
    });

    test('4 ผู้รับงาน จาก recive_by ที่ API สะกดตก e', () {
      expect(
        _jobs.first.officer,
        '69053',
        reason: 'เทียบชื่อช่องแบบสะกดถูกอย่างเดียวจะไม่เจอ ช่องนี้จะหายไปเงียบ',
      );
    });

    test('5 สถานะ จาก job_s_details_i ฝั่งผู้แจ้ง', () {
      final job = _jobs.first;

      expect(job.statusId, 'CF');
      expect(job.statusTextFrom(_statuses), 'ตรวจสอบเรียบร้อยแล้ว');
      expect(job.progress, 100);
    });
  });

  test('ข้อความฝั่ง IT ไม่หลุดมาโชว์ให้ผู้แจ้ง', () {
    for (final job in _jobs) {
      expect(
        job.statusTextFrom(_statuses),
        isNot(contains('ยืนยันปิดงาน')),
        reason: 'job_s_details_o เป็นของฝั่งเจ้าหน้าที่ ไม่ใช่ของผู้แจ้ง',
      );
    }
  });

  test('เคสที่ปิดแล้วไม่ขึ้นบนหน้าหลัก', () {
    expect(
      _jobs.where((e) => !e.isClosed),
      isEmpty,
      reason: 'ทั้งสี่แถวเป็น CF หน้าหลักจึงไม่ควรมีการ์ดค้างเลย',
    );
  });
}
