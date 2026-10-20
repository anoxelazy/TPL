import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_log_view.dart';
import 'package:claim/page/asset/asset_models.dart';

/// ประวัติของจริงจาก `GET /api/AssetTransfer/asset/ASE105234/log` (24 ก.ย. 2026)
const _logJson = '''
[
  {"log_id":14,"action_type":"TRANSFER","field_name":"status_id",
   "old_value":"IN_TRANSIT","new_value":"IN_USE",
   "change_note":"ผลการรับของ: RECEIVED_OK","ref_no":"TRF-2026-0003",
   "action_by":"68196","action_date":"2026-09-23T14:25:16.147"},
  {"log_id":6,"action_type":"UPDATE","field_name":"purchase_price",
   "old_value":null,"new_value":"15250.25","change_note":"ทดสอบข้อมูล",
   "ref_no":null,"action_by":"66019","action_date":"2026-09-19T15:28:40.486"},
  {"log_id":5,"action_type":"UPDATE","field_name":"accept_date",
   "old_value":null,"new_value":"2026-09-19","change_note":"ทดสอบข้อมูล",
   "ref_no":null,"action_by":"66019","action_date":"2026-09-19T15:28:40.486"},
  {"log_id":1,"action_type":"UPDATE","field_name":"asset_name",
   "old_value":"ทรัพย์สินทดสอบ1","new_value":"ทดสอบเปลี่ยนข้อมูล",
   "change_note":"ทดสอบข้อมูล","ref_no":null,"action_by":"66019",
   "action_date":"2026-09-19T15:28:40.486"}
]
''';

List<AssetLogEvent> _events() {
  final entries = [
    for (final row in jsonDecode(_logJson) as List)
      AssetLogEntry.fromJson(Map<String, dynamic>.from(row as Map)),
  ];
  sortAssetLog(entries);
  return groupAssetLog(entries);
}

