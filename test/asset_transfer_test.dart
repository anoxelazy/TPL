import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';

/// ทรัพย์สินหนึ่งชิ้นที่กรอกข้อมูลไว้ครบ ใช้เป็นตัวตั้งต้นของการโอนย้าย
Asset _asset() => Asset(
  id: 'F800-6703-0001',
  name: 'โน้ตบุ๊ก ASUS',
  typeId: 'NOTEBOOK',
  typeName: 'โน้ตบุ๊ก',
  serialNo: 'SN12345',
  brand: 'ASUS',
  model: 'X515',
  statusId: 'IN-USE',
  statusName: 'ใช้งานอยู่',
  siteId: 'HQ',
  custodian: '68051',
  remark: 'เครื่องของฝ่ายบัญชี',
  acceptDate: DateTime(2026, 3, 1),
  purchaseDate: DateTime(2026, 2, 20),
  warrantyExpireDate: DateTime(2029, 2, 20),
  purchasePrice: 25900,
);

void main() {
  group('โอนย้าย = PUT เปลี่ยนสาขา/ผู้ครอบครอง', () {
    test('ส่งของเดิมไปครบทั้งก้อน เปลี่ยนแค่ปลายทาง', () {
      final payload = buildAssetUpdatePayload(
        next: _asset().copyWith(siteId: 'BKK01', custodian: '70012'),
        changeNote: 'ย้ายตามพนักงานที่เปลี่ยนสาขา',
        refNo: 'MV-2026-001',
      );

      expect(payload['current_site_id'], 'BKK01');
      expect(payload['current_custodian'], '70012');
      expect(payload['change_note'], 'ย้ายตามพนักงานที่เปลี่ยนสาขา');
      expect(payload['ref_no'], 'MV-2026-001');

      // ช่องที่ไม่เกี่ยวกับการย้ายต้องติดไปด้วย ไม่งั้นถ้าเซิร์ฟเวอร์ตีความ
      // null ว่า "ล้างค่า" การย้ายหนึ่งครั้งจะลบยี่ห้อกับวันที่ซื้อทิ้ง
      expect(payload['asset_name'], 'โน้ตบุ๊ก ASUS');
      expect(payload['asset_type'], 'NOTEBOOK');
      expect(payload['serial_no'], 'SN12345');
      expect(payload['brand'], 'ASUS');
      expect(payload['model'], 'X515');
      expect(payload['remark'], 'เครื่องของฝ่ายบัญชี');
      expect(payload['accept_date'], '2026-03-01T00:00:00');
      expect(payload['purchase_date'], '2026-02-20T00:00:00');
      expect(payload['warranty_expire_date'], '2029-02-20T00:00:00');
      expect(payload['purchase_price'], 25900);
    });

    test('ไม่ส่งรหัสทรัพย์สินกับสถานะไปใน body', () {
      final payload = buildAssetUpdatePayload(
        next: _asset(),
        changeNote: 'แก้ชื่อ',
      );

      // asset_id อยู่ใน path ส่วน status_id ไม่มีใน requestUpdateAsset เลย
      // ส่งไปจะโดน 400 เพราะ schema ตั้ง additionalProperties: false
      expect(payload.containsKey('asset_id'), isFalse);
      expect(payload.containsKey('status_id'), isFalse);
    });

    test('ไม่มีเลขเอกสารอ้างอิงก็ไม่ต้องส่ง key ไป', () {
      final payload = buildAssetUpdatePayload(
        next: _asset(),
        changeNote: 'แก้ชื่อ',
      );

      expect(payload.containsKey('ref_no'), isFalse);
    });

    test('ช่องที่ว่างอยู่แล้วไม่ถูกส่ง', () {
      final bare = Asset(id: 'A1', name: 'ของ', typeId: 'T1');
      final payload = buildAssetUpdatePayload(next: bare, changeNote: 'x');

      expect(payload.keys, containsAll(['asset_name', 'asset_type',
          'change_note']));
      expect(payload.containsKey('brand'), isFalse);
      expect(payload.containsKey('purchase_price'), isFalse);
      expect(payload.containsKey('accept_date'), isFalse);
    });

    test('copyWith ไม่ให้เปลี่ยนรหัสและสถานะ', () {
      final moved = _asset().copyWith(siteId: 'BKK01');

      expect(moved.id, 'F800-6703-0001');
      expect(moved.statusId, 'IN-USE');
      expect(moved.siteId, 'BKK01');
      // ช่องที่ไม่ได้ส่งมาต้องคงของเดิม
      expect(moved.custodian, '68051');
      expect(moved.purchasePrice, 25900);
    });

    test('เหตุผลบังคับกรอก', () {
      expect(assetChangeNoteError(''), isNotNull);
      expect(assetChangeNoteError('   '), isNotNull);
      expect(assetChangeNoteError('ย้ายไปสาขาใหม่'), isNull);
      expect(assetChangeNoteError('ก' * (kAssetChangeNoteMax + 1)), isNotNull);
    });
  });

  group('Asset.fromJson', () {
    test('อ่านชื่อช่องแบบ snake_case ตาม schema', () {
      final asset = Asset.fromJson({
        'asset_id': 'F800-6703-0001',
        'asset_name': 'โน้ตบุ๊ก',
        'asset_type': 'NOTEBOOK',
        'serial_no': 'SN1',
        'current_site_id': 'HQ',
        'current_custodian': '68051',
        'purchase_price': 25900.0,
        'warranty_expire_date': '2029-02-20T00:00:00',
      });

      expect(asset.id, 'F800-6703-0001');
      expect(asset.name, 'โน้ตบุ๊ก');
      expect(asset.typeId, 'NOTEBOOK');
      expect(asset.serialNo, 'SN1');
      expect(asset.siteId, 'HQ');
      expect(asset.custodian, '68051');
      expect(asset.purchasePrice, 25900);
      expect(asset.warrantyExpireDate, DateTime(2029, 2, 20));
    });

    test('ใช้ชื่อประเภท/สถานะที่ join มาถ้ามี ไม่มีก็โชว์รหัส', () {
      final joined = Asset.fromJson({
        'asset_id': 'A1',
        'asset_type': 'NOTEBOOK',
        'type_desc_th': 'โน้ตบุ๊ก',
        'status_id': 'IN-USE',
        'status_desc_th': 'ใช้งานอยู่',
      });
      expect(joined.typeLabel, 'โน้ตบุ๊ก');
      expect(joined.statusLabel, 'ใช้งานอยู่');

      final plain = Asset.fromJson({
        'asset_id': 'A1',
        'asset_type': 'NOTEBOOK',
        'status_id': 'IN-USE',
      });
      expect(plain.typeLabel, 'NOTEBOOK');
      expect(plain.statusLabel, 'IN-USE');
    });

    test('ที่อยู่รวมบรรทัดเดียว ไม่มีข้อมูลก็บอกว่ายังไม่ระบุ', () {
      expect(Asset.fromJson({'asset_id': 'A1'}).placeLabel, 'ยังไม่ระบุที่อยู่');
      expect(
        Asset.fromJson({
          'asset_id': 'A1',
          'current_site_id': 'HQ',
          'current_custodian': '68051',
        }).placeLabel,
        'HQ · 68051',
      );
    });

    test('วันเวลาที่ไม่มี timezone อ่านเป็นเวลาไทยตรง ๆ ไม่เลื่อน', () {
      expect(assetDateOf('2026-09-21T14:30:00'), DateTime(2026, 9, 21, 14, 30));
      expect(assetDateOf('2026-09-21'), DateTime(2026, 9, 21));
      expect(assetDateOf(''), isNull);
      expect(assetDateOf(null), isNull);
      expect(assetDateOf('ไม่ระบุ'), isNull);
    });
  });

  group('ตัวกรองของ /assets', () {
    test('ส่งแค่ตัวกรองที่เปิดใช้ ไม่ส่งค่าว่างกับ false', () {
      final params = const AssetQuery().toParams();

      expect(params, {'page': 1, 'page_size': kAssetPageSize});
    });

    test('ตัวกรองที่ตั้งไว้แปลงเป็นชื่อพารามิเตอร์ของ API', () {
      final params = const AssetQuery(
        keyword: 'ASUS',
        typeId: 'NOTEBOOK',
        statusId: 'IN-USE',
        siteId: 'HQ',
        custodian: '68051',
        warrantyExpiring: true,
        incompleteOnly: true,
        includeInactive: true,
        page: 2,
        pageSize: 20,
        sortBy: 'asset_id',
        sortDesc: true,
      ).toParams();

      expect(params['keyword'], 'ASUS');
      expect(params['asset_type'], 'NOTEBOOK');
      expect(params['status_id'], 'IN-USE');
      expect(params['current_site_id'], 'HQ');
      expect(params['current_custodian'], '68051');
      expect(params['warranty_expiring'], isTrue);
      expect(params['incomplete_only'], isTrue);
      expect(params['include_inactive'], isTrue);
      expect(params['page'], 2);
      expect(params['page_size'], 20);
      expect(params['sort_by'], 'asset_id');
      expect(params['sort_desc'], isTrue);
    });

    test('hasFilter ไม่นับหน้าที่กำลังดู', () {
      expect(const AssetQuery(page: 3).hasFilter, isFalse);
      expect(const AssetQuery(keyword: 'a').hasFilter, isTrue);
    });
  });

  group('parseAssetSearch', () {
    test('ตอบเป็น array เปล่า ๆ ก็อ่านได้ ยอดรวมไม่รู้', () {
      final result = parseAssetSearch(
        [
          {'asset_id': 'A1'},
          {'asset_id': 'A2'},
        ],
        page: 1,
        pageSize: 50,
      );

      expect(result.items, hasLength(2));
      expect(result.total, isNull);
      // ได้มาไม่เต็มหน้า แปลว่าหมดแล้ว
      expect(result.hasMore, isFalse);
    });

    test('ตอบเป็น object ที่ห่อรายการกับยอดรวมมาด้วย', () {
      final result = parseAssetSearch(
        {
          'total': 120,
          'items': [
            {'asset_id': 'A1'},
          ],
        },
        page: 1,
        pageSize: 50,
      );

      expect(result.items.single.id, 'A1');
      expect(result.total, 120);
      expect(result.hasMore, isTrue);
    });

    test('หน้าสุดท้ายตามยอดรวมแล้วไม่ต้องโหลดต่อ', () {
      final result = parseAssetSearch(
        {'total': 100, 'data': []},
        page: 2,
        pageSize: 50,
      );

      expect(result.hasMore, isFalse);
    });

    test('แถวที่ไม่มีรหัสทรัพย์สินถูกตัดทิ้ง เปิดรายละเอียดต่อไม่ได้อยู่ดี', () {
      final result = parseAssetSearch(
        [
          {'asset_id': 'A1'},
          {'asset_name': 'ของไม่มีรหัส'},
        ],
        page: 1,
        pageSize: 50,
      );

      expect(result.items, hasLength(1));
    });

    test('ของที่อ่านไม่ออกคืนลิสต์ว่าง ไม่ throw', () {
      expect(parseAssetSearch('', page: 1, pageSize: 50).items, isEmpty);
      expect(
        parseAssetSearch('ไม่พบข้อมูล', page: 1, pageSize: 50).items,
        isEmpty,
      );
    });
  });

  group('ประวัติการเปลี่ยนแปลง', () {
    test('อ่านแถวที่เก็บละเอียดถึงระดับช่อง', () {
      final entry = AssetLogEntry.fromJson({
        'change_date': '2026-09-21T10:30:00',
        'changed_by': '68051',
        'field_name': 'current_site_id',
        'old_value': 'HQ',
        'new_value': 'BKK01',
        'change_note': 'ย้ายตามพนักงาน',
        'ref_no': 'MV-001',
      });

      expect(entry.at, DateTime(2026, 9, 21, 10, 30));
      expect(entry.by, '68051');
      expect(entry.refNo, 'MV-001');
      expect(entry.oldValue, 'HQ');
      expect(entry.newValue, 'BKK01');
      // ชื่อคอลัมน์ดิบห้ามหลุดไปถึงหน้าจอ
      expect(entry.fieldLabel, 'แผนกที่ดูแล');
    });

    test('แถวที่ไม่ได้เก็บรายช่อง ยังอ่านเหตุผลได้', () {
      final entry = AssetLogEntry.fromJson({
        'change_date': '2026-09-21T10:30:00',
        'change_note': 'ย้ายไปสาขาบางนา',
      });

      expect(entry.note, 'ย้ายไปสาขาบางนา');
      expect(entry.fieldLabel, '');
    });

    test('แถวว่างเปล่าไม่เอามาโชว์', () {
      expect(AssetLogEntry.fromJson({'id': ''}).isUsable, isFalse);
    });

    test('เรียงใหม่สุดขึ้นก่อน แถวไม่มีวันที่ไปท้ายสุด', () {
      final entries = [
        const AssetLogEntry(note: 'ไม่มีวันที่'),
        AssetLogEntry(at: DateTime(2026, 1, 1), note: 'เก่า'),
        AssetLogEntry(at: DateTime(2026, 9, 1), note: 'ใหม่'),
      ];

      sortAssetLog(entries);

      expect(entries.map((e) => e.note).toList(), [
        'ใหม่',
        'เก่า',
        'ไม่มีวันที่',
      ]);
    });
  });
}
