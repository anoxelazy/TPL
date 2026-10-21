import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/transfer_models.dart';

/// ใบจริงใบเดียวที่มีในระบบตอนนี้ ดึงจาก
/// `GET /api/AssetTransfer/transfer/TRF-2026-0003` เมื่อ 28 ก.ย. 2026
///
/// เป็นใบที่เดินครบทุกขั้นแล้ว (สร้าง 14:09 → อนุมัติ 14:19 → ส่ง 14:22 →
/// รับ 14:25) จึงมีทุกช่องที่ช่วงกลางทางจะเป็น null
const _docJson = '''
{
  "transfer_no": "TRF-2026-0003",
  "transfer_date": "2026-09-23T00:00:00",
  "header_status": "RECEIVED",
  "status_desc": "รับครบแล้ว",
  "request_by": "63205",
  "request_by_name": "น.ส.พัชรินทร์ ผิวหลง",
  "request_dept": "F0000",
  "from_dept_name": "ฝ่ายเทคโนโลยีสารสนเทศ",
  "from_site_id": "BKK10",
  "from_site_name": "สำนักงานลาดกระบัง(สำนักงานใหญ่)",
  "to_dept_code": "N0007",
  "to_dept_name": "DC ลาดกระบัง",
  "to_site_id": "LKB01",
  "to_site_name": "HUB ลาดกระบัง",
  "to_custodian": null,
  "to_custodian_name": null,
  "expected_arrival_date": "2026-10-05T00:00:00",
  "reason": "ทดสอบระบบโอนย้ายทรัพย์สิน",
  "cr_no": null,
  "approved_by": "69045",
  "approved_by_name": "นายวงศกร หาญสกุลล้ำเลิศ",
  "approved_date": "2026-09-23T14:19:17.157",
  "reject_reason": null,
  "dispatch_by": "63205",
  "dispatch_by_name": "น.ส.พัชรินทร์ ผิวหลง",
  "dispatch_date": "2026-09-23T14:22:06.966",
  "courier_name": "ขนส่งภายใน",
  "tracking_no": "TRK001",
  "receipt_date": "2026-09-23T14:25:16.147",
  "discrepancy_note": null,
  "cancel_reason": null,
  "create_by": "63205",
  "create_date": "2026-09-23T14:09:39.537",
  "line_count": 1,
  "pending_count": 0,
  "behalf_count": 1,
  "days_overdue": null,
  "severity": null,
  "lines": [
    {
      "asset_id": "ASE105234",
      "asset_name_snap": "ทดสอบเปลี่ยนข้อมูล",
      "asset_type_snap": "IT-TEST-02",
      "serial_no_snap": "UI5989212HUAW",
      "condition_out": "GOOD",
      "condition_in": "GOOD",
      "receipt_outcome": "RECEIVED_OK",
      "outcome_desc": "ได้รับปกติ",
      "receipt_note": null,
      "receipt_by": "68196",
      "receipt_by_name": "นายภาคภูมิ ปริเตสัง",
      "receipt_date": "2026-09-23T14:25:16.147",
      "photo_path": null,
      "received_on_behalf": true,
      "asset_current_status": "IN_USE"
    }
  ],
  "can_edit": false,
  "can_submit": false,
  "can_approve": false,
  "can_dispatch": false,
  "can_receive": false,
  "can_cancel": false
}
''';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

AssetTransferDoc _doc() => AssetTransferDoc.fromJson(_decode(_docJson));

