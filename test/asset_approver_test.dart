import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';

/// ของจริงที่ยิงมาได้เมื่อ 24 ก.ย. 2026
///
/// `D0002` เป็นเคสที่ทำให้เจอบั๊กของ `/deptlist`: ผู้อนุมัติคนเดียวของแผนกนี้
/// ลาออกไปแล้ว (`is_effective: false`) แต่ `deptlist` ยังนับว่าแผนกพร้อม
const _blockedApproverJson = '''
{
  "dept_code": "D0002",
  "dept_name": "สรรหาและฝึกอบรม ฝ่ายทรัพยากรบุคคล",
  "approver_id": "63057",
  "approver_name": "น.ส.พัณณ์วรา ชัยรัฐนิธิสกุล",
  "approver_position": "ผู้จัดการฝ่ายทรัพยากรบุคคล",
  "approver_dept": "D0000",
  "approve_order": 1,
  "valid_from": null,
  "valid_to": null,
  "is_active": true,
  "remark": null,
  "is_effective": false,
  "blocked_reason": "ไม่ใช่พนักงานปัจจุบันแล้ว",
  "create_by": "SYSTEM",
  "create_date": "2026-09-22T11:15:49.092"
}
''';

const _summaryJson = '''
{
  "dept_code": "I0005",
  "dept_name": "E-Commerce ฝ่ายคลังสินค้า",
  "staff_count": 13,
  "approver_count": 1,
  "has_primary": true,
  "has_backup": false,
  "is_ready": true,
  "approvers": [
    {
      "dept_code": "I0005",
      "approver_id": "70002",
      "approver_name": "คนสำรอง",
      "approve_order": 2,
      "is_active": true,
      "is_effective": true
    },
    {
      "dept_code": "I0005",
      "approver_id": "70001",
      "approver_name": "คนตัวจริง",
      "approve_order": 1,
      "is_active": true,
      "is_effective": true
    }
  ]
}
''';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

AssetDeptApprovers _dept({
  required String code,
  int staff = 0,
  int approvers = 0,
  bool ready = false,
  bool backup = false,
}) => AssetDeptApprovers(
  deptCode: code,
  staffCount: staff,
  approverCount: approvers,
  hasPrimary: ready,
  hasBackup: backup,
  isReady: ready,
);

