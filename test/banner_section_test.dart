import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/banner_api.dart';
import 'package:claim/page/dashboard/banner_carousel.dart';

/// หัวข้อพับได้ของแบนเนอร์บนหน้าหลัก
void main() {
  const banners = [
    BannerItem(id: '1', imageUrl: 'https://example.com/a.png'),
    BannerItem(id: '2', imageUrl: 'https://example.com/b.png'),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required bool expanded,
    VoidCallback? onToggle,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerSection(
            banners: banners,
            expanded: expanded,
            onToggle: onToggle ?? () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // รูปโหลดจากเน็ตไม่ได้ในเทสต์ ระบายทิ้งไป
    tester.takeException();
  }

  testWidgets('พับอยู่ ไม่มีสไลด์ แต่ยังมีหัวข้อให้กดกางกลับ', (tester) async {
    await pump(tester, expanded: false);

    expect(find.text('ประชาสัมพันธ์'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    // ตัวสไลด์ต้องถูกถอดออกจริง ไม่ใช่แค่ซ่อน ไม่งั้น Timer เลื่อนรูปยังเดินอยู่
    expect(find.byType(BannerCarousel), findsNothing);
  });

  testWidgets('กางอยู่ เห็นสไลด์แบบการ์ดเลื่อน', (tester) async {
    await pump(tester, expanded: true);

    expect(find.byType(BannerCarousel), findsOneWidget);
    expect(find.text('ประชาสัมพันธ์'), findsOneWidget);
  });

  testWidgets('กดที่หัวข้อแล้วสั่งพับ/กาง', (tester) async {
    var taps = 0;
    await pump(tester, expanded: true, onToggle: () => taps++);

    await tester.tap(find.text('ประชาสัมพันธ์'));
    await tester.pump();

    expect(taps, 1);
  });
}
