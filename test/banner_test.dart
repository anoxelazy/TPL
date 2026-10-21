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
    testWidgets('ไม่มีตัวนับหรือจุดบอกตำแหน่งบนรูป', (tester) async {
      await pumpCarousel(tester, [banner('b1'), banner('b2'), banner('b3')]);

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('1/3'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('ใบที่โชว์อยู่กลางจอ เห็นขอบใบข้างเคียงชัดทั้งซ้ายขวาเท่ากัน', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpCarousel(tester, [banner('b1'), banner('b2'), banner('b3')]);
      await tester.pump();

      // รายการวนได้ทั้งสองทาง มีใบที่ซ่อนอยู่นอกจอซ้ายด้วย เลือกเฉพาะที่อยู่ในจอ
      final visible =
          find
              .byType(ClipRRect)
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget)))
              .where((r) => r.right > 0 && r.left < 400)
              .toList()
            ..sort((a, b) => a.left.compareTo(b.left));

      // ใบก่อนหน้า (โผล่ซ้าย) ใบที่โชว์ ใบถัดไป (โผล่ขวา)
      expect(visible, hasLength(3));
      final front = visible[1];
      expect(front.center.dx, 200, reason: 'ใบที่โชว์ต้องอยู่กลางจอ');
      expect(_frontId(tester), 'b1');

      final leftPeek = visible.first.right;
      final rightPeek = 400 - visible.last.left;
      expect(
        leftPeek,
        greaterThanOrEqualTo(16),
        reason: 'ต้องเห็นชัด ไม่ใช่เส้นบาง',
      );
      expect(leftPeek, rightPeek, reason: 'โผล่สองข้างเท่ากัน');
    });

    testWidgets('ปัดขวาเลยใบสุดท้าย วนต่อเป็นใบแรก ไม่ย้อนกลับ', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpCarousel(tester, [banner('b1'), banner('b2'), banner('b3')]);
      await tester.pump(); // กระโดดไปช่องเริ่มหลังเฟรมแรก

      final seen = <String>[_frontId(tester)];
      for (var i = 0; i < 3; i++) {
        await tester.fling(find.byType(ListView), const Offset(-300, 0), 1500);
        await tester.pumpAndSettle();
        tester.takeException();
        seen.add(_frontId(tester));
      }

      expect(seen, ['b1', 'b2', 'b3', 'b1']);
    });

    testWidgets('ค้างเยื้องไม่ตรงช่อง ดูดกลับเข้าแนวเดียวกับการ์ดอื่นเอง', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpCarousel(tester, [banner('b1'), banner('b2'), banner('b3')]);
      await tester.pump();

      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      // จำลองแอนิเมชันที่ถูกตัดกลางทางจนค้างเยื้อง 21 จุด แบบที่เจอบนเครื่องจริง
      controller.jumpTo(controller.offset + 21);
      await tester.pumpAndSettle();
      tester.takeException();

      expect(_frontId(tester), 'b1');
    });

    testWidgets('แตะค้างตอนรูปกำลังเลื่อนเอง ปล่อยแล้วยังเข้าที่', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpCarousel(tester, [banner('b1'), banner('b2'), banner('b3')]);
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 120)); // กลางทาง
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      // หลายเฟรม ให้แอนิเมชันดูดเข้าที่เล่นจนจบ (pump ครั้งเดียวได้แค่เฟรมแรก)
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      tester.takeException();

      expect(_frontId(tester), isNotEmpty, reason: 'ต้องมีใบที่ตรงแนวพอดี');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ปัดซ้ายจากใบแรก วนไปใบสุดท้ายได้', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpCarousel(tester, [banner('b1'), banner('b2'), banner('b3')]);
      await tester.pump();

      await tester.fling(find.byType(ListView), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      tester.takeException();

      expect(_frontId(tester), 'b3');
    });

    testWidgets('เลื่อนเองไปทางขวาเรื่อย ๆ ครบรอบแล้วต่อด้วยใบแรก', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpCarousel(tester, [banner('b1'), banner('b2'), banner('b3')]);
      await tester.pump();

      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      final seen = <String>[_frontId(tester)];
      var lastOffset = controller.offset;
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 500));
        tester.takeException();
        // ขยับไปทางขวาทุกครั้ง ไม่มีครั้งไหนวิ่งย้อนกลับทั้งแถว
        expect(controller.offset, greaterThan(lastOffset));
        lastOffset = controller.offset;
        seen.add(_frontId(tester));
      }

      expect(seen, ['b1', 'b2', 'b3', 'b1']);
      await tester.pumpWidget(const SizedBox());
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
}

/// id ของรูปที่อยู่กลางจอพอดี (ใบที่กำลังโชว์ จอเทสต์กว้าง 400)
String _frontId(WidgetTester tester) {
  for (final element in find.byType(Image).evaluate()) {
    final rect = tester.getRect(find.byWidget(element.widget));
    if ((rect.center.dx - 200).abs() < 1) {
      var provider = (element.widget as Image).image;
      if (provider is ResizeImage) provider = provider.imageProvider;
      final url = (provider as NetworkImage).url;
      return url.split('/').last.replaceAll('.png', '');
    }
  }
  return '';
}
