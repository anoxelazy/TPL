import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/widgets/state_views.dart';

void main() {
  testWidgets('ใส่การ์ดเท่าที่จอพอดี ไม่ล้น', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ListLoadingView())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('วางในที่ที่ความสูงไม่จำกัดก็ไม่พัง', (tester) async {
    // บางหน้าวางตัวโหลดไว้ใน Column ที่เลื่อนได้ ListView จะ throw ทันที
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ListLoadingView())),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Card), findsNWidgets(4));
  });
}
