import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';

/// ประวัติของจริงจาก `GET /api/AssetTransfer/asset/ASE105234/log` (24 ก.ย. 2026)
///
/// เป็นเคสที่ครบทุกปัญหาของหน้าประวัติแบบเดิมในก้อนเดียว: หกแถวล่างมาจากการกด
/// บันทึกครั้งเดียว (เวลา คนทำ เหตุผล เหมือนกันเป๊ะ) และทุกแถวเก็บชื่อคอลัมน์
/// ดิบกับค่ารหัสดิบ
const _logJson = '''
[
  {"log_id":14,"action_type":"TRANSFER","field_name":"status_id",
   "old_value":"IN_TRANSIT","new_value":"IN_USE",
   "change_note":"ผลการรับของ: RECEIVED_OK","ref_no":"TRF-2026-0003",
   "action_by":"68196","action_date":"2026-09-23T14:25:16.147"},
  {"log_id":13,"action_type":"TRANSFER","field_name":"status_id",
   "old_value":"IN_STOCK","new_value":"IN_TRANSIT",
   "change_note":"ส่งออกจากแผนก F0000 สาขา BKK10","ref_no":"TRF-2026-0003",
   "action_by":"63205","action_date":"2026-09-23T14:22:06.966"},
  {"log_id":6,"action_type":"UPDATE","field_name":"purchase_price",
   "old_value":null,"new_value":"15250.25","change_note":"ทดสอบข้อมูล",
   "ref_no":null,"action_by":"66019","action_date":"2026-09-19T15:28:40.486"},
  {"log_id":5,"action_type":"UPDATE","field_name":"accept_date",
   "old_value":null,"new_value":"2026-09-19","change_note":"ทดสอบข้อมูล",
   "ref_no":null,"action_by":"66019","action_date":"2026-09-19T15:28:40.486"},
  {"log_id":3,"action_type":"UPDATE","field_name":"serial_no",
   "old_value":"XXXXXCSAEAA","new_value":"UI5989212HUAW",
   "change_note":"ทดสอบข้อมูล","ref_no":null,"action_by":"66019",
   "action_date":"2026-09-19T15:28:40.486"},
  {"log_id":1,"action_type":"UPDATE","field_name":"asset_name",
   "old_value":"ทรัพย์สินทดสอบ1","new_value":"ทดสอบเปลี่ยนข้อมูล",
   "change_note":"ทดสอบข้อมูล","ref_no":null,"action_by":"66019",
   "action_date":"2026-09-19T15:28:40.486"}
]
''';

List<AssetLogEntry> _entries() => [
  for (final row in jsonDecode(_logJson) as List)
    AssetLogEntry.fromJson(Map<String, dynamic>.from(row as Map)),
];

