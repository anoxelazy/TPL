import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/itcase/itcase_image.dart';
import 'package:claim/utils/mobile_api.dart';

/// PNG 1x1 จริง ๆ ใช้แทนรูปที่ API ส่งมาเป็น base64
const String _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<Image?> _pump(WidgetTester tester, String source) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ItCaseImage(source: source)),
    ),
  );

  final found = find.byType(Image);
  return found.evaluate().isEmpty ? null : tester.widget<Image>(found);
}

/// ⚠️ ยังไม่รู้ว่า API ส่งรูปมาแบบไหน ตัววิดเจ็ตจึงเดาจากหน้าตาของค่า
/// เทสต์นี้คุมว่าเดาถูกทุกแบบที่เป็นไปได้ และแบบที่อ่านไม่ออกก็ไม่พัง
void main() {
  testWidgets('ลิงก์เต็มใช้ตรง ๆ', (tester) async {
    final image = await _pump(tester, 'https://internal.example/it/1.jpg');

    expect(
      (image!.image as NetworkImage).url,
      'https://internal.example/it/1.jpg',
    );
  });

  testWidgets('พาธบนเซิร์ฟเวอร์ต่อกับโดเมนของ API ให้เอง', (tester) async {
    final image = await _pump(tester, '/upload/it/IT2026106446.jpg');

    expect(
      (image!.image as NetworkImage).url,
      '${MobileApi.baseUrl}/upload/it/IT2026106446.jpg',
      reason: 'รูปอยู่เครื่องเดียวกับ API พาธเปล่า ๆ โหลดไม่ได้',
    );
  });

  testWidgets('พาธที่ไม่มี / นำหน้า ก็ยังต่อโดเมนให้ถูก', (tester) async {
    final image = await _pump(tester, 'upload/it/IT2026106446.jpg');

    expect(
      (image!.image as NetworkImage).url,
      '${MobileApi.baseUrl}/upload/it/IT2026106446.jpg',
    );
  });

  testWidgets('base64 เปล่า ๆ ถอดเป็นรูปได้', (tester) async {
    final image = await _pump(tester, _png);

    expect(image!.image, isA<MemoryImage>());
  });

  testWidgets('data URI ถอดเฉพาะส่วนหลังคอมมา', (tester) async {
    final image = await _pump(tester, 'data:image/png;base64,$_png');

    expect(image!.image, isA<MemoryImage>());
  });

  testWidgets('ค่าที่ไม่ใช่รูป ขึ้นกล่องแทน ไม่พังทั้งหน้า', (tester) async {
    final image = await _pump(tester, 'ไม่มีรูป');

    expect(image, isNull);
    expect(find.text('แสดงรูปไม่ได้'), findsOneWidget);
  });
}