Future<void> _pump(WidgetTester tester, {List<AssetLogEvent>? events}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AssetLogTimeline(
              events: events ?? _events(),
              statusNames: const {
                'IN_TRANSIT': 'อยู่ระหว่างขนย้าย',
                'IN_USE': 'กำลังใช้งาน',
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => initializeDateFormatting('th', null));

  testWidgets('ชื่อคอลัมน์ดิบต้องไม่หลุดไปถึงหน้าจอ', (tester) async {
    await _pump(tester);

    for (final raw in const [
      'status_id',
      'purchase_price',
      'accept_date',
      'asset_name',
    ]) {
      expect(find.textContaining(raw), findsNothing, reason: raw);
    }

    expect(find.text('สถานะ'), findsOneWidget);
    expect(find.text('ราคาซื้อ'), findsOneWidget);
    expect(find.text('ชื่อทรัพย์สิน'), findsOneWidget);
  });

  testWidgets('ประเภททรัพย์สินไม่โชว์ในประวัติ', (tester) async {
    await _pump(
      tester,
      events: groupAssetLog([
        AssetLogEntry(
          at: DateTime(2026, 9, 19, 15, 28),
          note: 'ทดสอบข้อมูล',
          field: 'asset_type',
          oldValue: 'IT-TEST-01',
          newValue: 'IT-TEST-02',
        ),
      ]),
    );

    expect(find.text('ประเภท'), findsNothing);
    expect(find.textContaining('IT-TEST'), findsNothing);
    // เหตุการณ์ยังต้องขึ้น เวลากับเหตุผลยังมีค่าแม้ไม่มีตารางใต้มัน
    expect(find.text('ทดสอบข้อมูล'), findsOneWidget);
  });

  testWidgets('ค่าขยะคำว่า string ต้องไม่โผล่ให้คนอ่านเห็น', (tester) async {
    await _pump(
      tester,
      events: groupAssetLog([
        AssetLogEntry(
          at: DateTime(2026, 9, 19, 15, 28),
          field: 'remark',
          oldValue: 'string',
          newValue: 'ของจริง',
        ),
      ]),
    );

    expect(find.text('string'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('ของจริง'), findsOneWidget);
  });

  testWidgets('รหัสสถานะถูกแปลเป็นชื่อไทย', (tester) async {
    await _pump(tester);

    expect(find.text('อยู่ระหว่างขนย้าย'), findsOneWidget);
    expect(find.text('กำลังใช้งาน'), findsOneWidget);
    expect(find.textContaining('IN_TRANSIT'), findsNothing);
  });

  testWidgets('ราคาใส่ลูกน้ำและหน่วย ไม่ใช่ตัวเลขดิบ', (tester) async {
    await _pump(tester);

    expect(find.text('15,250.25 บาท'), findsOneWidget);
  });

  testWidgets('วันที่แปลงเป็น พ.ศ. ไม่ใช่ 2026-09-19', (tester) async {
    await _pump(tester);

    expect(find.textContaining('2026-09-19'), findsNothing);
    expect(find.textContaining('2569'), findsWidgets);
  });

  testWidgets('ช่องที่เดิมยังไม่เคยกรอก โชว์ขีด ไม่ใช่ช่องว่างข้างลูกศร', (
    tester,
  ) async {
    await _pump(tester);

    // purchase_price กับ accept_date เดิมเป็น null ทั้งคู่
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('สามแถวจากการบันทึกครั้งเดียว เหตุผลขึ้นครั้งเดียว', (
    tester,
  ) async {
    await _pump(tester);

    // ถ้าไม่ยุบกลุ่ม จะเห็น "ทดสอบข้อมูล" สามรอบ
    expect(find.text('ทดสอบข้อมูล'), findsOneWidget);
  });

  testWidgets('แยกป้ายโอนย้ายออกจากการแก้ข้อมูล', (tester) async {
    await _pump(tester);

    expect(find.text('โอนย้าย'), findsOneWidget);
    expect(find.text('แก้ไขข้อมูล'), findsOneWidget);
  });

  testWidgets('โชว์คนทำกับเลขเอกสาร', (tester) async {
    await _pump(tester);

    // ยังหาชื่อจากรหัสไม่ได้ในเทสต์ (ไม่มี session) ต้องถอยไปโชว์รหัส
    expect(
      find.text('โดย 68196 · เอกสาร TRF-2026-0003'),
      findsOneWidget,
    );
  });

  testWidgets('เวลาขึ้นด้วย ไม่ใช่แค่วันที่', (tester) async {
    await _pump(tester);

    expect(find.textContaining('14:25'), findsOneWidget);
  });

  testWidgets('ยังไม่มีประวัติ บอกว่าของยังไม่เคยถูกแตะ ไม่ใช่จอว่าง', (
    tester,
  ) async {
    await _pump(tester, events: const []);

    expect(
      find.text('ยังไม่มีประวัติ ของชิ้นนี้ยังไม่เคยถูกแก้หรือโอนย้าย'),
      findsOneWidget,
    );
  });

  testWidgets('ช่องที่ไม่รู้จักถูกซ่อน ไม่โชว์ชื่อคอลัมน์ดิบให้คนงง', (
    tester,
  ) async {
    await _pump(
      tester,
      events: groupAssetLog([
        AssetLogEntry(
          at: DateTime(2026, 9, 24, 9, 0),
          note: 'แก้ตามผลตรวจนับ',
          field: 'some_new_column',
          oldValue: 'a',
          newValue: 'b',
        ),
      ]),
    );

    expect(find.text('some_new_column'), findsNothing);
    expect(find.text('b'), findsNothing);
    expect(find.text('แก้ตามผลตรวจนับ'), findsOneWidget);
  });

  testWidgets('ค่าภายในของระบบอย่าง create_by ไม่โชว์', (tester) async {
    await _pump(
      tester,
      events: groupAssetLog([
        AssetLogEntry(
          at: DateTime(2026, 9, 24, 9, 0),
          field: 'create_by',
          oldValue: 'SYSTEM',
          newValue: '68148',
        ),
      ]),
    );

    expect(find.textContaining('SYSTEM'), findsNothing);
  });
}
