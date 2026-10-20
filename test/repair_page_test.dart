import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/repair/repair_page.dart';

/// แถบหัวของหน้ารายการใบแจ้งซ่อม
///
/// เทสต์นี้ยิง API ไม่ได้ หน้าจะจบที่สถานะ error ซึ่งไม่เป็นไร เพราะสิ่งที่
/// เช็คอยู่คือแถบหัว ไม่ใช่เนื้อหา
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RepairPage()));
    await tester.pumpAndSettle();
    tester.takeException();
  }

  testWidgets('แถบหัวไม่มีไอคอนเปล่าให้เดาแล้ว', (tester) async {
    await pump(tester);

    // ทะเบียนเครื่องย้ายไปเป็นการ์ดทางลัดในเนื้อหา ถามบอทเป็นปุ่มลอย
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('กดถามบอทแล้วแผ่นเลื่อนขึ้นมา ไม่ใช่เปิดหน้าใหม่', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('ถามบอท'));
    await tester.pumpAndSettle();
    tester.takeException();

    // หัวแผ่นโผล่มา และหน้าเดิมยังอยู่ข้างหลัง (ปุ่มแจ้งซ่อมยังอยู่ในต้นไม้)
    expect(find.text('ติดตามสถานะซ่อม'), findsOneWidget);
    expect(find.text('แจ้งซ่อม'), findsWidgets);
  });

  testWidgets('ปุ่มลอยมีสองชั้น ถามบอทอยู่เหนือแจ้งซ่อม', (tester) async {
    await pump(tester);

    final chat = tester.getCenter(find.text('ถามบอท'));
    final report = tester.getCenter(find.text('แจ้งซ่อม').last);

    // แกน y ยิ่งน้อยยิ่งอยู่สูง
    expect(chat.dy, lessThan(report.dy));
    expect(chat.dx, closeTo(report.dx, 40));
  });
}
