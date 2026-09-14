import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/scan/scan_widgets.dart';

Future<void> pumpBox(
  WidgetTester tester, {
  required bool hasBarcode,
  bool uploading = false,
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScanPhotoBox(
          hasBarcode: hasBarcode,
          uploading: uploading,
          uploadingFile: null,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('ยังไม่มีบาร์โค้ด', () {
    testWidgets('บอกให้สแกนก่อน และกดไม่ได้', (tester) async {
      await pumpBox(tester, hasBarcode: false);

      expect(find.text('สแกนบาร์โค้ดก่อน'), findsOneWidget);
      expect(find.text('ถ่ายรูปบาร์สินค้า(เท่านั้น)'), findsNothing);

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });
  });

  group('พร้อมถ่าย', () {
    testWidgets('ขึ้นข้อความให้ถ่ายรูป', (tester) async {
      await pumpBox(tester, hasBarcode: true);

      expect(find.text('ถ่ายรูปบาร์สินค้า(เท่านั้น)'), findsOneWidget);
      expect(
        find.text('ถ่ายรูปใหม่หรือเลือกรูปบาร์จากคลังรูป'),
        findsOneWidget,
      );
      expect(find.text('สแกนบาร์โค้ดก่อน'), findsNothing);
    });

    testWidgets('กดได้', (tester) async {
      var taps = 0;
      await pumpBox(tester, hasBarcode: true, onTap: () => taps++);

      await tester.tap(find.byType(ScanPhotoBox));
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('กำลังส่ง', () {
    testWidgets('ขึ้น spinner และกดซ้ำไม่ได้', (tester) async {
      await pumpBox(tester, hasBarcode: true, uploading: true);

      expect(find.text('กำลังส่ง...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // กันส่งซ้อน: ระหว่างส่งต้องกดไม่ได้
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });

    testWidgets('ไม่โชว์ข้อความของสถานะพร้อมถ่ายทับกัน', (tester) async {
      await pumpBox(tester, hasBarcode: true, uploading: true);

      expect(find.text('ถ่ายรูปบาร์สินค้า(เท่านั้น)'), findsNothing);
    });
  });

  group('ความสูงคงที่ทุกสถานะ', () {
    testWidgets('กรอบต้องสูงเท่ากันไม่ว่าสถานะไหน', (tester) async {
      double heightOf() => tester.getSize(find.byType(ScanPhotoBox)).height;

      await pumpBox(tester, hasBarcode: false);
      final idle = heightOf();

      await pumpBox(tester, hasBarcode: true);
      expect(heightOf(), idle);

      await pumpBox(tester, hasBarcode: true, uploading: true);
      expect(heightOf(), idle);
    });
  });
}
