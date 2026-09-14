import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/info_row.dart';

Future<ChoiceChip> pumpChip(
  WidgetTester tester, {
  required bool selected,
  Color? color,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatusFilterChip(
          label: 'สำเร็จ',
          count: 5,
          color: color,
          selected: selected,
          onSelected: () {},
        ),
      ),
    ),
  );

  return tester.widget<ChoiceChip>(find.byType(ChoiceChip));
}

TextStyle labelStyle(ChoiceChip chip) => (chip.label as Text).style!;

void main() {
  group('chip กรองสถานะ', () {
    testWidgets('ตอนเลือกอยู่ย้อมสีของสถานะนั้น', (tester) async {
      final chip = await pumpChip(
        tester,
        selected: true,
        color: AppColors.success,
      );

      expect(chip.selectedColor, AppColors.success.withValues(alpha: 0.16));
      expect(labelStyle(chip).color, AppColors.success);
      expect((chip.side as BorderSide).color, AppColors.success);
    });

    testWidgets('ยังไม่เลือกใช้สีตัวหนังสือปกติ', (tester) async {
      final chip = await pumpChip(
        tester,
        selected: false,
        color: AppColors.success,
      );

      expect(labelStyle(chip).color, isNot(AppColors.success));
    });

    testWidgets('chip "ทั้งหมด" ไม่มีสีสถานะ ใช้สีของธีม', (tester) async {
      final chip = await pumpChip(tester, selected: true);

      expect(chip.selectedColor, isNull);
      expect(labelStyle(chip).color, isNot(AppColors.success));
    });

    testWidgets('แสดงจำนวนต่อท้ายชื่อสถานะ', (tester) async {
      await pumpChip(tester, selected: false, color: AppColors.pending);

      expect(find.text('สำเร็จ 5'), findsOneWidget);
    });

    testWidgets('กดแล้วเรียก onSelected', (tester) async {
      var tapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusFilterChip(
              label: 'คงเหลือ',
              count: 2,
              color: AppColors.pending,
              selected: false,
              onSelected: () => tapped++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ChoiceChip));
      expect(tapped, 1);
    });
  });
}
