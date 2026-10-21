import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:claim/colors.dart' as palette;
import 'package:claim/utils/app_colors.dart';

class AppTheme {
  /// สไตล์ของแถบสถานะ (นาฬิกา แบต สัญญาณ) ให้ตัดกับพื้นหลังที่อยู่ข้างหลัง
  ///
  /// ถ้าไม่ตั้งค่านี้ ไอคอนจะกลืนไปกับพื้นหลัง เช่นไอคอนขาวบนพื้นขาว
  /// จนมองไม่เห็นแถบด้านบนของเครื่องเลย
  ///
  /// [background] คือสีที่อยู่ใต้แถบสถานะจริง ๆ ไม่ใช่สีของธีม
  static SystemUiOverlayStyle statusBarStyleFor(Color background) {
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Android: ความสว่างของ "ไอคอน" จึงต้องตรงข้ามกับพื้นหลัง
      statusBarIconBrightness: isDarkBackground
          ? Brightness.light
          : Brightness.dark,
      // iOS: ความสว่างของ "พื้นหลัง" ระบบเลือกสีตัวอักษรให้เอง
      statusBarBrightness: isDarkBackground
          ? Brightness.dark
          : Brightness.light,
    );
  }

  static ThemeData? _lightTheme;
  static ThemeData? _darkTheme;

  static ThemeData getLightTheme() {
    _lightTheme ??= _buildTheme(Brightness.light);
    return _lightTheme!;
  }

  static ThemeData getDarkTheme() {
    _darkTheme ??= _buildTheme(Brightness.dark);
    return _darkTheme!;
  }

  /// ชุดสีของธีม แยกออกมาจากการสร้าง ThemeData เพื่อให้เทสต์ได้
  ///
  /// [_buildTheme] เรียก google_fonts ซึ่งต้องโหลดฟอนต์จากเน็ต แตะไม่ได้ในเทสต์
  /// ส่วนการตัดสินใจเรื่องสีอยู่ในฟังก์ชันนี้ทั้งหมด
  @visibleForTesting
  static ColorScheme buildColorScheme(Brightness brightness) {
    final ColorScheme seeded = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    );

    // พื้นผิวทั้งหมด (พื้นหลัง การ์ด เส้นขอบ ตัวหนังสือรอง) เอาจากชุดเป็นกลาง
    //
    // fromSeed ย้อมพื้นผิวทุกชั้นด้วยสีของ seed พื้นหลังกับการ์ดเลยออกเขียว
    // จาง ๆ ไปทั้งแอป เขียวเลยไม่เด่นตรงไหนเพราะมีอยู่ทุกที่ ใช้เทาเป็นกลาง
    // แล้วเก็บเขียวไว้แค่ primary (ปุ่มหลัก ของที่เลือกอยู่)
    final ColorScheme neutral = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    );
    //
    // ธีมสว่างกำหนดเทาเองทุกชั้นจากชุดสีของฝั่งออกแบบ (lib/colors.dart)
    // ชุดสีมีเทาอยู่ไม่กี่ขั้น ชั้นที่ไม่มีในชุดจึงใช้ขั้นที่ใกล้ที่สุดซ้ำ
    final ColorScheme base = brightness == Brightness.light
        ? seeded.copyWith(
            surface: palette.AppColors.completeWhite,
            onSurface: palette.AppColors.baseBlack,
            // ตัวหนังสือรองเป็นเทาเข้มนอกชุดสี greyNeutral400 ของชุดสีได้
            // contrast แค่ 2.7:1 บนพื้นขาว คำอธิบายใต้หัวข้อจะอ่านยาก
            // ตัวนี้โทนเดียวกันแต่เข้มขึ้นจนได้ 5.5:1
            onSurfaceVariant: const Color(0xFF6B6868),
            surfaceDim: palette.AppColors.greyNeutral200,
            surfaceBright: palette.AppColors.completeWhite,
            surfaceContainerLowest: palette.AppColors.completeWhite,
            surfaceContainerLow: palette.AppColors.baseWhite,
            surfaceContainer: palette.AppColors.greyNeutral100,
            surfaceContainerHigh: palette.AppColors.greyNeutral100,
            surfaceContainerHighest: palette.AppColors.greyNeutral200,
            outline: palette.AppColors.greyNeutral400,
            outlineVariant: palette.AppColors.greyNeutral100,
            error: palette.AppColors.redError,
            onError: palette.AppColors.completeWhite,
            errorContainer: palette.AppColors.redSecondary100,
            onErrorContainer: palette.AppColors.redSecondary,
          )
        : seeded.copyWith(
            surface: neutral.surface,
            onSurface: neutral.onSurface,
            onSurfaceVariant: neutral.onSurfaceVariant,
            surfaceDim: neutral.surfaceDim,
            surfaceBright: neutral.surfaceBright,
            surfaceContainerLowest: neutral.surfaceContainerLowest,
            surfaceContainerLow: neutral.surfaceContainerLow,
            surfaceContainer: neutral.surfaceContainer,
            surfaceContainerHigh: neutral.surfaceContainerHigh,
            surfaceContainerHighest: neutral.surfaceContainerHighest,
            outline: neutral.outline,
            outlineVariant: neutral.outlineVariant,
          );

    // ธีมสว่างบังคับ primary ให้เป็นสีแบรนด์เป๊ะ ๆ ไม่ใช้โทนที่ M3 คำนวณให้
    //
    // fromSeed จะลดความสดของ seed ลงเพื่อความสบายตา ผลคือแถบหัวเรื่องออกมา
    // เขียวหม่นคนละสีกับที่บริษัทใช้จริง พอเป็นสีประจำแบรนด์ที่คนจำได้ ความ
    // ตรงของสีสำคัญกว่าโทนที่ระบบเลือกให้
    //
    // ธีมมืดปล่อยตามที่คำนวณมา เพราะเขียวสดบนพื้นดำจะแสบตา
    return brightness == Brightness.light
        ? base.copyWith(primary: AppColors.brand, onPrimary: Colors.white)
        : base;
  }

  /// สีพื้นหลังของหน้า (ใต้การ์ด)
  ///
  /// ธีมสว่างเป็นเทาอ่อนกว่าการ์ดหนึ่งขั้น การ์ดขาวจะลอยขึ้นมาเองโดยไม่ต้อง
  /// พึ่งเงาหรือขอบสี ธีมมืดใช้พื้นผิวปกติ การ์ดเป็นชั้นที่สว่างกว่าอยู่แล้ว
  @visibleForTesting
  static Color pageBackground(ColorScheme scheme) =>
      scheme.brightness == Brightness.light
      ? scheme.surfaceContainerLow
      : scheme.surface;

  /// สีการ์ด ธีมสว่างเป็นขาวสนิทให้ตัดกับพื้นเทา
  static Color cardColor(ColorScheme scheme) =>
      scheme.brightness == Brightness.light
      ? scheme.surfaceContainerLowest
      : scheme.surfaceContainer;

  static ThemeData _buildTheme(Brightness brightness) {
    final ColorScheme colorScheme = buildColorScheme(brightness);

    final TextTheme baseTextTheme = GoogleFonts.notoSansThaiTextTheme();
    final TextTheme textTheme = baseTextTheme.copyWith(
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );

    final TextTheme finalTextTheme = brightness == Brightness.dark
        ? textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white)
        : textTheme;

    // แถบหัวเรื่องสีเดียวกับพื้นหลังของหน้า ไม่ใช่เขียวทึบอีกต่อไป
    //
    // เดิมทุกหน้ามีแถบเขียวเต็มความกว้าง บวกกับสีประจำเมนูอีกหลายสี
    // จอเลยแน่นไปด้วยสี แถบที่กลืนกับหน้าทำให้เนื้อหาเป็นพระเอก และพอเขียว
    // เหลือแค่ปุ่มหลัก ตาก็วิ่งไปหาปุ่มเอง
    final bool isDark = brightness == Brightness.dark;
    final Color pageBg = pageBackground(colorScheme);
    final Color appBarBg = pageBg;
    final Color appBarFg = colorScheme.onSurface;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: finalTextTheme,
      scaffoldBackgroundColor: pageBg,
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.6,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        // เลื่อนเนื้อหาลอดใต้แถบแล้วขึ้นเงาบาง ๆ บอกว่ามีของอยู่ข้างใต้
        scrolledUnderElevation: 0.5,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: appBarFg,
          fontSize: 18,
        ),
        iconTheme: IconThemeData(color: appBarFg),
        actionsIconTheme: IconThemeData(color: appBarFg),
        systemOverlayStyle: statusBarStyleFor(appBarBg),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          foregroundColor: colorScheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          shadowColor: colorScheme.primary.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      // chip กรองสถานะมีหลายตัวเรียงกัน ย่อให้ไม่กินพื้นที่การ์ด
      chipTheme: ChipThemeData(
        labelStyle: baseTextTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        showCheckmark: false,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      cardTheme: CardThemeData(
        color: cardColor(colorScheme),
        surfaceTintColor: Colors.transparent,
        shadowColor: colorScheme.shadow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      // ช่องกรอกโค้งเท่ากล่องเล็กอื่น ๆ ในหน้า ([AppSizes.innerRadius])
      // เดิมเป็น 16 เท่าการ์ด ขณะที่ช่องค้นหาที่แต่ละเมนูทำเองเป็น 12
      // ช่องกรอกสองแบบในหน้าเดียวกันเลยโค้งไม่เท่ากัน
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.innerRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.innerRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      // ปุ่มลอยเป็นเขียวปุ่มหลักเหมือนปุ่มอื่น ค่าตั้งต้นของ M3 เป็น
      // primaryContainer (เขียวอ่อน) แต่ละหน้าเลยเคยต้องตั้งสีเองทีละที่
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        // เขียวเดียวกับปุ่มและไอคอนทั้งแอป (ป้ายเป็นตัวหนาอยู่แล้ว อ่านออก)
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: isDark
            ? Colors.grey[400]
            : palette.AppColors.greyNeutral400,
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
      ),
    );
  }
}
