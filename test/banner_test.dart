import 'dart:convert';

import 'package:claim/page/dashboard/banner_api.dart';
import 'package:claim/page/dashboard/banner_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ไฟล์ JSON จริงที่ raw.githubusercontent.com ตอบกลับมา
const String _bannerJson = '''
{
  "banners": [
    {
      "id": "b1",
      "image_url": "https://internal.thaiparcels.com:4433/Tps/Claim/linktest/d3009201-2979-4fde-8e51-4aacc094fb1e.png",
      "link": "null"
    },
    {
      "id": "b2",
      "image_url": "https://internal.thaiparcels.com:4433/Tps/Claim/linktest/64215ace-7618-4de9-8a85-cdd18d7d81a1.png",
      "link": ""
    }
  ]
}
''';

List<BannerItem> parseBanners(String source) {
  final decoded = jsonDecode(source) as Map<String, dynamic>;
  return (decoded['banners'] as List)
      .whereType<Map>()
      .map((e) => BannerItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

BannerItem banner(String id, {String? link}) =>
    BannerItem(id: id, imageUrl: 'https://example.com/$id.png', link: link);

Future<void> pumpCarousel(WidgetTester tester, List<BannerItem> items) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: BannerCarousel(banners: items)),
    ),
  );
  await tester.pump();
  // รูปโหลดไม่ได้ในเทสต์ errorBuilder รับไว้แล้ว ระบายที่เหลือทิ้ง
  tester.takeException();
}

void main() {
  group('แปลง banner.json', () {
    test('อ่าน id กับ image_url ได้ครบ', () {
      final banners = parseBanners(_bannerJson);

      expect(banners, hasLength(2));
      expect(banners.first.id, 'b1');
      expect(
        banners.first.imageUrl,
        'https://internal.thaiparcels.com:4433/Tps/Claim/linktest/'
        'd3009201-2979-4fde-8e51-4aacc094fb1e.png',
      );
    });

    test('link ที่เป็นสตริง "null" กับสตริงว่าง ถือว่าไม่มีลิงก์', () {
      final banners = parseBanners(_bannerJson);

      // ถ้าไม่กันไว้ แอปจะพยายามเปิด URL ชื่อ "null" ตอนกดแบนเนอร์
      expect(banners[0].link, isNull);
      expect(banners[1].link, isNull);
    });

    test('link ที่มีค่าจริงเก็บไว้', () {
      final item = BannerItem.fromJson({
        'id': 'b3',
        'image_url': 'https://example.com/a.png',
        'link': 'https://thaiparcels.com/promo',
      });

      expect(item.link, 'https://thaiparcels.com/promo');
    });
  });

  group('แบนเนอร์สไลด์', () {
    testWidgets('สองรูปขึ้นไปมีจุดบอกตำแหน่งเท่าจำนวนรูป', (tester) async {
      await pumpCarousel(tester, [banner('b1'), banner('b2'), banner('b3')]);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('รูปเดียวไม่ต้องมีจุด', (tester) async {
      await pumpCarousel(tester, [banner('b1')]);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('แบนเนอร์ที่ไม่มีลิงก์กดไม่ได้', (tester) async {
      await pumpCarousel(tester, [banner('b1')]);

      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('แบนเนอร์ที่มีลิงก์กดได้', (tester) async {
      await pumpCarousel(tester, [
        banner('b1', link: 'https://thaiparcels.com'),
      ]);

      expect(find.byType(GestureDetector), findsOneWidget);
    });
  });

  testWidgets('กรอบสำรองบอกสภาพได้ทั้งกำลังโหลดและโหลดไม่ได้', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BannerPlaceholder(loading: true))),
    );
    expect(find.text('กำลังโหลดแบนเนอร์...'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BannerPlaceholder(message: 'โหลดแบนเนอร์ไม่สำเร็จ'),
        ),
      ),
    );
    expect(find.text('โหลดแบนเนอร์ไม่สำเร็จ'), findsOneWidget);
  });
}