void main() {
  group('AssetApprover', () {
    test('อ่านแถวจาก /approvers ได้ครบ รวมช่องที่เส้นอื่นไม่ส่งมา', () {
      final approver = AssetApprover.fromJson(_decode(_blockedApproverJson));

      expect(approver.id, '63057');
      expect(approver.deptCode, 'D0002');
      expect(approver.deptName, 'สรรหาและฝึกอบรม ฝ่ายทรัพยากรบุคคล');
      expect(approver.order, 1);
      expect(approver.isPrimary, isTrue);
      expect(approver.isActive, isTrue);
      expect(approver.isEffective, isFalse);
    });

    test('แผนกที่ผู้อนุมัติสังกัด ต่างจากแผนกที่เขาอนุมัติให้ได้', () {
      final approver = AssetApprover.fromJson(_decode(_blockedApproverJson));

      // หัวหน้าฝ่าย (D0000) ถูกตั้งเป็นผู้อนุมัติของแผนกลูก (D0002)
      expect(approver.deptCode, 'D0002');
      expect(approver.approverDept, 'D0000');
    });

    test('เปิดใช้งานอยู่แต่ใช้ไม่ได้ ต้องบอกเหตุผลที่เซิร์ฟเวอร์ส่งมา', () {
      final approver = AssetApprover.fromJson(_decode(_blockedApproverJson));

      expect(approver.problemLabel, 'ไม่ใช่พนักงานปัจจุบันแล้ว');
    });

    test('ปิดใช้งานเองสำคัญกว่าเหตุผลอื่น', () {
      const approver = AssetApprover(
        id: '63057',
        isActive: false,
        isEffective: false,
        blockedReason: 'ไม่ใช่พนักงานปัจจุบันแล้ว',
      );

      expect(approver.problemLabel, 'ปิดใช้งานไว้');
    });

    test('ใช้ไม่ได้แต่ไม่บอกเหตุผล ต้องมีข้อความกลาง ไม่ใช่ช่องว่าง', () {
      const approver = AssetApprover(id: '63057', isEffective: false);

      expect(approver.problemLabel, 'ใช้อนุมัติไม่ได้ตอนนี้');
    });

    test('แถวจาก /me ที่ไม่มีช่อง is_active / is_effective ต้องถือว่าใช้ได้', () {
      // ตั้งค่าตั้งต้นเป็น false จะทำให้ผู้อนุมัติของตัวเองใน /me ขึ้นแดงทั้งชุด
      final approver = AssetApprover.fromJson(
        _decode('{"approver_id": "63205", "approve_order": 1}'),
      );

      expect(approver.isActive, isTrue);
      expect(approver.isEffective, isTrue);
      expect(approver.problemLabel, '');
    });
  });

  group('AssetDeptApprovers', () {
    test('อ่าน /summary พร้อมผู้อนุมัติที่ซ้อนอยู่ข้างใน', () {
      final dept = AssetDeptApprovers.fromJson(_decode(_summaryJson));

      expect(dept.deptCode, 'I0005');
      expect(dept.staffCount, 13);
      expect(dept.hasPrimary, isTrue);
      expect(dept.hasBackup, isFalse);
      expect(dept.approvers, hasLength(2));
    });

    test('ผู้อนุมัติเรียงตามลำดับเสมอ ไม่เชื่อลำดับที่ API ส่งมา', () {
      final dept = AssetDeptApprovers.fromJson(_decode(_summaryJson));

      // ใน JSON คนลำดับ 2 มาก่อน
      expect(dept.approvers.first.order, 1);
      expect(dept.approvers.first.name, 'คนตัวจริง');
      expect(dept.approvers.last.order, 2);
    });

    test('ยังไม่มีผู้อนุมัติเลย กับมีแต่ใช้ไม่ได้ ต้องบอกคนละอย่าง', () {
      expect(
        _dept(code: 'X0004').gapLabel,
        'ยังไม่มีผู้อนุมัติ',
      );
      expect(
        _dept(code: 'D0002', approvers: 1).gapLabel,
        'มีผู้อนุมัติแต่ใช้ไม่ได้',
      );
    });

    test('พร้อมแล้วแต่ไม่มีตัวสำรอง ยังต้องเตือน', () {
      expect(
        _dept(code: 'I0005', approvers: 1, ready: true).gapLabel,
        'ยังไม่มีตัวสำรอง',
      );
    });

    test('ครบทั้งตัวจริงและตัวสำรอง ไม่ต้องเตือนอะไร', () {
      expect(
        _dept(code: 'A0000', approvers: 2, ready: true, backup: true).gapLabel,
        '',
      );
    });

    test('ค้นได้ทั้งรหัสแผนก ชื่อแผนก และชื่อผู้อนุมัติ', () {
      final index = AssetDeptApprovers.fromJson(
        _decode(_summaryJson),
      ).searchIndex;

      expect(index.contains('i0005'), isTrue);
      expect(index.contains('e-commerce'), isTrue);
      expect(index.contains('คนตัวจริง'), isTrue);
      expect(index.contains('70002'), isTrue);
    });
  });

  group('sortApproverBoard', () {
    test('แผนกที่ยังไม่พร้อมขึ้นก่อน แล้วค่อยแผนกที่ขาดตัวสำรอง', () {
      final board = [
        _dept(code: 'CRB', ready: true, backup: true),
        _dept(code: 'GAP', ready: true),
        _dept(code: 'NON'),
      ];

      sortApproverBoard(board);

      expect(board.map((e) => e.deptCode), ['NON', 'GAP', 'CRB']);
    });

    test('กลุ่มเดียวกัน แผนกที่คนเยอะขึ้นก่อน เพราะกระทบคนเยอะกว่า', () {
      final board = [
        _dept(code: 'SMALL', staff: 5),
        _dept(code: 'BIG', staff: 379),
      ];

      sortApproverBoard(board);

      expect(board.first.deptCode, 'BIG');
    });

    test('คนเท่ากันเรียงตามรหัสแผนก ผลจะได้ไม่สลับไปมาทุกครั้งที่โหลด', () {
      final board = [_dept(code: 'B0001'), _dept(code: 'A0001')];

      sortApproverBoard(board);

      expect(board.map((e) => e.deptCode), ['A0001', 'B0001']);
    });
  });

  group('buildApproverInsertPayload', () {
    test('ส่งเฉพาะช่องที่จำเป็นเมื่อไม่ได้กรอกอย่างอื่น', () {
      final payload = buildApproverInsertPayload(
        deptCode: ' F0001 ',
        approverId: ' 63205 ',
      );

      expect(payload, {
        'dept_code': 'F0001',
        'approver_id': '63205',
        'approve_order': 1,
      });
    });

    test('ลำดับที่เกิน 1–5 ถูกดึงกลับเข้าช่วงที่ schema ยอมรับ', () {
      expect(
        buildApproverInsertPayload(
          deptCode: 'F0001',
          approverId: '63205',
          order: 99,
        )['approve_order'],
        kApproverOrderMax,
      );
      expect(
        buildApproverInsertPayload(
          deptCode: 'F0001',
          approverId: '63205',
          order: 0,
        )['approve_order'],
        kApproverOrderMin,
      );
    });

    test('หมายเหตุว่างไม่ถูกส่งไป จะได้ไม่เขียนสตริงว่างลงฐานข้อมูล', () {
      final payload = buildApproverInsertPayload(
        deptCode: 'F0001',
        approverId: '63205',
        remark: '   ',
      );

      expect(payload.containsKey('remark'), isFalse);
    });

    test('ช่วงวันที่ส่งเป็นรูปแบบที่ .NET รับ ไม่ติดเวลาไปด้วย', () {
      final payload = buildApproverInsertPayload(
        deptCode: 'F0001',
        approverId: '63205',
        validFrom: DateTime(2026, 10, 1, 14, 30),
      );

      expect(payload['valid_from'], '2026-10-01T00:00:00');
    });
  });

  group('buildApproverUpdatePayload', () {
    test('ไม่ส่งช่องที่ไม่ได้ตั้งใจแก้', () {
      expect(buildApproverUpdatePayload(order: 2), {'approve_order': 2});
      expect(buildApproverUpdatePayload(isActive: false), {'is_active': false});
    });

    test('ไม่แก้อะไรเลยได้ก้อนเปล่า ไม่ใช่ก้อนที่มี null เต็มไปหมด', () {
      expect(buildApproverUpdatePayload(), isEmpty);
    });

    test('ล้างหมายเหตุทำได้ ต่างจากตอนเพิ่มที่ปล่อยว่างแปลว่าไม่ส่ง', () {
      // ส่ง '' มาแปลว่าตั้งใจล้าง ไม่ใช่ "ไม่ได้แก้"
      expect(buildApproverUpdatePayload(remark: ''), {'remark': ''});
    });
  });

  group('approverRemarkError', () {
    test('ปล่อยว่างได้ ไม่บังคับ', () {
      expect(approverRemarkError(''), isNull);
    });

    test('ยาวเกิน 300 ตัวต้องเตือนก่อนยิง จะได้ไม่เสียรอบไปโดน 400', () {
      expect(approverRemarkError('ก' * 301), contains('300'));
      expect(approverRemarkError('ก' * 300), isNull);
    });
  });
}
