import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/claim/claim.dart';
import 'package:claim/page/claim/claim_card.dart';

void main() {
  testWidgets('ปัดเปิดปุ่มลบ กล่องสูงเท่าการ์ด ห่างการ์ดกับขอบจอเท่ากัน', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ClaimListItem(
                claim: {
                  'id': 'c1',
                  'docNumber': 'TP1',
                  'carCode': 'C1',
                  'type': 'เสียหาย',
                  'timestamp': DateTime(2026, 10, 20),
                },
                index: 0,
                onEdit: () {},
                onSend: () {},
                onDelete: () => deleted++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ClaimCard), const Offset(-200, 0));
    await tester.pumpAndSettle();

    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(ClaimCard),
            matching: find.byType(Material),
          )
          .first,
    );
    final button = tester.getRect(
      find
          .ancestor(of: find.text('ลบ'), matching: find.byType(Container))
          .first,
    );

    // กว้างพอเป็นปุ่มจริง ไม่ใช่แท่งผอมเท่าไอคอน
    expect(button.width, greaterThan(60));
    expect(button.top, card.top);
    expect(button.bottom, card.bottom);
    // ห่างการ์ดกับห่างขอบจอขวาเท่ากัน
    expect(button.left - card.right, closeTo(360 - button.right, 0.5));

    await tester.tap(find.text('ลบ'));
    expect(deleted, 1);
  });
}
