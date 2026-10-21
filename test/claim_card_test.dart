import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/claim/claim_card.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool isSent,
  bool sendFailed = false,
  VoidCallback? onSend,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: ClaimCard(
        claim: {
          'docNumber': 'TP123',
          'carCode': 'C01',
          'type': 'เสียหาย',
          'timestamp': DateTime(2026, 10, 20),
          'isSent': isSent,
          if (sendFailed) 'sendFailed': true,
        },
        index: 0,
        onEdit: () {},
        onSend: onSend ?? () {},
      ),
    ),
  ),
);

Color? _cardColor(WidgetTester tester) =>
    tester.widget<AppCard>(find.byType(AppCard)).color;

void main() {
  testWidgets('ยังไม่ส่ง การ์ดส้ม ปุ่มเป็นรูปส่ง', (tester) async {
    await _pump(tester, isSent: false);

    expect(_cardColor(tester), AppColors.claimPendingBg);
    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.text('ส่งซ้ำ'), findsNothing);
  });

  testWidgets('ส่งแล้ว การ์ดเขียว ปุ่มเปลี่ยนเป็นวนซ้ำ บอกว่ากดอีกคือส่งซ้ำ', (
    tester,
  ) async {
    await _pump(tester, isSent: true);

    expect(_cardColor(tester), AppColors.claimSentBg);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.send_outlined), findsNothing);
    expect(find.text('ส่งซ้ำ'), findsOneWidget);
  });

  testWidgets('ส่งไม่สำเร็จหรือเซิร์ฟเวอร์ไม่ตอบ การ์ดแดง รอกดส่งใหม่', (
    tester,
  ) async {
    await _pump(tester, isSent: false, sendFailed: true);

    expect(_cardColor(tester), AppColors.claimFailedBg);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.text('ส่งใหม่'), findsOneWidget);
    expect(find.text('ส่งไม่สำเร็จ กดส่งอีกครั้ง'), findsOneWidget);
  });

  testWidgets('เคยส่งสำเร็จแล้ว ค่าพลาดที่ค้างอยู่ไม่ทำให้การ์ดแดง', (
    tester,
  ) async {
    await _pump(tester, isSent: true, sendFailed: true);

    expect(_cardColor(tester), AppColors.claimSentBg);
    expect(find.text('ส่งซ้ำ'), findsOneWidget);
  });

  testWidgets('ปุ่มส่งซ้ำยังกดส่งได้', (tester) async {
    var sent = 0;
    await _pump(tester, isSent: true, onSend: () => sent++);

    await tester.tap(find.byIcon(Icons.refresh_rounded));

    expect(sent, 1);
  });
}