void main() {
  setUpAll(() => initializeDateFormatting('th', null));

  group('AssetLogEntry', () {
    test('อ่านช่อง action_by ที่ของจริงใช้ ไม่ใช่ changed_by ที่เดาไว้', () {
      // เดิมลิสต์ไม่มี actionby บรรทัด "โดย …" เลยว่างทุกแถว
      expect(_entries().first.by, '68196');
    });

    test('อ่าน action_type แยกโอนย้ายออกจากการแก้ข้อมูลได้', () {
      final entries = _entries();

      expect(entries.first.actionType, 'TRANSFER');
      expect(entries.first.isTransfer, isTrue);
      expect(entries.last.isTransfer, isFalse);
    });

    test('เก็บเวลาไว้ด้วย ไม่ตัดเหลือแค่วัน', () {
      // ส่งออกกับรับเข้าห่างกันสามนาที ตัดเวลาทิ้งแล้วเรียงลำดับไม่ออก
      expect(_entries().first.at, DateTime(2026, 9, 23, 14, 25, 16));
    });
  });

  group('assetFieldLabel', () {
    test('ชื่อคอลัมน์ดิบต้องแปลงเป็นคำที่คนอ่านออก', () {
      expect(assetFieldLabel('status_id'), 'สถานะ');
      expect(assetFieldLabel('current_site_id'), 'แผนกที่ดูแล');
      expect(assetFieldLabel('current_custodian'), 'ผู้ครอบครอง');
      expect(assetFieldLabel('purchase_price'), 'ราคาซื้อ');
      expect(assetFieldLabel('warranty_expire_date'), 'วันหมดประกัน');
    });

    test('ชื่อที่ไม่รู้จักคืนของเดิม ดีกว่าซ่อนบรรทัดจนไม่รู้ว่าอะไรเปลี่ยน', () {
      expect(assetFieldLabel('some_new_column'), 'some_new_column');
    });

    test('ไม่มีชื่อช่องคืนค่าว่าง หน้าจอจะได้ข้ามตารางไปเลย', () {
      expect(assetFieldLabel(''), '');
      expect(assetFieldLabel('   '), '');
    });
  });

  group('assetLogShowsField', () {
    test('ช่องที่แปลเป็นภาษาคนได้ โชว์', () {
      expect(assetLogShowsField('status_id'), isTrue);
      expect(assetLogShowsField('current_site_id'), isTrue);
      expect(assetLogShowsField('remark'), isTrue);
    });

    test('ประเภททรัพย์สินถูกซ่อน เพราะตารางประเภทมีแถวขยะปน', () {
      expect(assetLogShowsField('asset_type'), isFalse);
    });

    test('ค่าภายในของระบบถูกซ่อน คนใช้งานไม่ได้เป็นคนแก้', () {
      for (final field in const [
        'is_active',
        'create_by',
        'create_date',
        'modify_by',
        'modify_date',
      ]) {
        expect(assetLogShowsField(field), isFalse, reason: field);
      }
    });

    test('ช่องที่ไม่รู้จักถูกซ่อน เป็น whitelist ไม่ใช่ blacklist', () {
      // backend เพิ่มคอลัมน์ใหม่แล้วมันโผล่เป็นชื่อดิบในประวัติทันทีคือสิ่งที่
      // ไม่อยากให้เกิด ต้องตั้งใจเพิ่มใน kAssetFieldLabels ก่อนถึงจะโชว์
      expect(assetLogShowsField('some_new_column'), isFalse);
      expect(assetLogShowsField(''), isFalse);
    });
  });

  group('assetLogValueIsPlaceholder', () {
    test('ค่าตั้งต้นของ swagger ที่หลุดลงฐานข้อมูลจริง', () {
      expect(assetLogValueIsPlaceholder('string'), isTrue);
      expect(assetLogValueIsPlaceholder('STRING'), isTrue);
      expect(assetLogValueIsPlaceholder(' null '), isTrue);
    });

    test('ค่าจริงต้องไม่ถูกเข้าใจผิดว่าเป็นขยะ', () {
      expect(assetLogValueIsPlaceholder('IN_USE'), isFalse);
      expect(assetLogValueIsPlaceholder('ทดสอบ'), isFalse);
      expect(assetLogValueIsPlaceholder(''), isFalse);
    });
  });

  group('AssetLogEvent.visibleChanges', () {
    test('กรองเฉพาะช่องที่โชว์ได้ แต่เหตุการณ์ยังอยู่', () {
      final event = groupAssetLog([
        const AssetLogEntry(field: 'asset_type', newValue: 'IT-NB'),
        const AssetLogEntry(field: 'status_id', newValue: 'IN_USE'),
        const AssetLogEntry(field: 'create_by', newValue: '68148'),
      ]).single;

      expect(event.changes, hasLength(3));
      expect(event.visibleChanges, hasLength(1));
      expect(event.visibleChanges.single.field, 'status_id');
    });

    test('แก้แต่ช่องที่ซ่อนทั้งหมด ได้ลิสต์ว่าง หน้าจอจะได้ไม่วาดตารางเปล่า', () {
      final event = groupAssetLog([
        const AssetLogEntry(field: 'asset_type', newValue: 'IT-NB'),
      ]).single;

      expect(event.visibleChanges, isEmpty);
    });
  });

  group('groupAssetLog', () {
    test('หกแถวจากการกดบันทึกครั้งเดียว ต้องยุบเหลือเหตุการณ์เดียว', () {
      final events = groupAssetLog(_entries());

      // 2 โอนย้าย (คนละเวลา) + 1 การแก้ข้อมูลที่กระทบสี่ช่อง
      expect(events, hasLength(3));
      expect(events.last.changes, hasLength(4));
    });

    test('เหตุผลกับคนทำอยู่ที่ระดับเหตุการณ์ ไม่ซ้ำทุกบรรทัด', () {
      final event = groupAssetLog(_entries()).last;

      expect(event.note, 'ทดสอบข้อมูล');
      expect(event.by, '66019');
      expect(event.actionLabel, 'แก้ไขข้อมูล');
    });

    test('โอนย้ายสองครั้งในนาทีใกล้กันต้องไม่ถูกยุบรวม', () {
      final events = groupAssetLog(_entries());

      expect(events[0].refNo, 'TRF-2026-0003');
      expect(events[0].by, '68196');
      expect(events[1].by, '63205');
      expect(events[0].actionLabel, 'โอนย้าย');
    });

    test('คนละคนกดในวินาทีเดียวกัน ต้องแยกเหตุการณ์', () {
      final at = DateTime(2026, 9, 23, 14, 0);
      final events = groupAssetLog([
        AssetLogEntry(at: at, by: 'A', field: 'brand', newValue: 'x'),
        AssetLogEntry(at: at, by: 'B', field: 'model', newValue: 'y'),
      ]);

      expect(events, hasLength(2));
    });

    test('ลำดับที่ส่งเข้ามาถูกรักษาไว้ ใหม่สุดยังอยู่บนสุด', () {
      final events = groupAssetLog(_entries());

      expect(events.first.at!.isAfter(events.last.at!), isTrue);
    });

    test('ประวัติว่างได้ลิสต์ว่าง ไม่ใช่เหตุการณ์เปล่า', () {
      expect(groupAssetLog(const []), isEmpty);
    });
  });

  group('เรียงแล้วค่อยจัดกลุ่ม', () {
    test('sortAssetLog แล้ว groupAssetLog ต้องได้ใหม่สุดขึ้นก่อน', () {
      final entries = _entries()..shuffle();
      sortAssetLog(entries);

      final events = groupAssetLog(entries);

      expect(events.first.at, DateTime(2026, 9, 23, 14, 25, 16));
      expect(events.last.at, DateTime(2026, 9, 19, 15, 28, 40));
    });
  });

  group('assetDateTimeLabel', () {
    test('มีเวลาต่อท้ายวันที่ ใช้แยกเหตุการณ์ในวันเดียวกัน', () {
      final label = assetDateTimeLabel(DateTime(2026, 9, 23, 14, 25));

      expect(label, contains('14:25'));
      expect(label, contains('น.'));
    });
  });
}
