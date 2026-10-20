import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/dashboard_menu.dart';
import 'package:claim/page/dashboard/dashboard_page.dart';
import 'package:claim/utils/app_colors.dart';

/// เมนูปลอมไว้ทดสอบการแยกกอง
///
/// [tappable] = false คือเมนูที่ยังไม่เปิดใช้งาน ของจริงตัวนี้ไม่ได้ใส่ onTap ไว้
/// (comingSoon อย่างเดียวไม่ได้ทำให้กดไม่ได้ ตัวที่ตัดสินคือ onTap เป็น null)
DashboardMenuItem _item(
  String label, {
  bool locked = false,
  bool comingSoon = false,
  bool tappable = true,
}) => DashboardMenuItem(
  icon: Icons.circle,
  label: label,
  iconColor: AppColors.claimIcon,
  iconBg: AppColors.claimBg,
  locked: locked,
  comingSoon: comingSoon,
  onTap: tappable ? () {} : null,
);

void main() {
  group('แยกเมนูที่กดได้กับกดไม่ได้', () {
    test('เมนูที่ล็อกกับที่ยังไม่เปิด ไม่อยู่ในตารางหลัก', () {
      final items = [
        _item('กดได้'),
        _item('ไม่มีสิทธิ์', locked: true),
        _item('ยังไม่เปิด', comingSoon: true, tappable: false),
      ];

      expect(unlockedMenu(items).map((e) => e.label), ['กดได้']);
      expect(lockedMenu(items).map((e) => e.label), [
        'ไม่มีสิทธิ์',
        'ยังไม่เปิด',
      ]);
    });

    test('สองกองรวมกันแล้วต้องครบเท่าเดิม ไม่มีเมนูหาย', () {
      final items = [
        _item('a'),
        _item('b', locked: true),
        _item('c'),
        _item('d', locked: true),
      ];

      expect(
        unlockedMenu(items).length + lockedMenu(items).length,
        items.length,
      );
    });

    test('มีสิทธิ์ครบ กองที่ล็อกต้องว่าง', () {
      final items = [_item('a'), _item('b')];

      expect(lockedMenu(items), isEmpty);
      expect(unlockedMenu(items), hasLength(2));
    });
  });

  group('แถวพับเก็บบนหน้าหลัก', () {
    testWidgets('มีแถวให้กด แต่ยังไม่เห็นตัวเมนู และไม่ทวงเรื่องสิทธิ์', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DashboardPage())),
      );
      await tester.pump();

      // ในเทสต์ไม่มีสิทธิ์ module ไหนเลย เมนูที่ล็อกจึงต้องถูกพับไว้
      expect(find.text('เมนูอื่น ๆ'), findsOneWidget);
      expect(find.text('คลังสินค้า -'), findsNothing);
      // ไม่ทวงกับผู้ใช้ทุกครั้งที่เปิดแอปว่าเขาใช้อะไรไม่ได้บ้าง
      expect(find.textContaining('ไม่มีสิทธิ์'), findsNothing);
    });

    testWidgets('กดแถวแล้วเมนูที่ล็อกกางออกมา', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DashboardPage())),
      );
      await tester.pump();

      await tester.tap(find.text('เมนูอื่น ๆ'));
      await tester.pumpAndSettle();

      expect(find.text('คลังสินค้า -'), findsOneWidget);
    });
  });
}
