import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/scan/scan_api.dart';
import 'package:claim/page/scan/scan_widgets.dart';

/// PNG 1x1 สีแดง ใช้แทนรูปจริงเพื่อไม่ต้องยิงเน็ตในเทสต์
const String _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<void> pumpCard(WidgetTester tester, List<String> images) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScanCheckCard(
          checking: false,
          result: ScanCheckResult(
            status: ScanCheckStatus.found,
            images: images,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('รูปย่อในการ์ดผลตรวจ', () {
    testWidgets('ต้องมีขนาดจริง ไม่ยุบเป็นศูนย์', (tester) async {
      await pumpCard(tester, const [_png]);
      await tester.pump();

      final size = tester.getSize(find.byType(Image).first);

      expect(size.width, greaterThan(0), reason: 'กว้างเป็นศูนย์ = มองไม่เห็น');
      expect(size.height, greaterThan(0), reason: 'สูงเป็นศูนย์ = มองไม่เห็น');
    });

    testWidgets('หลายรูปต้องขึ้นครบทุกใบ', (tester) async {
      await pumpCard(tester, const [_png, _png, _png]);
      await tester.pump();

      expect(find.byType(Image), findsNWidgets(3));
    });
  });
}
