import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/asset_register_page.dart';

void main() {
  testWidgets('ยังไม่มี token ของ Mobile API บอกให้ล็อกอินใหม่ ไม่ให้ปุ่มลองใหม่', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AssetRegisterPage()),
    );
    // รอ future ของการโหลดลิสต์ทำงานจนจบ
    await tester.pumpAndSettle();

    expect(
      find.text('ยังไม่ได้เชื่อมต่อระบบทรัพย์สิน กรุณาเข้าสู่ระบบใหม่'),
      findsOneWidget,
    );

    // กดลองใหม่กี่ทีก็ไม่ผ่านเมื่อไม่มี token จึงต้องไม่มีปุ่มนี้ให้กด
    expect(find.text('ลองใหม่'), findsNothing);
    expect(find.text('บันทึกทรัพย์สิน'), findsNothing);
  });
}
