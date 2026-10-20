import 'package:claim/page/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpDashboard(
  WidgetTester tester,
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);

  // ในแอปจริงหน้านี้อยู่ใน Scaffold ของ HomePage ต้องมี Material ครอบ
  // ไม่งั้น TextField กับ InkWell จะ error
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: DashboardPage())),
  );
  await tester.pumpAndSettle();

  // รูป avatar โหลดไม่ได้เพราะเทสต์ไม่มี asset bundle ระบายทิ้งไป
  tester.takeException();
}

void main() {
  testWidgets('ทักทายด้วย fullname เป็นหลัก', (tester) async {
    await pumpDashboard(tester, {
      'flutter.fullname': 'พัฒนพงษ์ (IT) อุ่นทรัพย์',
      'flutter.username': 'lazy',
      'flutter.driverID': '68148',
    });

    expect(find.text('สวัสดีคุณ'), findsOneWidget);
    expect(find.text('พัฒนพงษ์ (IT) อุ่นทรัพย์'), findsOneWidget);
  });

  testWidgets('ช่องว่างซ้อนกันใน fullname ถูกยุบเหลือช่องเดียว', (
    tester,
  ) async {
    // ค่าจริงที่ API ส่งมามีช่องว่างสองตัวคั่นกลาง
    await pumpDashboard(tester, {'flutter.fullname': 'ลาดกระบัง  ลาดกระบัง'});

    expect(find.text('ลาดกระบัง ลาดกระบัง'), findsOneWidget);
  });

  testWidgets('ไม่มี fullname ถอยไปใช้ username', (tester) async {
    await pumpDashboard(tester, {
      'flutter.username': 'lazy',
      'flutter.driverID': '68148',
    });

    expect(find.text('lazy'), findsOneWidget);
  });

  testWidgets('ไม่มีทั้ง fullname และ username ถอยไปใช้ driverID', (
    tester,
  ) async {
    await pumpDashboard(tester, {'flutter.driverID': '10164008'});

    expect(find.text('10164008'), findsOneWidget);
  });

  testWidgets('ไม่มีข้อมูลเลยขึ้นขีด', (tester) async {
    await pumpDashboard(tester, {});

    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('เลื่อนหน้าลงไปแล้วแถบทักทายยังค้างอยู่บนสุด', (tester) async {
    // จอเทสต์ตั้งต้นสูงกว่าเนื้อหาที่หน้านี้มีตอนไม่มีแบนเนอร์กับเคสค้าง
    // ย่อจอให้เตี้ยลงก่อน ไม่งั้นลากเท่าไรก็ไม่มีอะไรให้เลื่อน
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpDashboard(tester, {'flutter.fullname': 'ลาดกระบัง'});

    final before = tester.getTopLeft(find.text('ลาดกระบัง'));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();

    // กันเทสต์หลอกตัวเอง: ถ้าเนื้อหาสั้นกว่าจอจนลากแล้วไม่ขยับ ข้อสรุปข้างล่าง
    // ก็ไม่ได้พิสูจน์อะไร
    final scrolled = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(scrolled.pixels, greaterThan(0));

    // ยังอยู่ และอยู่ที่เดิม ไม่ได้เลื่อนตามเนื้อหาขึ้นไป
    expect(find.text('ลาดกระบัง'), findsOneWidget);
    expect(tester.getTopLeft(find.text('ลาดกระบัง')), before);
  });
}
