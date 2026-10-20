import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';

/// เทสต์เรื่องสีของธีมเท่านั้น ไม่แตะ [AppTheme.getLightTheme] เพราะตัวนั้น
/// เรียก google_fonts ที่ต้องโหลดฟอนต์จากเน็ต ซึ่งในเทสต์ทำไม่ได้
void main() {
  group('สีแบรนด์ของธีม', () {
    test('สีแบรนด์คือเขียว #00A751 ตามที่บริษัทใช้', () {
      expect(AppColors.brand, const Color(0xFF00A751));
    });

    test('ธีมสว่างใช้สีแบรนด์เป๊ะ ไม่ใช่โทนที่ M3 คำนวณให้', () {
      final scheme = AppTheme.buildColorScheme(Brightness.light);

      expect(scheme.primary, AppColors.brand);
      expect(scheme.onPrimary, Colors.white);
    });

    test('ธีมมืดไม่เอาเขียวสดมาใช้ ปล่อยตามโทนที่คำนวณมา', () {
      final scheme = AppTheme.buildColorScheme(Brightness.dark);

      expect(scheme.primary, isNot(AppColors.brand));
      expect(scheme.brightness, Brightness.dark);
    });

    test('ไอคอนแถบสถานะเป็นสีสว่างเมื่อพื้นหลังเป็นสีแบรนด์', () {
      final style = AppTheme.statusBarStyleFor(AppColors.brand);

      // เขียวแบรนด์นับเป็นพื้นเข้ม ไอคอนจึงต้องสว่างถึงจะเห็น
      expect(style.statusBarIconBrightness, Brightness.light);
    });

    test('สีแบรนด์เวอร์ชันตัวหนังสือเข้มกว่าตัวเต็ม', () {
      // ใช้กับตัวอักษรเล็กบนพื้นขาว ที่สีเต็มสว่างเกินเกณฑ์ contrast
      expect(
        AppColors.brandText.computeLuminance(),
        lessThan(AppColors.brand.computeLuminance()),
      );
    });
  });
}
