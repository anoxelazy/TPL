import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/itcase/itcase_api.dart';

ItCaseJob _job(String id, String status) =>
    ItCaseJob.fromJson({'job_id': id, 'job_status': status});

/// การ์ดบนหน้าหลักโชว์เฉพาะเคสที่ยังไม่ปิด และเรียงใบที่รอมือผู้แจ้งขึ้นก่อน
/// เทสต์นี้คุมกติกาการคัดกับการเรียง ส่วนหน้าตาการ์ดใช้ตัวเดียวกับหน้ารายการ
void main() {
  group('เคสที่ยังไม่ปิด', () {
    test('CF คือปิดแล้ว ไม่ต้องโชว์บนหน้าหลัก', () {
      expect(_job('A', 'CF').isClosed, isTrue);

      for (final id in const ['OP', 'RC', 'AS1', 'AS2', 'IN', 'IN2', 'FN']) {
        expect(_job('A', id).isClosed, isFalse, reason: id);
      }
    });

    test('FN คือใบที่รอผู้แจ้งตรวจแล้วกดปิด', () {
      expect(_job('A', 'FN').needsConfirm, isTrue);
      expect(_job('A', 'IN').needsConfirm, isFalse);
      expect(_job('A', 'CF').needsConfirm, isFalse);
    });

    test('สถานะที่ติดมาแบบ CF:ตรวจสอบเรียบร้อยแล้ว ก็รู้ว่าปิดแล้ว', () {
      final job = ItCaseJob.fromJson(const {
        'job_id': 'IT2026106446',
        'job_status': 'CF:ตรวจสอบเรียบร้อยแล้ว',
      });

      expect(
        job.isClosed,
        isTrue,
        reason: 'แยกรหัสไม่ออกแล้วเคสที่ปิดไปแล้วจะค้างอยู่หน้าหลักตลอด',
      );
    });

    test('ใบที่รอตรวจถูกดันขึ้นก่อน ไม่ถูกตัดทิ้งตอนโชว์ได้แค่ไม่กี่ใบ', () {
      final open = [
        _job('A', 'IN'),
        _job('B', 'OP'),
        _job('C', 'FN'),
        _job('D', 'RC'),
      ].where((e) => !e.isClosed).toList();

      final sorted = [
        ...open.where((e) => e.needsConfirm),
        ...open.where((e) => !e.needsConfirm),
      ];

      expect(sorted.map((e) => e.id), ['C', 'A', 'B', 'D']);
    });
  });
}
