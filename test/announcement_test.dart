import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/announcement_service.dart';

/// ประกาศ 1 ก้อนแบบข้อความ ใส่ image ไม่ได้เพราะเทสต์โหลดรูปจากเน็ตไม่ได้
Map<String, dynamic> item(String id, {String title = 'ประกาศทดสอบ'}) => {
  'id': id,
  'title': title,
  'message': 'เนื้อหาประกาศ $id',
};

/// ตั้งค่าเครื่องก่อนเปิดแอป
///
/// ในเทสต์ยิงเน็ตไม่ได้ ตัวโหลดจะ throw แล้วตกไปอ่านก้อนที่ cache ไว้
/// ซึ่งเป็นเส้นทางเดียวกับตอนผู้ใช้เปิดแอปแบบเน็ตไม่ดี
void seed({
  required bool loggedIn,
  List<Map<String, dynamic>> announcements = const [],
  List<String> dismissed = const [],
  String empId = '80770',
}) {
  SharedPreferences.setMockInitialValues({
    if (loggedIn) 'token': 'token-ของจริง',
    if (loggedIn) 'driverID': empId,
    'announcement_json': jsonEncode({'announcements': announcements}),
    if (dismissed.isNotEmpty) 'announcement_dismissed_$empId': dismissed,
  });
  AnnouncementService.I.forgetCurrentUser();
}

/// จำลองการเปิดแอป 1 รอบ แล้วบอกว่าประกาศเด้งไหม
///
/// ห้าม await ตัว showIfAny ตรง ๆ เพราะมันค้างรอจนกว่าผู้ใช้จะปิด dialog
/// ซึ่งจะเกิดขึ้นได้ก็ต่อเมื่อ pump ให้ dialog วาดขึ้นมาก่อน
Future<bool> openApp(WidgetTester tester) async {
  late BuildContext ctx;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          ctx = context;
          return const Scaffold(body: Text('หน้าหลัก'));
        },
      ),
    ),
  );

  unawaited(AnnouncementService.I.showIfAny(ctx));

  // showIfAny มี await หลายชั้นกว่าจะถึงตอนเปิด dialog (อ่าน prefs, โหลด json,
  // ถามเวอร์ชันแอป) ยังไม่มีเฟรมไหนถูกจอง pumpAndSettle เลยจบตั้งแต่รอบแรก
  // ต้องหมุน event loop ให้ future พวกนั้นเสร็จก่อน
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();

  return find.byType(AlertDialog).evaluate().isNotEmpty;
}

/// กดปุ่มในประกาศแล้วรอให้ที่ต้องจำถูกเขียนลงเครื่องเรียบร้อย
Future<void> tapInDialog(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.pump();
}

Future<List<String>> dismissedOf(String empId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('announcement_dismissed_$empId') ?? const [];
}

