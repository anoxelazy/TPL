import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/transfer_list_page.dart';
import 'package:claim/page/dashboard/asset_transfer_banner.dart';
import 'package:claim/page/dashboard/dashboard_banner.dart';
import 'package:claim/page/dashboard/dashboard_menu.dart';
import 'package:claim/page/dashboard/it_case_banner.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';

/// วางแถบไว้ในกรอบกว้างเท่าหน้าหลักจริง (จอ 400 ลบขอบซ้ายขวา 16)
Future<void> pumpBanner(WidgetTester tester, {bool dark = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.getDarkTheme() : AppTheme.getLightTheme(),
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AssetTransferBanner(),
        ),
      ),
    ),
  );
  // แถบนับใบที่รออยู่ตอนเปิด ไม่มี token ก็ล้มทันทีโดยไม่ออกเน็ต
  await tester.pump();
}

void main() {
  group('แถบใบโอนย้าย', () {
    testWidgets('กว้างเต็มแถวเท่าแถบแจ้งเคส ไม่ใช่ช่องเล็กแบบในตาราง', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpBanner(tester);
      final banner = tester.getSize(find.byType(AssetTransferBanner));

      expect(banner.width, 400 - 32);
      expect(
        banner.width / banner.height,
        greaterThan(3),
        reason: 'ต้องเป็นแถวยาว ไม่ใช่ช่องจตุรัสแบบปุ่มในตาราง',
      );

      // สูงเท่าแถบแจ้งเคสเป๊ะ สองแถบวางติดกัน สูงไม่เท่ากันจะเห็นทันที
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getLightTheme(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ItCaseBanner(),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ItCaseBanner)).height, banner.height);
    });

    testWidgets('บอกได้ว่าเป็นอะไรและกดแล้วไปไหน', (tester) async {
      await pumpBanner(tester);

      expect(find.text('ใบโอนย้าย'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsDuotone.arrowsLeftRight), findsOneWidget);
      expect(
        find.byIcon(Icons.chevron_right_rounded),
        findsOneWidget,
        reason: 'ต้องมีลูกศรบอกว่ากดได้ ไม่ใช่ป้ายประกาศเฉย ๆ',
      );
    });

    testWidgets('กดแล้วเข้าหน้าใบโอนย้ายเลย ไม่ใช่หน้าค้นทะเบียน', (
      tester,
    ) async {
      // ของเดิมชื่อ "โอนย้ายทรัพย์สิน" แต่ลงที่หน้าค้นทะเบียน แล้วใบจริงซ่อน
      // อยู่ในเมนูสามจุดอีกชั้น ต้องกดสามทีกว่าจะถึงสิ่งที่ชื่อแถบสัญญาไว้
      await pumpBanner(tester);

      await tester.tap(find.byType(AssetTransferBanner));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TransferListPage), findsOneWidget);
    });

    testWidgets('ไม่มีงานค้างก็ไม่ต้องมีตัวเลขมากินที่', (tester) async {
      await pumpBanner(tester);

      final banner = tester.widget<DashboardBanner>(
        find.byType(DashboardBanner),
      );
      expect(banner.badgeCount, 0);
      expect(
        find.text('ขอย้ายทรัพย์สิน อนุมัติ ส่งออก รับเข้า'),
        findsOneWidget,
      );
    });

    testWidgets('วาดได้ทั้งธีมสว่างและมืด ไม่มี overflow', (tester) async {
      await pumpBanner(tester);
      expect(tester.takeException(), isNull);

      await pumpBanner(tester, dark: true);
      expect(tester.takeException(), isNull);
    });
  });

  group('ตัวเลขงานค้างบนแถบ', () {
    Future<void> pumpWithBadge(WidgetTester tester, int count) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getLightTheme(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DashboardBanner(
                  icon: Icons.swap_horiz,
                  color: AppColors.assetIcon,
                  background: AppColors.assetBg,
                  title: 'ใบโอนย้าย',
                  subtitle: 'มีงานรออยู่',
                  badgeCount: count,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

    testWidgets('มีงานค้างต้องเห็นตัวเลขตั้งแต่หน้าแรก', (tester) async {
      await pumpWithBadge(tester, 5);

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('0 ไม่ต้องวาดอะไรเลย', (tester) async {
      await pumpWithBadge(tester, 0);

      expect(find.text('0'), findsNothing);
    });

    testWidgets('เกิน 99 ย่อเป็น 99+ ไม่ให้เลขสามหลักดันแถบเบี้ยว', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpWithBadge(tester, 128);

      expect(find.text('99+'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ตารางเมนู', () {
    testWidgets('ทะเบียนทรัพย์สินอยู่ในตาราง ส่วนใบโอนย้ายอยู่บนแถบ', (
      tester,
    ) async {
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

      // คนละเรื่องกัน: ทะเบียนคือค้นว่าของอยู่ไหน เปิดดูเมื่อไหร่ก็ได้
      // ส่วนใบโอนย้ายมีคนปลายทางรอรับ จึงต้องเด่นกว่าและมีตัวเลขบอก
      expect(items.where((e) => e.label == 'โอนทรัพย์สิน'), hasLength(1));
      expect(
        items.where((e) => e.label.contains('โอนย้าย')),
        isEmpty,
        reason: 'ใบโอนย้ายอยู่บนแถบแล้ว อยู่สองที่จะงงว่ากดอันไหน',
      );
      expect(
        items.where((e) => e.label == 'แจ้งซ่อม'),
        hasLength(1),
        reason: 'เมนูอื่นในตารางต้องไม่หายไปด้วย',
      );
    });
  });
}
