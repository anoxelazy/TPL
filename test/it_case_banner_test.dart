import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/dashboard_menu.dart';
import 'package:claim/page/dashboard/it_case_banner.dart';
import 'package:claim/page/itcase/itcase_form_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';

/// วางแถบไว้ในกรอบกว้างเท่าหน้าหลักจริง (จอ 400 ลบขอบซ้ายขวา 16)
Future<void> pumpBanner(WidgetTester tester, {bool dark = false}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.getDarkTheme() : AppTheme.getLightTheme(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ItCaseBanner(),
          ),
        ),
      ),
    );

void main() {
  group('แถบแจ้งเคส', () {
    testWidgets('กว้างเต็มแถว ไม่ใช่ช่องสี่เหลี่ยมเล็กแบบในตาราง', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpBanner(tester);
      final box = tester.getSize(find.byType(ItCaseBanner));

      expect(box.width, 400 - 32, reason: 'เต็มความกว้างที่เหลือจากขอบหน้า');
      expect(
        box.width / box.height,
        greaterThan(3),
        reason: 'ต้องเป็นแถวยาว ไม่ใช่ช่องจตุรัสแบบปุ่มในตาราง',
      );
    });

    testWidgets('บอกได้ว่าเป็นอะไรและกดแล้วไปไหน', (tester) async {
      await pumpBanner(tester);

      expect(find.text('แจ้งเคสถึงทีม IT'), findsOneWidget);
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
      expect(
        find.byIcon(Icons.arrow_forward),
        findsOneWidget,
        reason: 'ต้องมีลูกศรบอกว่ากดได้ ไม่ใช่ป้ายประกาศเฉย ๆ',
      );
    });

    testWidgets('กดแล้วเข้าหน้าแจ้งเคส', (tester) async {
      await pumpBanner(tester);

      await tester.tap(find.byType(ItCaseBanner));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ItCaseFormPage), findsOneWidget);
    });

    testWidgets('วาดได้ทั้งธีมสว่างและมืด ไม่มี overflow', (tester) async {
      await pumpBanner(tester);
      expect(tester.takeException(), isNull);

      await pumpBanner(tester, dark: true);
      expect(tester.takeException(), isNull);
    });
  });

  group('ตารางเมนู', () {
    testWidgets('ไม่มีแจ้งเคสซ้ำอยู่ในตารางแล้ว', (tester) async {
      late List<DashboardMenuItem> items;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              items = buildDashboardMenu(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        items.where((e) => e.label.contains('แจ้งเคส')),
        isEmpty,
        reason: 'ย้ายออกมาเป็นแถวแยกแล้ว อยู่สองที่จะงงว่ากดอันไหน',
      );
      expect(
        items.where((e) => e.label == 'แจ้งซ่อม'),
        hasLength(1),
        reason: 'แจ้งซ่อมเป็นคนละเมนู ต้องยังอยู่ในตาราง',
      );
    });
  });

  test('สีของแจ้งเคสไม่ซ้ำกับเมนูอื่น', () {
    // แยกเมนูออกมาแล้วแต่ใช้สีซ้ำกับตัวอื่น สายตาจะยังจับคู่ผิด
    const others = [
      AppColors.repairIcon,
      AppColors.claimIcon,
      AppColors.stockIcon,
      AppColors.planIcon,
      AppColors.pmIcon,
      AppColors.assetIcon,
      AppColors.meterIcon,
      AppColors.scanIcon,
      AppColors.trackingIcon,
    ];

    expect(others.contains(AppColors.caseIcon), isFalse);
  });
}
