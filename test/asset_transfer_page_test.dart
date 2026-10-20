import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_picker.dart';
import 'package:claim/page/asset/asset_transfer_page.dart';
import 'package:claim/utils/mobile_api.dart';

const _asset = Asset(
  id: 'F800-6703-0001',
  name: 'โน้ตบุ๊ก ASUS',
  siteId: 'HQ',
  custodian: '68051',
);

/// ปุ่มบันทึกการแก้ไข
///
/// หาด้วย predicate ไม่ใช่ byType เพราะ FilledButton.icon สร้างคลาสลูกออกมา
/// ซึ่ง byType ที่เทียบชนิดแบบตรงตัวจะหาไม่เจอ
FilledButton _confirmButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byWidgetPredicate((widget) => widget is FilledButton),
);

Future<void> _open(WidgetTester tester) async {
  // จอสูงพอให้ทั้งฟอร์มกับปุ่มยืนยันถูกวาดพร้อมกัน จอ 600 ของ default
  // ปุ่มจะยังไม่ถูกสร้างเพราะอยู่นอกพื้นที่ที่ ListView วาด
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    const MaterialApp(home: AssetTransferPage(asset: _asset)),
  );
  // รอบแรกวาดหน้า รอบสองรับผลของการหาชื่อจากรหัสที่ล้มไปแล้ว (ไม่มี token)
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    // ปุ่มลัด "ฉันถือไว้เอง" อ่านรหัสพนักงานจากตรงนี้ ไม่ตั้งไว้ปุ่มจะไม่ขึ้น
    // แล้วเทสต์จะไม่มีทางเปลี่ยนค่าเลย เพราะทั้งสองช่องเป็นช่องเลือกไม่ใช่ช่องพิมพ์
    //
    // ปุ่ม "แผนกฉัน" ทดสอบตรงนี้ไม่ได้ เพราะแผนกมาจาก `/me` เท่านั้นซึ่งต้องมี
    // token — ต่างจากรหัสพนักงานที่อ่านจาก SharedPreferences ได้
    //
    // ตั้งใจไม่ใส่ token: ไม่มี token แปลว่าทุกการยิง API ตายตั้งแต่ก่อนออกเน็ต
    // เทสต์จึงไม่แตะเซิร์ฟเวอร์จริง
    SharedPreferences.setMockInitialValues({'mobile_api_emp_no': '68148'});
    await MobileSession.I.init();
  });

  testWidgets('เปิดมายังกดยืนยันไม่ได้ เพราะยังไม่ได้เปลี่ยนปลายทาง', (
    tester,
  ) async {
    await _open(tester);

    // เจอสองที่: บรรทัดค่าเดิมกับช่องที่ตั้งต้นเป็นค่าเดิม ทั้งป้ายและค่า
    expect(find.text('แผนกที่ดูแล'), findsNWidgets(2));
    expect(find.text('HQ'), findsNWidgets(2));

    final button = _confirmButton(tester);
    expect(button.onPressed, isNull);
    expect(
      find.text(
        'ยังเหมือนเดิมทั้งสองช่อง เปลี่ยนอย่างน้อยหนึ่งช่องถึงจะบันทึกได้',
      ),
      findsOneWidget,
    );
  });

  testWidgets('หาชื่อแผนกไม่ได้ ห้ามบอกว่ารหัสไม่มีในระบบ', (tester) async {
    await _open(tester);

    // ยิง API ไม่ผ่าน (ไม่มี token) คนละเรื่องกับหาแล้วไม่เจอ รหัส HQ อาจถูกอยู่
    // ขึ้นเตือนตอนนี้คือไล่ให้คนไปแก้ของที่ไม่ได้พัง
    expect(find.text('ไม่พบรหัสนี้ในระบบ'), findsNothing);
  });

  testWidgets('กดปุ่มลัดฉันถือไว้เองแล้วปุ่มบันทึกกดได้', (tester) async {
    await _open(tester);

    await tester.tap(find.text('ฉันถือไว้เอง'));
    await tester.pump();

    expect(find.text('68148'), findsOneWidget);
    expect(_confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('ล้างช่องแผนกแล้วยังนับว่ามีการเปลี่ยนแปลง', (tester) async {
    await _open(tester);

    await tester.tap(find.byTooltip('ล้าง').first);
    await tester.pump();

    // เอาของออกจากแผนกโดยยังไม่รู้ว่าไปไหนก็เป็นการเปลี่ยนแปลงที่ต้องบันทึกได้
    expect(_confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('ไม่กรอกเหตุผลแล้วกดยืนยัน ต้องเตือน ไม่ยิง API', (tester) async {
    await _open(tester);

    await tester.tap(find.text('ฉันถือไว้เอง'));
    await tester.pump();

    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.pump();

    // ยิง API จริงจะได้ข้อความ "ยังไม่ได้เชื่อมต่อระบบทรัพย์สิน" ขึ้นมาแทน
    expect(find.text('กรอกเหตุผล'), findsOneWidget);
  });

  testWidgets('แตะช่องแผนกแล้วเปิดลิสต์ให้เลือก ไม่ใช่คีย์บอร์ด', (
    tester,
  ) async {
    await _open(tester);

    await tester.tap(find.byType(AssetPickerField).first);
    await tester.pumpAndSettle();

    expect(find.text('เลือกแผนก'), findsOneWidget);
    // ไม่มี token ลิสต์จึงโหลดไม่ได้ ต้องบอกให้ล็อกอินใหม่ ไม่ใช่ปุ่มลองใหม่เปล่า ๆ
    expect(
      find.text('ยังไม่ได้เชื่อมต่อระบบทรัพย์สิน กรุณาเข้าสู่ระบบใหม่'),
      findsOneWidget,
    );
  });
}
