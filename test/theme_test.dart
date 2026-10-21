import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/colors.dart' as palette;
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';

/// เทสต์เรื่องสีของธีมเท่านั้น ไม่แตะ [AppTheme.getLightTheme] เพราะตัวนั้น
/// เรียก google_fonts ที่ต้องโหลดฟอนต์จากเน็ต ซึ่งในเทสต์ทำไม่ได้
void main() {
  group('สีแบรนด์ของธีม', () {
    test('สีแบรนด์คือเขียวหลักจากชุดสีของฝั่งออกแบบ', () {
      expect(AppColors.brand, palette.AppColors.greenPrimary);
    });

    test('สีที่ใช้เป็นตัวหนังสือเล็กบนพื้นขาวได้ contrast อย่างน้อย 4.5:1', () {
      final scheme = AppTheme.buildColorScheme(Brightness.light);

      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      // brandText ไม่อยู่ในรายการนี้แล้ว: เป็นเขียวหลักตัวเดียวกับปุ่ม
      // (ได้ราว 3.1:1) เพื่อให้ทั้งแอปมีเขียวเดียว ดูเทสต์ "เขียวเดียว" ข้างล่าง
      for (final c in [
        AppColors.moneyText,
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ]) {
        expect(contrast(c, Colors.white), greaterThanOrEqualTo(4.5));
      }
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

    test('ไอคอนเมนูใช้เขียวคู่เดียวกันหมด ไม่กลับไปเป็นหลายสี', () {
      final menuIcons = [
        AppColors.claimIcon,
        AppColors.stockIcon,
        AppColors.planIcon,
        AppColors.pmIcon,
        AppColors.assetIcon,
        AppColors.meterIcon,
        AppColors.scanIcon,
        AppColors.trackingIcon,
        AppColors.repairMenuIcon,
      ].toSet();

      expect(menuIcons, {AppColors.menuIcon});
    });

    test('ทั้งแอปมีเขียวตัวเดียว คือเขียวหลักของชุดสี', () {
      final greens = [
        AppColors.brand,
        AppColors.brandText,
        AppColors.success,
        AppColors.successText,
        AppColors.lineGreen,
        AppColors.repairIcon,
        AppColors.caseIcon,
        AppColors.menuIcon,
      ].toSet();

      expect(greens, {palette.AppColors.greenPrimary});
    });

    test('เขียวหลักยังเห็นชัดพอสำหรับไอคอนและตัวหนา (อย่างน้อย 3:1)', () {
      final l = AppColors.brand.computeLuminance();
      expect(1.05 / (l + 0.05), greaterThanOrEqualTo(3));
    });

    test('พื้นผิวเป็นเทาเป็นกลาง ไม่ถูกย้อมเขียว', () {
      final scheme = AppTheme.buildColorScheme(Brightness.light);
      final page = AppTheme.pageBackground(scheme);

      // เทาเป็นกลาง = แดง เขียว น้ำเงิน ห่างกันนิดเดียว
      int spread(Color c) {
        final channels = [c.r, c.g, c.b].map((v) => (v * 255).round());
        return channels.reduce((a, b) => a > b ? a : b) -
            channels.reduce((a, b) => a < b ? a : b);
      }

      expect(spread(page), lessThanOrEqualTo(6));
      expect(spread(scheme.surface), lessThanOrEqualTo(6));
    });

    test('การ์ดสว่างกว่าพื้นหน้า การ์ดจึงลอยขึ้นมาโดยไม่ต้องมีเงา', () {
      final scheme = AppTheme.buildColorScheme(Brightness.light);

      expect(
        AppTheme.cardColor(scheme).computeLuminance(),
        greaterThan(AppTheme.pageBackground(scheme).computeLuminance()),
      );
    });

    test('แถบหัวเรื่องเป็นพื้นอ่อน ไอคอนแถบสถานะต้องเป็นสีเข้ม', () {
      final scheme = AppTheme.buildColorScheme(Brightness.light);
      final style = AppTheme.statusBarStyleFor(AppTheme.pageBackground(scheme));

      expect(style.statusBarIconBrightness, Brightness.dark);
    });
  });
}
