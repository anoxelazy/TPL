import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/claim/claim_form_page.dart';

/// เปิดหน้าหลักที่มีปุ่มพาไปฟอร์ม แล้วกดเข้าฟอร์ม
Future<void> _openForm(
  WidgetTester tester, {
  Map<String, dynamic>? initialClaim,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ClaimFormPage(
                  initialClaim: initialClaim,
                  empId: '1',
                  empName: 'ทดสอบ',
                  onScanBarcode: (_, _) async => null,
                ),
              ),
            ),
            child: const Text('เปิดฟอร์ม'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('เปิดฟอร์ม'));
  await tester.pumpAndSettle();
  expect(find.byType(ClaimFormPage), findsOneWidget);
}

Future<void> _pressBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ยังไม่กรอกอะไรเลย กดกลับออกได้ทันที ไม่มีเตือน', (tester) async {
    await _openForm(tester);

    await _pressBack(tester);

    expect(find.text('ทิ้งข้อมูลที่กรอกไว้?'), findsNothing);
    expect(find.byType(ClaimFormPage), findsNothing);
  });

  testWidgets('กรอกไปบ้างแล้ว กดกลับต้องเตือนก่อน', (tester) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField).first, 'TP123');

    await _pressBack(tester);

    expect(find.text('ทิ้งข้อมูลที่กรอกไว้?'), findsOneWidget);
    expect(find.byType(ClaimFormPage), findsOneWidget);
  });

  testWidgets('เตือนแล้วกด "กรอกต่อ" ยังอยู่ในฟอร์ม ข้อมูลไม่หาย', (
    tester,
  ) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField).first, 'TP123');
    await _pressBack(tester);

    await tester.tap(find.text('กรอกต่อ'));
    await tester.pumpAndSettle();

    expect(find.byType(ClaimFormPage), findsOneWidget);
    expect(find.text('TP123'), findsOneWidget);
  });

  testWidgets('เตือนแล้วกด "ทิ้งข้อมูลแล้วออก" ออกจากฟอร์ม', (tester) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField).first, 'TP123');
    await _pressBack(tester);

    await tester.tap(find.text('ทิ้งข้อมูลแล้วออก'));
    await tester.pumpAndSettle();

    expect(find.byType(ClaimFormPage), findsNothing);
  });

  testWidgets('พิมพ์แล้วลบจนว่างเหมือนเดิม กดกลับออกได้เลย', (tester) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField).first, 'TP123');
    await tester.enterText(find.byType(TextField).first, '');

    await _pressBack(tester);

    expect(find.byType(ClaimFormPage), findsNothing);
  });

  testWidgets('แก้ไขรายการเดิมแต่ยังไม่ได้แก้อะไร กดกลับออกได้เลย', (
    tester,
  ) async {
    await _openForm(
      tester,
      initialClaim: {
        'docNumber': 'TP9',
        'carCode': 'C9',
        'type': 'เสียหาย',
        'timestamp': DateTime(2026, 10, 20),
        'images': const [],
      },
    );

    await _pressBack(tester);

    expect(find.byType(ClaimFormPage), findsNothing);
  });

  testWidgets('แก้ไขรายการเดิมแล้วเปลี่ยนค่า เตือนแบบข้อความแก้ไข', (
    tester,
  ) async {
    await _openForm(
      tester,
      initialClaim: {
        'docNumber': 'TP9',
        'carCode': 'C9',
        'type': 'เสียหาย',
        'timestamp': DateTime(2026, 10, 20),
        'images': const [],
      },
    );
    await tester.enterText(find.byType(TextField).first, 'TP10');

    await _pressBack(tester);

    expect(find.text('ยกเลิกการแก้ไข?'), findsOneWidget);
  });
}
