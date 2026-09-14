import 'package:claim/page/dashboard/dashboard_menu.dart';
import 'package:claim/page/dashboard/menu_search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardMenuItem menu(
  String label, {
  VoidCallback? onTap,
  bool locked = false,
  bool comingSoon = false,
}) => DashboardMenuItem(
  icon: Icons.circle,
  label: label,
  iconColor: Colors.green,
  iconBg: Colors.green,
  onTap: onTap,
  locked: locked,
  comingSoon: comingSoon,
);

Future<void> pumpSearch(
  WidgetTester tester,
  List<DashboardMenuItem> items, {
  ValueChanged<DashboardMenuItem>? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MenuSearchPage(items: items, onSelected: onSelected ?? (_) {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('กรองเมนู', () {
    final items = [
      menu('บันทึกสินค้าเสียหาย'),
      menu('สถานะคลังสินค้า LKB01'),
      menu('แผนของคุณ'),
    ];

    test('ค้นด้วยคำไทยบางส่วน', () {
      final found = filterDashboardMenu(items, 'คลัง');
      expect(found, hasLength(1));
      expect(found.first.label, 'สถานะคลังสินค้า LKB01');
    });

    test('ค้นด้วยอังกฤษไม่สนตัวพิมพ์', () {
      expect(filterDashboardMenu(items, 'lkb'), hasLength(1));
    });

    test('ไม่ตรงคืนลิสต์ว่าง', () {
      expect(filterDashboardMenu(items, 'ไม่มีเมนูนี้'), isEmpty);
    });
  });

  group('หน้าค้นหา', () {
    testWidgets('ยังไม่พิมพ์ต้องไม่ลิสต์เมนูออกมา', (tester) async {
      await pumpSearch(tester, [
        menu('บันทึกสินค้าเสียหาย'),
        menu('แผนของคุณ'),
      ]);

      expect(find.text('พิมพ์ชื่อเมนูที่ต้องการ'), findsOneWidget);
      expect(find.text('บันทึกสินค้าเสียหาย'), findsNothing);
      expect(find.text('แผนของคุณ'), findsNothing);
    });

    testWidgets('พิมพ์แล้วโชว์เฉพาะที่ตรง', (tester) async {
      await pumpSearch(tester, [
        menu('บันทึกสินค้าเสียหาย'),
        menu('แผนของคุณ'),
      ]);

      await tester.enterText(find.byType(TextField), 'แผน');
      await tester.pumpAndSettle();

      expect(find.text('แผนของคุณ'), findsOneWidget);
      expect(find.text('บันทึกสินค้าเสียหาย'), findsNothing);
    });

    testWidgets('ล้างคำค้นแล้วกลับไปสภาพยังไม่พิมพ์', (tester) async {
      await pumpSearch(tester, [menu('แผนของคุณ')]);

      await tester.enterText(find.byType(TextField), 'แผน');
      await tester.pumpAndSettle();
      expect(find.text('แผนของคุณ'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('พิมพ์ชื่อเมนูที่ต้องการ'), findsOneWidget);
      expect(find.text('แผนของคุณ'), findsNothing);
    });

    testWidgets('ค้นไม่เจอขึ้นข้อความบอก', (tester) async {
      await pumpSearch(tester, [menu('แผนของคุณ')]);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();

      expect(find.text('ไม่พบเมนูที่ค้นหา'), findsOneWidget);
    });

    testWidgets('เปิดหน้าค้นหาแบบเฟด ไม่ใช่โผล่ทันที', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MenuSearchPage.route(
                    items: [menu('แผนของคุณ')],
                    onSelected: (_) {},
                  ),
                ),
                child: const Text('เปิดค้นหา'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('เปิดค้นหา'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // เอา FadeTransition ที่ครอบหน้าค้นหาอยู่ (ของ route) ไม่ใช่ตัวใน
      // AnimatedSwitcher ที่อยู่ข้างในหน้า
      double routeOpacity() => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.byType(MenuSearchPage),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      // กลางทางต้องยังโปร่งอยู่ ถ้าไม่มี animation จะเป็น 1 ตั้งแต่เฟรมแรก
      expect(routeOpacity(), greaterThan(0));
      expect(routeOpacity(), lessThan(1));

      await tester.pumpAndSettle();
      expect(routeOpacity(), 1);
    });

    testWidgets('เนื้อหาเปลี่ยนสภาพด้วยการเฟดสลับ', (tester) async {
      await pumpSearch(tester, [menu('แผนของคุณ')]);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });

    testWidgets('กดผลค้นหาแล้วปิดหน้านี้ก่อนแล้วค่อยส่งต่อ', (tester) async {
      DashboardMenuItem? selected;
      final target = menu('แผนของคุณ', onTap: () {});

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MenuSearchPage(
                      items: [target],
                      onSelected: (item) => selected = item,
                    ),
                  ),
                ),
                child: const Text('เปิดค้นหา'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('เปิดค้นหา'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'แผน');
      await tester.pumpAndSettle();
      await tester.tap(find.text('แผนของคุณ'));
      await tester.pumpAndSettle();

      // หน้าค้นหาต้องถูกปิดแล้ว และเมนูที่เลือกส่งกลับมาถูกตัว
      expect(find.text('เปิดค้นหา'), findsOneWidget);
      expect(find.text('แผนของคุณ'), findsNothing);
      expect(selected?.label, 'แผนของคุณ');
    });
  });
}
