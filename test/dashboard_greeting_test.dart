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
}