void main() {
  group('AssetTransferDoc', () {
    test('อ่านใบจริงได้ครบทั้งหัวและร่องรอยทุกขั้น', () {
      final doc = _doc();

      expect(doc.transferNo, 'TRF-2026-0003');
      expect(doc.header.status, 'RECEIVED');
      expect(doc.header.statusText, 'รับครบแล้ว');
      expect(doc.approvedByName, 'นายวงศกร หาญสกุลล้ำเลิศ');
      expect(doc.courierName, 'ขนส่งภายใน');
      expect(doc.trackingNo, 'TRK001');
      expect(doc.behalfCount, 1);
      expect(doc.createAt, DateTime(2026, 9, 23, 14, 9, 39));
    });

    test('ปุ่มมาจาก can_* ของเซิร์ฟเวอร์ ใบที่ปิดแล้วต้องไม่มีปุ่มเลย', () {
      final doc = _doc();

      expect(doc.canSubmit, isFalse);
      expect(doc.canApprove, isFalse);
      expect(doc.canReceive, isFalse);
      expect(doc.canCancel, isFalse);
      expect(doc.hasActions, isFalse);
    });

    test('can_* ที่ไม่ส่งมาต้องถือว่ากดไม่ได้ ไม่ใช่กดได้', () {
      // เดาผิดทางนี้แค่ปุ่มหาย เดาผิดอีกทางคือโชว์ปุ่มที่กดแล้วเด้ง error
      final doc = AssetTransferDoc.fromJson(
        _decode('{"transfer_no": "TRF-2026-0009"}'),
      );

      expect(doc.hasActions, isFalse);
    });

    test('รายการของในใบอ่านได้ พร้อมผลการรับ', () {
      final line = _doc().lines.single;

      expect(line.assetId, 'ASE105234');
      expect(line.assetName, 'ทดสอบเปลี่ยนข้อมูล');
      expect(line.serialNo, 'UI5989212HUAW');
      expect(line.isReceived, isTrue);
      expect(line.hasProblem, isFalse);
      expect(line.outcomeText, 'ได้รับปกติ');
      expect(line.receivedOnBehalf, isTrue);
    });

    test('รับครบแล้วไม่เหลือชิ้นค้าง', () {
      final doc = _doc();

      expect(doc.pendingLines, isEmpty);
      expect(doc.problemLines, isEmpty);
      expect(doc.header.isDone, isTrue);
    });

    test('ชิ้นที่ยังไม่ได้รับนับเป็นค้าง ไม่ใช่มีปัญหา', () {
      const line = AssetTransferLine(assetId: 'A1');

      expect(line.isReceived, isFalse);
      expect(line.hasProblem, isFalse);
    });

    test('ผลการรับที่ไม่ใช่ RECEIVED_OK ถือว่ามีปัญหาทั้งหมด', () {
      for (final outcome in const [
        kReceiveDamaged,
        kReceiveNotArrived,
        kReceiveRejected,
      ]) {
        expect(
          AssetTransferLine(assetId: 'A1', outcome: outcome).hasProblem,
          isTrue,
          reason: outcome,
        );
      }
    });

    test('เซิร์ฟเวอร์ไม่แปลผลการรับมาให้ ต้องแปลเองได้', () {
      const line = AssetTransferLine(assetId: 'A1', outcome: kReceiveDamaged);

      expect(line.outcomeText, 'ได้รับแต่ชำรุด');
    });
  });

  group('AssetTransferItem', () {
    test('ต้นทาง → ปลายทาง ใช้ชื่อสาขาเมื่อมี', () {
      expect(
        _doc().header.routeLabel,
        'สำนักงานลาดกระบัง(สำนักงานใหญ่) → HUB ลาดกระบัง',
      );
    });

    test('ไม่มีชื่อสาขาก็ยังบอกทิศทางได้ด้วยรหัส', () {
      const item = AssetTransferItem(
        transferNo: 'TRF-1',
        fromSiteId: 'BKK10',
        toSiteId: 'LKB01',
      );

      expect(item.routeLabel, 'BKK10 → LKB01');
    });

    test('days_overdue เป็น null ต่างจาก 0 — null คือยังไม่เกินกำหนด', () {
      expect(_doc().header.daysOverdue, isNull);
      expect(_doc().header.isOverdue, isFalse);

      const overdue = AssetTransferItem(transferNo: 'TRF-1', daysOverdue: 3);
      expect(overdue.isOverdue, isTrue);
    });
  });

  group('AssetTransferSearchResult', () {
    test('อ่านก้อนแบ่งหน้าที่ /transfers ตอบมา', () {
      final result = AssetTransferSearchResult.fromJson(
        _decode('''
        {"items":[{"transfer_no":"TRF-2026-0003"}],
         "total":1,"page":1,"page_size":20,"total_pages":1}
        '''),
      );

      expect(result.items, hasLength(1));
      expect(result.total, 1);
      expect(result.hasMore, isFalse);
    });

    test('ยังมีหน้าถัดไปเมื่อหน้าปัจจุบันไม่ใช่หน้าสุดท้าย', () {
      final result = AssetTransferSearchResult.fromJson(
        _decode(
          '{"items":[],"total":60,"page":1,"page_size":20,'
          '"total_pages":3}',
        ),
      );

      expect(result.hasMore, isTrue);
    });

    test('แถวที่ไม่มีเลขที่ใบถูกตัดทิ้ง เปิดดูต่อไม่ได้อยู่ดี', () {
      final result = AssetTransferSearchResult.fromJson(
        _decode('{"items":[{"reason":"ไม่มีเลขใบ"}],"total":1}'),
      );

      expect(result.items, isEmpty);
    });
  });

  group('buildTransferCreatePayload', () {
    test('ส่งครบทุกช่องที่ schema บังคับ', () {
      final payload = buildTransferCreatePayload(
        toDeptCode: ' n0007 ',
        toSiteId: ' LKB01 ',
        expectedArrival: DateTime(2026, 10, 5, 16, 30),
        reason: ' ย้ายตามพนักงาน ',
        assetIds: const ['ASE105234', 'OHM'],
      );

      expect(payload['to_dept_code'], 'n0007');
      expect(payload['to_site_id'], 'LKB01');
      expect(payload['expected_arrival_date'], '2026-10-05T00:00:00');
      expect(payload['reason'], 'ย้ายตามพนักงาน');
      expect(payload['asset_ids'], ['ASE105234', 'OHM']);
    });

    test('ช่องไม่บังคับที่ปล่อยว่างไม่ถูกส่งไป', () {
      final payload = buildTransferCreatePayload(
        toDeptCode: 'N0007',
        toSiteId: 'LKB01',
        expectedArrival: DateTime(2026, 10, 5),
        reason: 'ย้าย',
        assetIds: const ['A1'],
      );

      expect(payload.containsKey('to_custodian'), isFalse);
      expect(payload.containsKey('cr_no'), isFalse);
    });

    test(
      'รหัสทรัพย์สินที่ว่างถูกคัดทิ้ง ไม่ส่งช่องว่างไปให้เซิร์ฟเวอร์ตีกลับ',
      () {
        final payload = buildTransferCreatePayload(
          toDeptCode: 'N0007',
          toSiteId: 'LKB01',
          expectedArrival: DateTime(2026, 10, 5),
          reason: 'ย้าย',
          assetIds: const ['A1', '  ', ''],
        );

        expect(payload['asset_ids'], ['A1']);
      },
    );
  });

  group('buildTransferApprovePayload', () {
    test('อนุมัติไม่ต้องมีเหตุผล', () {
      expect(buildTransferApprovePayload(approve: true), {'approve': true});
    });

    test('ตีกลับส่งเหตุผลไปด้วย', () {
      expect(
        buildTransferApprovePayload(approve: false, reason: ' ยังไม่พร้อม '),
        {'approve': false, 'reason': 'ยังไม่พร้อม'},
      );
    });
  });

  group('buildTransferReceivePayload', () {
    test('ผลการรับถูกแปลงเป็นตัวพิมพ์ใหญ่ให้ตรง regex ของ schema', () {
      final payload = buildTransferReceivePayload(
        assetId: ' ase105234 ',
        outcome: 'received_ok',
      );

      expect(payload['asset_id'], 'ase105234');
      expect(payload['outcome'], 'RECEIVED_OK');
    });

    test('หมายเหตุว่างไม่ถูกส่งไป', () {
      final payload = buildTransferReceivePayload(
        assetId: 'A1',
        outcome: kReceiveOk,
        note: '   ',
      );

      expect(payload.containsKey('note'), isFalse);
    });
  });

  group('buildTransferDispatchPayload', () {
    test('ไม่กรอกอะไรเลยได้ก้อนเปล่า ซึ่ง schema ยอมรับ', () {
      expect(buildTransferDispatchPayload(), isEmpty);
    });
  });

  group('AssetTransferQuery', () {
    test('ส่งแค่ตัวกรองที่เปิดใช้ ไม่ส่งค่าว่างกับ false', () {
      expect(const AssetTransferQuery().toParams(), {
        'page': 1,
        'page_size': kTransferPageSize,
      });
    });

    test('ตัวกรองที่ตั้งไว้แปลงเป็นชื่อพารามิเตอร์ของ API', () {
      final params = const AssetTransferQuery(
        keyword: 'TRF',
        status: 'IN_TRANSIT',
        openOnly: true,
        overdueOnly: true,
        page: 2,
      ).toParams();

      expect(params['keyword'], 'TRF');
      expect(params['header_status'], 'IN_TRANSIT');
      expect(params['open_only'], true);
      expect(params['overdue_only'], true);
      expect(params['page'], 2);
    });

    test('เปลี่ยนตัวกรองแล้วต้องกลับไปหน้าแรก', () {
      // ค้างอยู่หน้า 3 ของผลเก่าแล้วเปลี่ยนตัวกรอง จะเห็นหน้าว่างโดยไม่รู้สาเหตุ
      const query = AssetTransferQuery(page: 3);

      expect(query.copyWith(openOnly: true).page, 1);
    });

    test('ขอหน้าถัดไปโดยระบุ page ตรง ๆ ยังทำได้', () {
      expect(const AssetTransferQuery(page: 3).copyWith(page: 4).page, 4);
    });

    test('hasFilter ไม่นับหน้าที่กำลังดู', () {
      expect(const AssetTransferQuery(page: 5).hasFilter, isFalse);
      expect(const AssetTransferQuery(overdueOnly: true).hasFilter, isTrue);
    });
  });

  group('transferCancelReasonError', () {
    // Stored Procedure ตีกลับเหตุผลที่สั้นกว่า 10 ตัว ต้องดักก่อนยิง
    test('สั้นกว่า 10 ตัวไม่ผ่าน', () {
      expect(transferCancelReasonError('ขอผิดใบ'), isNotNull);
    });

    test('ครบ 10 ตัวผ่าน นับหลังตัดช่องว่างหัวท้าย', () {
      expect(transferCancelReasonError('1234567890'), isNull);
      expect(transferCancelReasonError('  123456789  '), isNotNull);
    });

    test('ว่างก็ยังฟ้องว่าต้องกรอก ไม่ใช่ฟ้องเรื่องความยาว', () {
      expect(transferCancelReasonError(''), transferReasonError(''));
    });
  });

  group('transferArrivalError', () {
    test('ไม่เลือกวันที่ต้องเตือน', () {
      expect(transferArrivalError(null), isNotNull);
    });

    test('วันที่ผ่านมาแล้วใช้ไม่ได้ ใบจะขึ้นค้างทางทันทีที่ส่ง', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      expect(transferArrivalError(yesterday), isNotNull);
    });

    test('วันนี้กับอนาคตใช้ได้', () {
      final now = DateTime.now();

      expect(
        transferArrivalError(DateTime(now.year, now.month, now.day)),
        isNull,
      );
      expect(transferArrivalError(now.add(const Duration(days: 7))), isNull);
    });
  });

  group('AssetTransitAging', () {
    test('อ่านแถวของค้างทาง', () {
      final row = AssetTransitAging.fromJson(
        _decode('''
        {"transfer_no":"TRF-2026-0004","to_site_id":"LKB01",
         "to_site_name":"HUB ลาดกระบัง","asset_id":"A1",
         "asset_name_snap":"โน้ตบุ๊ก","days_overdue":5,
         "severity":"HIGH","action_required":"ติดตามกับปลายทาง"}
        '''),
      );

      expect(row.transferNo, 'TRF-2026-0004');
      expect(row.daysOverdue, 5);
      expect(row.label, 'โน้ตบุ๊ก');
      expect(row.actionRequired, 'ติดตามกับปลายทาง');
    });
  });

  test(
    "บังคับหมายเหตุเฉพาะของชำรุดกับไม่มาถึง ตามกฎข้อ 8 ของ Workflow v2.0",
    () {
      expect(transferOutcomeNeedsNote(kReceiveDamaged), isTrue);
      expect(transferOutcomeNeedsNote(kReceiveNotArrived), isTrue);
      expect(transferOutcomeNeedsNote(kReceiveRejected), isFalse);
      expect(transferOutcomeNeedsNote(kReceiveOk), isFalse);
    },
  );
}
