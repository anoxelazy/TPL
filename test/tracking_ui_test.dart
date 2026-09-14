import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:claim/page/tracking/api.dart';
import 'package:claim/page/tracking/models.dart';
import 'package:claim/page/tracking/tracking_cache.dart';
import 'package:claim/page/tracking/tracking_screen.dart';
import 'package:claim/page/tracking/tracking_timeline.dart';
import 'package:claim/utils/app_icons.dart';
import 'package:claim/widgets/remote_image.dart';

/// ผลจริงจาก tracking.aspx ที่เก็บไว้เป็น fixture
TrackingResult _realResult() => decodeTrackingBody(
  File('test/fixtures/tracking_delivered.json').readAsStringSync(),
);

/// PNG 1x1 โปร่งใส ใช้เป็นรูปทดสอบ
///
/// ต้องเป็น data URI ไม่ใช่ URL จริง เพราะใน widget test ทุก request
/// ถูกตอบ 400 ให้หมด รูปจะขึ้นไอคอนรูปแตกแล้วเทสต์จะวัดอะไรไม่ได้
const String _png1x1 =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';

void main() {
  setUpAll(() => initializeDateFormatting('th', null));

  // แคชเป็น singleton ระดับแอป ถ้าไม่ล้าง เทสต์ตัวก่อนจะทิ้งผลค้างให้ตัวถัดไป
  setUp(() => TrackingCache.I.clear());

  group('ตัวดูรูปแบบเลื่อน', () {
    /// เปิด gallery ขึ้นมาตรง ๆ โดยไม่ต้องผ่านหน้าเช็คสถานะ
    Future<void> openGallery(
      WidgetTester tester, {
      required int initialIndex,
      int count = 3,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFullScreenGallery(
                context,
                sources: List.filled(count, _png1x1),
                initialIndex: initialIndex,
                title: 'หลักฐานการส่ง',
              ),
              child: const Text('เปิด'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
    }

    testWidgets('เปิดที่รูปที่แตะ ไม่ใช่รูปแรกเสมอ', (tester) async {
      await openGallery(tester, initialIndex: 1);

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('หลักฐานการส่ง'), findsOneWidget);
    });

    testWidgets('ปัดซ้ายไปรูปถัดไป ปัดขวากลับรูปก่อนหน้า', (tester) async {
      await openGallery(tester, initialIndex: 0);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('รูปเดียวไม่ต้องขึ้นตัวนับ', (tester) async {
      await openGallery(tester, initialIndex: 0, count: 1);

      expect(find.text('1 / 1'), findsNothing);
    });

    testWidgets('index เกินขอบถูกดึงกลับให้อยู่ในช่วง ไม่ crash', (
      tester,
    ) async {
      await openGallery(tester, initialIndex: 99);

      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('กดปิดแล้วออกจากหน้าดูรูป', (tester) async {
      await openGallery(tester, initialIndex: 0);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
    });
  });

  group('แถบไทม์ไลน์แนวนอน', () {
    Future<void> pumpTimeline(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackingTimeline(events: _realResult().events)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('เรียงซ้าย→ขวา เก่า→ใหม่ สลับทิศจากที่เก็บในโมเดล', (
      tester,
    ) async {
      await pumpTimeline(tester);

      final steps = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      // B00 เป็นเหตุการณ์แรกสุด ต้องอยู่ก่อน "ส่งสินค้าถึงปลายทาง" ในลำดับวาด
      final b00 = steps.indexWhere((s) => s.contains('รับข้อมูล Api'));
      final delivered = steps.indexWhere((s) => s.contains('ถึงปลายทาง'));
      expect(b00, isNonNegative);
      expect(delivered, isNonNegative);
      expect(b00, lessThan(delivered));
    });

    testWidgets('เริ่มที่สถานะล่าสุด การ์ดล่างโชว์รายละเอียดของใบที่ส่งถึง', (
      tester,
    ) async {
      await pumpTimeline(tester);

      // สถานะ 7 มีรูป 3 ใบ + ลายเซ็น = 4 thumbnail
      expect(find.byType(RemoteImage), findsNWidgets(4));
      // remark ของสถานะ 7 ในข้อมูลจริง
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('13.1678771, 101.0013249'), findsOneWidget);
    });

    testWidgets('แตะช่องอื่นแล้วรายละเอียดเปลี่ยนตาม', (tester) async {
      await pumpTimeline(tester);

      // สถานะ 6 มีคนขับ ยังไม่โชว์ตอนเลือกสถานะ 7 อยู่
      expect(find.text('ปวิช ทองท่อ (095-1058256)'), findsNothing);

      await tester.tap(
        find.textContaining('ดำเนินการส่งสินค้าไปให้ลูกค้า').first,
      );
      await tester.pumpAndSettle();

      expect(find.text('ปวิช ทองท่อ (095-1058256)'), findsOneWidget);
      // สถานะ 6 ไม่มีรูป การ์ดต้องไม่ค้างรูปของสถานะก่อนหน้า
      expect(find.byType(RemoteImage), findsNothing);
    });

    testWidgets('ช่องที่มีรูปติดไอคอนบอกไว้', (tester) async {
      await pumpTimeline(tester);

      // มีแค่สถานะ 7 ที่มีรูปในข้อมูลชุดนี้
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });

    testWidgets('แถบเลื่อนแนวนอนได้', (tester) async {
      await pumpTimeline(tester);

      final scroller = find.byType(SingleChildScrollView);
      expect(scroller, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(scroller).scrollDirection,
        Axis.horizontal,
      );
    });
  });

  group('หน้าเช็คสถานะ', () {
    testWidgets('แตะที่ว่างแล้วคีย์บอร์ดถูกลด', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));

      // วัดจาก testTextInput ตรง ๆ ว่าคีย์บอร์ดขึ้นอยู่หรือไม่
      // เช็ค primaryFocus ไม่ได้ เพราะหลัง unfocus() โฟกัสจะเลื่อนไปที่
      // FocusScope ที่ครอบอยู่ ซึ่งก็นับว่า hasPrimaryFocus เหมือนกัน
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      // แตะที่ข้อความชวนกรอกกลางจอ ซึ่งเป็นที่ว่างไม่มีปุ่มอะไรทับ
      await tester.tap(find.text('กรอกเลขเอกสารเพื่อเช็คสถานะ'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('ช่องกรอกแปลงเป็นตัวพิมพ์ใหญ่และตัดช่องว่าง', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));

      // เคสนี้เคยทำให้ assert ตาย เพราะข้อความสั้นลงแต่เคอร์เซอร์ยังชี้ที่เดิม
      await tester.enterText(find.byType(TextField), 'hvr 0126 0909');
      await tester.pump();

      expect(find.text('HVR01260909'), findsOneWidget);
    });

    testWidgets('ไม่มีช่องเบอร์โทรแล้ว เหลือช่องกรอกเดียว', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('ไอคอนหน้าช่องเป็นปุ่มสแกน กดได้', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));

      final scanButton = find.ancestor(
        of: find.byIcon(AppIcons.scan),
        matching: find.byType(IconButton),
      );
      expect(scanButton, findsOneWidget);
      expect(tester.widget<IconButton>(scanButton).onPressed, isNotNull);
    });

    testWidgets('ไม่มีของค้าง เปิดมาเจอหน้าชวนกรอก', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));

      expect(find.text('กรอกเลขเอกสารเพื่อเช็คสถานะ'), findsOneWidget);
    });

    testWidgets('มีของค้าง เปิดมาเห็นผลเดิมทันที ไม่ต้องค้นซ้ำ', (
      tester,
    ) async {
      TrackingCache.I.save(code: 'HVR012609093457', result: _realResult());

      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));
      await tester.pump();

      // ไม่ขึ้นวงหมุน ไม่ขึ้นหน้าชวนกรอก โผล่มาเป็นผลลัพธ์เลย
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('กรอกเลขเอกสารเพื่อเช็คสถานะ'), findsNothing);
      expect(find.text('Delivered'), findsOneWidget);

      // เลขที่ค้นไว้กลับมาอยู่ในช่องกรอกด้วย เช็คที่ controller ตรง ๆ
      // เพราะ find.text จะไปเจอเลขเดียวกันในการ์ดสรุปด้วย
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'HVR012609093457');
    });

    testWidgets('บอกเวลาที่ดึงข้อมูลมา ไม่ให้เข้าใจผิดว่าเป็นของสด', (
      tester,
    ) async {
      TrackingCache.I.save(code: 'HVR012609093457', result: _realResult());

      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));
      await tester.pump();

      expect(find.textContaining('ข้อมูลเมื่อ'), findsOneWidget);
    });

    testWidgets('ดึงใหม่เบื้องหลังไม่สำเร็จ ต้องคงของเดิมไว้ ไม่เด้ง error', (
      tester,
    ) async {
      TrackingCache.I.save(code: 'HVR012609093457', result: _realResult());

      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));
      // ใน widget test ทุก request ถูกตอบ 400 การดึงเบื้องหลังจึงล้มแน่นอน
      await tester.pumpAndSettle(const Duration(seconds: 20));

      expect(find.text('Delivered'), findsOneWidget);
      expect(find.textContaining('เช็คสถานะไม่สำเร็จ'), findsNothing);
      expect(find.text('ลองใหม่'), findsNothing);
    });

    testWidgets('กดค้นหาโดยไม่กรอกอะไร ต้องเตือน ไม่ยิง API', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrackingPage()));

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('กรุณากรอกเลขเอกสาร'), findsOneWidget);
    });
  });
}