void main() {
  setUpAll(() {
    // ไม่มีปลั๊กอินจริงในเทสต์ ตัวอ่านเวอร์ชันจะค้างรอ method channel
    // ยัดค่าให้ตั้งแต่แรก เงื่อนไข min_version จะได้เทียบกับของจริงได้ด้วย
    PackageInfo.setMockInitialValues(
      appName: 'TPL',
      packageName: 'com.tpl.claim',
      version: '2.1.16',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(AnnouncementService.I.forgetCurrentUser);

  group('ยังไม่ล็อกอิน', () {
    testWidgets('เปิดแอปมาที่หน้า login ประกาศต้องไม่เด้ง', (tester) async {
      seed(loggedIn: false, announcements: [item('a1')]);

      expect(await openApp(tester), isFalse);
    });

    testWidgets('มี driverID ค้างอยู่แต่ token หลุด ก็ยังไม่เด้ง', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'driverID': '80770',
        'announcement_json': jsonEncode({
          'announcements': [item('a1')],
        }),
      });
      AnnouncementService.I.forgetCurrentUser();

      expect(await openApp(tester), isFalse);
    });

    testWidgets('ล็อกอินแล้วเด้งตามปกติ', (tester) async {
      seed(loggedIn: true, announcements: [item('a1')]);

      expect(await openApp(tester), isTrue);
      expect(find.text('เนื้อหาประกาศ a1'), findsOneWidget);
    });
  });

  group('เคส 1 กดปิดเฉย ๆ', () {
    testWidgets('รอบหน้าเจอประกาศเดิมอีก', (tester) async {
      seed(loggedIn: true, announcements: [item('a1')]);

      expect(await openApp(tester), isTrue);
      await tapInDialog(tester, 'ปิด');
      expect(find.byType(AlertDialog), findsNothing);

      // กดปิดแล้วต้องไม่ถูกจดไว้ ไม่งั้นรอบหน้าจะหายไปด้วย
      expect(await dismissedOf('80770'), isEmpty);

      // เปิดแอปรอบใหม่ ของที่จำไว้ในรอบก่อนถูกล้าง
      AnnouncementService.I.forgetCurrentUser();
      expect(await openApp(tester), isTrue);
    });

    testWidgets('รอบเดียวกันไม่เด้งซ้ำ', (tester) async {
      seed(loggedIn: true, announcements: [item('a1')]);

      expect(await openApp(tester), isTrue);
      await tapInDialog(tester, 'ปิด');

      // ยังอยู่ในรอบเดิม เช่น สลับกลับเข้าแอป ต้องไม่เด้งใหม่
      expect(await openApp(tester), isFalse);
    });
  });

  group('เคส 2 กดไม่แสดงอีก', () {
    testWidgets('หายไปเลย เปิดแอปกี่รอบก็ไม่เจอ', (tester) async {
      seed(loggedIn: true, announcements: [item('a1')]);

      expect(await openApp(tester), isTrue);
      await tapInDialog(tester, 'ไม่แสดงอีก');

      expect(await dismissedOf('80770'), ['a1']);

      AnnouncementService.I.forgetCurrentUser();
      expect(await openApp(tester), isFalse, reason: 'รอบต่อไปต้องไม่เจอแล้ว');
    });

    testWidgets('แก้ id ใหม่ที่ git แล้วกลับมาเด้งอีก', (tester) async {
      seed(
        loggedIn: true,
        announcements: [
          item('a1', title: 'ของเก่า'),
          item('a2'),
        ],
        dismissed: const ['a1'],
      );

      expect(await openApp(tester), isTrue);
      expect(find.text('เนื้อหาประกาศ a2'), findsOneWidget);
      expect(
        find.text('เนื้อหาประกาศ a1'),
        findsNothing,
        reason: 'ตัวที่ปิดไปแล้วต้องไม่กลับมา',
      );
    });

    testWidgets('จำแยกตามรหัสพนักงาน คนอื่นยังเห็น', (tester) async {
      seed(
        loggedIn: true,
        announcements: [item('a1')],
        dismissed: const ['a1'],
        empId: '80770',
      );
      expect(await openApp(tester), isFalse);

      seed(loggedIn: true, announcements: [item('a1')], empId: '66293');
      expect(await openApp(tester), isTrue);
    });
  });

  group('เงื่อนไขอื่นของ json', () {
    testWidgets('active เป็น false ไม่เด้ง', (tester) async {
      seed(
        loggedIn: true,
        announcements: [
          {...item('a1'), 'active': false},
        ],
      );

      expect(await openApp(tester), isFalse);
    });

    testWidgets('หมดอายุแล้วไม่เด้ง', (tester) async {
      seed(
        loggedIn: true,
        announcements: [
          {...item('a1'), 'show_until': '2020-01-01'},
        ],
      );

      expect(await openApp(tester), isFalse);
    });

    testWidgets('ไม่มี id ข้ามไป เพราะจำว่าปิดไปแล้วไม่ได้', (tester) async {
      seed(
        loggedIn: true,
        announcements: [
          {...item(''), 'id': ''},
        ],
      );

      expect(await openApp(tester), isFalse);
    });

    testWidgets('มีหลายก้อน เอาอันล่างสุดที่ผ่านเงื่อนไข', (tester) async {
      seed(loggedIn: true, announcements: [item('a1'), item('a2'), item('a3')]);

      expect(await openApp(tester), isTrue);
      expect(find.text('เนื้อหาประกาศ a3'), findsOneWidget);
    });
  });
}
