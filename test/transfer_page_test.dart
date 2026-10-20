import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:claim/page/asset/asset_list_page.dart';
import 'package:claim/page/asset/transfer_create_page.dart';
import 'package:claim/page/asset/transfer_detail_page.dart';
import 'package:claim/page/asset/transfer_list_page.dart';

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  // หน้าสร้างใบตั้งวันที่คาดว่าของจะถึงไว้ให้ แล้ววาดเป็น พ.ศ. ตั้งแต่เฟรมแรก
  setUpAll(() => initializeDateFormatting('th', null));

  const noSession = 'ยังไม่ได้เชื่อมต่อระบบทรัพย์สิน กรุณาเข้าสู่ระบบใหม่';

  testWidgets('รายการใบ — ไม่มี token บอกให้ล็อกอินใหม่ ไม่ให้ปุ่มลองใหม่', (
    tester,
  ) async {
    await _pump(tester, const TransferListPage());

    expect(find.text('ใบโอนย้าย'), findsOneWidget);
    expect(find.text(noSession), findsOneWidget);
    // กดลองใหม่กี่ทีก็ไม่ผ่านเมื่อไม่มี token
    expect(find.text('ลองใหม่'), findsNothing);
  });

  testWidgets('รายการใบ — เปิดมาอยู่ที่ "รอฉันทำ" เพราะคนส่วนใหญ่มาเพราะมีงานค้าง', (
    tester,
  ) async {
    await _pump(tester, const TransferListPage());

    expect(find.text('รอฉันทำ'), findsOneWidget);
    expect(find.text('ทั้งหมด'), findsOneWidget);
    expect(find.text('ค้างทาง'), findsOneWidget);
  });

  testWidgets('รายละเอียดใบ — ไม่มี token ต้องไม่โชว์แถบปุ่มล่างจอ', (
    tester,
  ) async {
    await _pump(tester, const TransferDetailPage(transferNo: 'TRF-2026-0003'));

    expect(find.text('TRF-2026-0003'), findsOneWidget);
    expect(find.text(noSession), findsOneWidget);
    // โหลดใบไม่ได้ = ไม่รู้ว่ากดอะไรได้ ห้ามเดาว่ากดได้
    expect(find.text('ส่งอนุมัติ'), findsNothing);
    expect(find.text('อนุมัติ'), findsNothing);
    expect(find.text('รับของ'), findsNothing);
  });

  testWidgets('สร้างใบ — ยังไม่เลือกของ ปุ่มสร้างต้องกดไม่ได้และบอกว่าขาดอะไร', (
    tester,
  ) async {
    await _pump(tester, const TransferCreatePage());

    expect(find.text('เลือกทรัพย์สินที่จะย้ายอย่างน้อยหนึ่งชิ้น'), findsOneWidget);

    // หาด้วย predicate ไม่ใช่ byType เพราะ FilledButton.icon สร้างคลาสลูกออกมา
    final button = tester.widget<FilledButton>(
      find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('สร้างใบ — วันที่คาดว่าถึงตั้งต้นให้แล้ว ไม่ปล่อยว่างให้กรอกเอง', (
    tester,
  ) async {
    await _pump(tester, const TransferCreatePage());

    expect(find.text('แตะเพื่อเลือกวันที่'), findsNothing);
  });

  testWidgets('สร้างใบ — ไม่ระบุผู้รับ ต้องให้เลือกสาขาและแผนกเอง', (
    tester,
  ) async {
    await _pump(tester, const TransferCreatePage());

    // โหมดตั้งต้นคือระบุผู้รับ สาขากับแผนกดึงจากคน ไม่มีช่องให้เลือกเอง
    expect(find.text('ผู้รับปลายทาง'), findsOneWidget);
    expect(find.text('แผนกปลายทาง'), findsNothing);

    await tester.tap(find.text('ไม่ระบุผู้รับ'));
    await tester.pumpAndSettle();

    expect(find.text('ผู้รับปลายทาง'), findsNothing);
    expect(find.text('สาขาปลายทาง'), findsOneWidget);
    expect(find.text('แผนกปลายทาง'), findsOneWidget);
    expect(find.text('หัวหน้าแผนกปลายทางจะเป็นคนรับของ'), findsOneWidget);
  });

  group('ทางเข้าเพิ่มทรัพย์สิน', () {
    // เคยพลาดมาแล้ว: ย้ายแถบหน้าแรกให้ไปหน้าใบโอนย้ายแทนหน้าทะเบียน แล้วปุ่ม +
    // ที่คนเคยกดกลายเป็น "สร้างใบ" คนหาปุ่มเพิ่มทรัพย์สินไม่เจอทันที
    testWidgets('หน้าทะเบียนต้องมีปุ่มเพิ่มทรัพย์สินเสมอ', (tester) async {
      await _pump(tester, const AssetListPage());

      expect(find.byTooltip('เพิ่มทรัพย์สิน'), findsOneWidget);
    });

    testWidgets('หน้าใบโอนย้ายมีทางลัดข้ามไปทะเบียน ไม่ต้องย้อนกลับหน้าแรก', (
      tester,
    ) async {
      await _pump(tester, const TransferListPage());

      await tester.tap(find.byTooltip('เมนูเพิ่มเติม'));
      await tester.pumpAndSettle();

      expect(find.text('ทะเบียนทรัพย์สิน (เพิ่ม/ค้นของ)'), findsOneWidget);
    });
  });
}
