import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/claim/claim_summary_bar.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int sent,
    required int pending,
    required int failed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClaimSummaryBar(sent: sent, pending: pending, failed: failed),
        ),
      ),
    );
  }

  testWidgets('โชว์ตัวเลขครบสามช่องและยอดรวม', (tester) async {
    await pump(tester, sent: 3, pending: 2, failed: 1);

    expect(find.text('ส่งสำเร็จ'), findsOneWidget);
    expect(find.text('รอส่ง'), findsOneWidget);
    expect(find.text('ไม่สำเร็จ'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('ทั้งหมด 6 รายการ'), findsOneWidget);
  });

  testWidgets('ช่องที่เป็นศูนย์ไม่กินที่บนแถบสี', (tester) async {
    await pump(tester, sent: 4, pending: 0, failed: 0);

    // เหลือสีเดียวเต็มแถบ ไม่มีเส้นคั่นระหว่างช่อง
    final bar = find.descendant(
      of: find.byType(ClipRRect),
      matching: find.byType(Expanded),
    );
    expect(bar, findsOneWidget);
  });

  testWidgets('ช่องสีบนแถบสูงเต็มแถบ ไม่หายไปเป็นเส้นศูนย์', (tester) async {
    await pump(tester, sent: 2, pending: 1, failed: 1);

    final segments = find.descendant(
      of: find.byType(ClipRRect),
      matching: find.byType(ColoredBox),
    );
    expect(segments, findsNWidgets(3));
    for (final element in segments.evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)).height, 10);
    }
  });

  testWidgets('ไม่มีรายการเลยก็วาดได้ ไม่หารศูนย์พัง', (tester) async {
    await pump(tester, sent: 0, pending: 0, failed: 0);

    expect(tester.takeException(), isNull);
    expect(find.text('ทั้งหมด 0 รายการ'), findsOneWidget);
  });
}
