import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/claim/claim_dialogs.dart';

void main() {
  /// เปิดหน้าต่างยืนยันลบ แล้วคืนค่าที่ผู้ใช้เลือก (null = ยังไม่ได้ปิด)
  Future<bool? Function()> open(WidgetTester tester, String doc) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => answer = await showConfirmDeleteDialog(
                context,
                docNumber: doc,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => answer;
  }

  testWidgets('บอกเลขเอกสารของใบที่จะลบ กันลบผิดใบ', (tester) async {
    await open(tester, 'A1-777');

    expect(find.text('ลบรายการนี้?'), findsOneWidget);
    expect(find.textContaining('A1-777'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  testWidgets('กดลบได้ true', (tester) async {
    final answer = await open(tester, 'A1-1');

    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();

    expect(answer(), isTrue);
  });

  testWidgets('ยืนยันส่งซ้ำใช้กล่องแบบเดียวกัน บอกเลขเอกสาร', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => answer = await showConfirmResendDialog(
                context,
                docNumber: 'A1-555',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('ส่งอีกครั้ง?'), findsOneWidget);
    expect(find.textContaining('A1-555'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    await tester.tap(find.text('ส่งอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('กดยกเลิกได้ false และไม่มีอะไรถูกลบ', (tester) async {
    final answer = await open(tester, 'A1-1');

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(answer(), isFalse);
  });
}
