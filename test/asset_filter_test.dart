import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/asset_list_page.dart';
import 'package:claim/page/asset/asset_models.dart';

/// หน้านี้ยิง API ตอนเปิด แต่ในเทสต์ไม่มี token ของ Mobile API จึงตกไปที่หน้า
/// บอกให้ล็อกอินใหม่ ส่วนช่องค้นหากับปุ่มตัวกรองอยู่นอกส่วนนั้น ยังกดได้ตามปกติ
Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const MaterialApp(home: AssetListPage()));
  await tester.pumpAndSettle();
}

void main() {
  group('นับจำนวนตัวกรอง', () {
    test('ไม่นับคำค้น เพราะมีช่องของตัวเองอยู่แล้ว', () {
      expect(const AssetQuery(keyword: 'ASUS').filterCount, 0);
    });

    test('นับทุกตัวที่เปิดอยู่', () {
      const query = AssetQuery(
        keyword: 'ASUS',
        typeId: 'NOTEBOOK',
        siteId: 'HQ',
        warrantyExpiring: true,
      );

      expect(query.filterCount, 3);
    });

    test('ล้างตัวกรองแล้วคำค้นต้องยังอยู่', () {
      const query = AssetQuery(keyword: 'ASUS', typeId: 'NOTEBOOK');
      final cleared = query.cleared();

      expect(cleared.filterCount, 0);
      expect(cleared.keyword, 'ASUS');
    });
  });

  group('หน้าตาตัวกรองบนหน้าจอ', () {
    testWidgets('ยังไม่ได้กรอง มีแค่ปุ่มเดียว ไม่มีแถบชิป', (tester) async {
      await _open(tester);

      expect(find.text('กรอง'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('กดปุ่มแล้วแผ่นตัวกรองเด้งขึ้นมา', (tester) async {
      await _open(tester);

      await tester.tap(find.text('กรอง'));
      await tester.pumpAndSettle();

      expect(find.text('ตัวกรอง'), findsOneWidget);
      expect(find.text('ใกล้หมดประกัน'), findsOneWidget);
      expect(find.text('ใช้ตัวกรอง'), findsOneWidget);
      // ยังไม่ได้เลือกอะไร ปุ่มล้างต้องกดไม่ได้
      final clear = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'ล้างทั้งหมด'),
      );
      expect(clear.onPressed, isNull);
    });

    testWidgets('เลือกในแผ่นแล้วกดใช้ ตัวกรองไปโผล่เป็นชิปใต้ช่องค้นหา', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('กรอง'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ใกล้หมดประกัน'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ใช้ตัวกรอง'));
      await tester.pumpAndSettle();

      // แผ่นปิดไปแล้ว เหลือชิปบอกว่ากรองอะไรอยู่ กับเลขบนปุ่ม
      expect(find.text('ใช้ตัวกรอง'), findsNothing);
      expect(find.widgetWithText(InputChip, 'ใกล้หมดประกัน'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('กดกากบาทบนชิปแล้วตัวกรองนั้นหายไป', (tester) async {
      await _open(tester);

      await tester.tap(find.text('กรอง'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ข้อมูลไม่ครบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ใช้ตัวกรอง'));
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
    });
  });
}
