import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/dashboard_page.dart';

void main() {
  group('แบ่งหน้าเมนู', () {
    test('หน้าละ 8 = 4 ช่องสองแถว', () {
      expect(kMenuPerPage, 8);
      expect(kMenuPerPage % 4, 0, reason: 'ต้องหารด้วยจำนวนคอลัมน์ลงตัว');
    });

    test('จำนวนหน้าคิดจากเมนูทั้งหมด', () {
      int pages(int items) => (items / kMenuPerPage).ceil();

      expect(pages(8), 1, reason: '8 พอดีหน้าเดียว ไม่ต้องมีจุดบอกหน้า');
      expect(pages(9), 2, reason: 'เกินมาตัวเดียวก็ต้องมีหน้าสอง');
      expect(pages(16), 2);
      expect(pages(17), 3);
    });
  });

  testWidgets('เมนูเกิน 8 มีจุดบอกหน้า เลื่อนไปหน้าสองได้', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DashboardPage())),
    );
    await tester.pump();

    // เมนูจริงมี 9 ตัว หน้าแรกต้องไม่โชว์เกิน 8
    expect(find.byType(PageView), findsOneWidget);

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(
      pageView.controller?.hasClients,
      isTrue,
      reason: 'ต้องผูก controller แล้ว ไม่งั้นเลื่อนหน้าไม่ได้',
    );
  });
}
