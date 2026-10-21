import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/claim/sending_animation.dart';

Future<ValueNotifier<SendingStatus>> _pump(WidgetTester tester) async {
  final status = ValueNotifier(SendingStatus.sending);
  addTearDown(status.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SendingAnimation(
          statusNotifier: status,
          message: 'กำลังส่งรายการ...',
        ),
      ),
    ),
  );
  return status;
}

void main() {
  testWidgets('กำลังส่ง จุดไข่ปลาวิ่งท้ายข้อความ ไม่ซ้อนกับจุดเดิม', (
    tester,
  ) async {
    await _pump(tester);

    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(tester.takeException(), isNull);
    expect(find.textContaining('กำลังส่งรายการ'), findsOneWidget);
    // จุดเดิมในข้อความถูกตัดออก ไม่กลายเป็น "......"
    expect(find.textContaining('....'), findsNothing);
  });

  testWidgets('ส่งสำเร็จ เปลี่ยนเป็นวงเขียวพร้อมข้อความสำเร็จ แล้วหยุดนิ่ง', (
    tester,
  ) async {
    final status = await _pump(tester);
    await tester.pump(const Duration(milliseconds: 300));

    status.value = SendingStatus.success;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ส่งข้อมูลสำเร็จ'), findsOneWidget);
    // วงหมุนหยุดแล้ว ไม่มีแอนิเมชันค้าง (pumpAndSettle จบได้แปลว่าหยุดจริง)
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('ส่งไม่สำเร็จ ขึ้นข้อความผิดพลาด แล้วหยุดนิ่ง', (tester) async {
    final status = await _pump(tester);
    await tester.pump(const Duration(milliseconds: 300));

    status.value = SendingStatus.error;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('เกิดข้อผิดพลาด'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
