import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';

void main() {
  group('buildAssetPayload', () {
    test('ส่งเฉพาะสามช่องบังคับเมื่อกรอกแค่นั้น', () {
      final payload = buildAssetPayload(
        assetId: 'F800-6703-0001',
        assetName: 'โน้ตบุ๊ก ASUS',
        assetType: 'NOTEBOOK',
      );

      expect(payload, {
        'asset_id': 'F800-6703-0001',
        'asset_name': 'โน้ตบุ๊ก ASUS',
        'asset_type': 'NOTEBOOK',
      });
    });

    test('ช่องที่ไม่ได้กรอกไม่ถูกส่งไปเป็นสตริงว่าง', () {
      final payload = buildAssetPayload(
        assetId: 'A1',
        assetName: 'ของ',
        assetType: 'T1',
        serialNo: '   ',
        brand: '',
        statusId: 'IN-USE',
      );

      expect(payload.containsKey('serial_no'), isFalse);
      expect(payload.containsKey('brand'), isFalse);
      expect(payload['status_id'], 'IN-USE');
    });

    test('ตัดช่องว่างหัวท้ายของทุกช่อง', () {
      final payload = buildAssetPayload(
        assetId: '  A1  ',
        assetName: ' ของ ',
        assetType: ' T1 ',
        custodian: ' 68051 ',
      );

      expect(payload['asset_id'], 'A1');
      expect(payload['asset_name'], 'ของ');
      expect(payload['asset_type'], 'T1');
      expect(payload['current_custodian'], '68051');
    });

    test('วันที่ส่งเป็นเที่ยงคืนไม่มี timezone', () {
      final payload = buildAssetPayload(
        assetId: 'A1',
        assetName: 'ของ',
        assetType: 'T1',
        acceptDate: DateTime(2026, 9, 21, 14, 30),
        purchaseDate: DateTime(2026, 1, 5),
        warrantyExpireDate: DateTime(2029, 12, 31),
      );

      expect(payload['accept_date'], '2026-09-21T00:00:00');
      expect(payload['purchase_date'], '2026-01-05T00:00:00');
      expect(payload['warranty_expire_date'], '2029-12-31T00:00:00');
    });

    test('ราคาส่งเป็นตัวเลข ไม่ใช่ข้อความ', () {
      final payload = buildAssetPayload(
        assetId: 'A1',
        assetName: 'ของ',
        assetType: 'T1',
        purchasePrice: assetPriceOf('25,900'),
      );

      expect(payload['purchase_price'], 25900.0);
    });
  });

  group('ตรวจค่าก่อนส่ง', () {
    test('รหัสทรัพย์สินตามรูปแบบของ schema', () {
      expect(assetIdError('F800-6703-0001'), isNull);
      expect(assetIdError('TP0001'), isNull);

      expect(assetIdError(''), isNotNull);
      expect(assetIdError('-TP01'), isNotNull);
      expect(assetIdError('TP01-'), isNotNull);
      expect(assetIdError('TP--01'), isNotNull);
      expect(assetIdError('TP 01'), isNotNull);
      expect(assetIdError('ทรัพย์01'), isNotNull);
      expect(assetIdError('A' * (kAssetIdMax + 1)), isNotNull);
    });

    test('ราคาปล่อยว่างได้ แต่ติดลบหรือเกินเพดานไม่ได้', () {
      expect(assetPriceError(''), isNull);
      expect(assetPriceError('25,900'), isNull);
      expect(assetPriceError('0'), isNull);

      expect(assetPriceError('abc'), isNotNull);
      expect(assetPriceError('-1'), isNotNull);
      expect(assetPriceError('99999999999999'), isNotNull);
    });
  });

  group('AssetLookup.fromJson', () {
    test('อ่านชื่อช่องแบบ snake_case ตาม schema ของ assettype', () {
      final item = AssetLookup.fromJson({
        'type_id': 'NOTEBOOK',
        'desc_th': 'โน้ตบุ๊ก',
        'desc_en': 'Notebook',
      });

      expect(item.code, 'NOTEBOOK');
      expect(item.label, 'โน้ตบุ๊ก');
      expect(item.detailLabel, 'โน้ตบุ๊ก (NOTEBOOK)');
    });

    test('อ่านชื่อช่องแบบ ITRepair (details_th) ได้ด้วย', () {
      final item = AssetLookup.fromJson({
        'status_id': 'IN-USE',
        'details_th': 'ใช้งานอยู่',
        'details_en': 'In use',
      });

      expect(item.code, 'IN-USE');
      expect(item.label, 'ใช้งานอยู่');
    });

    test('ไม่มีชื่อกำกับก็ยังเลือกได้ โชว์รหัสแทน', () {
      final item = AssetLookup.fromJson({'type_id': 'MONITOR'});

      expect(item.label, 'MONITOR');
      expect(item.detailLabel, 'MONITOR');
    });
  });

  group('decodeAssetList', () {
    test('อ่าน list ปกติ', () {
      final rows = decodeAssetList([
        {'type_id': 'A'},
        {'type_id': 'B'},
      ]);

      expect(rows, hasLength(2));
      expect(rows.first['type_id'], 'A');
    });

    test('อ่าน list ที่ถูกห่อมาเป็นสตริง json', () {
      final rows = decodeAssetList('[{"type_id":"A"}]');

      expect(rows, hasLength(1));
      expect(rows.first['type_id'], 'A');
    });

    test('list ของข้อความล้วนถือว่าเป็นรหัส', () {
      final rows = decodeAssetList(['NOTEBOOK', 'MONITOR']);

      expect(AssetLookup.fromJson(rows.first).code, 'NOTEBOOK');
    });

    test('ของที่อ่านไม่ออกคืนลิสต์ว่าง ไม่ throw', () {
      expect(decodeAssetList(null), isEmpty);
      expect(decodeAssetList(''), isEmpty);
      expect(decodeAssetList('ไม่พบข้อมูล'), isEmpty);
      expect(decodeAssetList({'type_id': 'A'}), isEmpty);
    });
  });

  group('assetMessageOf', () {
    test('ใช้ข้อความจากเซิร์ฟเวอร์เมื่อตอบเป็นข้อความเปล่า', () {
      expect(
        assetMessageOf('บันทึกสำเร็จ', fallback: 'x'),
        'บันทึกสำเร็จ',
      );
    });

    test('ดึงข้อความออกจาก json ไม่เอา Map ทั้งก้อนไปโชว์', () {
      expect(
        assetMessageOf({'success': true, 'message': 'เพิ่มแล้ว'}, fallback: 'x'),
        'เพิ่มแล้ว',
      );
    });

    test('ตอบว่างมาก็ยังมีข้อความสำรอง', () {
      expect(assetMessageOf('', fallback: 'บันทึกทรัพย์สินแล้ว'),
          'บันทึกทรัพย์สินแล้ว');
      expect(assetMessageOf(null, fallback: 'บันทึกทรัพย์สินแล้ว'),
          'บันทึกทรัพย์สินแล้ว');
      expect(assetMessageOf({'success': true}, fallback: 'สำรอง'), 'สำรอง');
    });
  });
}
