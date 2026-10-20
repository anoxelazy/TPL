import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/asset/asset_style.dart';

/// กลุ่มที่พับได้ของฟอร์มทรัพย์สิน
///
/// สิ่งที่ต้องไม่พังคือ **ช่องที่ซ่อนอยู่ยังเป็นส่วนหนึ่งของ Form** ถ้าวันไหน
/// เปลี่ยนไปถอดของข้างในออกตอนพับ ช่องที่กรอกผิดจะผ่าน validate ไปเงียบ ๆ
void main() {
  Widget host({
    required bool expanded,
    required GlobalKey<FormState> formKey,
    VoidCallback? onToggle,
  }) => MaterialApp(
    home: Scaffold(
      body: Form(
        key: formKey,
        child: AssetSection(
          title: 'การจัดซื้อและประกัน',
          expanded: expanded,
          summary: 'กรอกแล้ว 1 ช่อง',
          onToggle: onToggle,
          children: [
            TextFormField(
              initialValue: 'ราคาผิด',
              decoration: const InputDecoration(labelText: 'ราคาซื้อ'),
              validator: (value) => 'ราคาไม่ถูกต้อง',
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('กลุ่มที่พับอยู่ซ่อนของข้างในแต่ยัง validate ให้', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(host(expanded: false, formKey: formKey));

    // ช่องยังอยู่ในต้นไม้ (ต้องบอก finder ให้มองของที่ซ่อนด้วยถึงจะเจอ)
    expect(find.text('ราคาผิด', skipOffstage: false), findsOneWidget);
    expect(find.text('ราคาผิด'), findsNothing);

    // จุดสำคัญ: validator ของช่องที่ซ่อนอยู่ต้องยังถูกเรียก
    expect(formKey.currentState?.validate(), isFalse);
  });

  testWidgets('ตอนพับมีบรรทัดสรุปบอกว่าข้างในมีของกรอกไว้แล้ว', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(host(expanded: false, formKey: formKey));

    expect(find.text('กรอกแล้ว 1 ช่อง'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('กางแล้วบรรทัดสรุปหายไป ของข้างในโผล่', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(host(expanded: true, formKey: formKey));

    expect(find.text('กรอกแล้ว 1 ช่อง'), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('ราคาผิด'), findsOneWidget);
  });

  testWidgets('กดที่หัวข้อทั้งแถบได้ ไม่ใช่กดได้แค่ลูกศร', (tester) async {
    final formKey = GlobalKey<FormState>();
    var taps = 0;
    await tester.pumpWidget(
      host(expanded: false, formKey: formKey, onToggle: () => taps++),
    );

    await tester.tap(find.text('การจัดซื้อและประกัน'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('กลุ่มธรรมดาไม่มีลูกศรให้กด และของข้างในโชว์ตลอด', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssetSection(
            title: 'ข้อมูลทรัพย์สิน',
            children: [Text('ชื่อทรัพย์สิน')],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(find.text('ชื่อทรัพย์สิน'), findsOneWidget);
  });
}
