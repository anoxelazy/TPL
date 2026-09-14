import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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

  static ThemeData _buildTheme(Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: brightness,
    );

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

    // แถบหัวเรื่องเป็นสีเขียวแบรนด์ทุกหน้า ธีมมืดใช้ primaryContainer
    // เพราะ primary ของธีมมืดเป็นเขียวพาสเทลสว่าง จ้าเกินไปเมื่อเต็มแถบ
    final bool isDark = brightness == Brightness.dark;
    final Color appBarBg = isDark
        ? colorScheme.primaryContainer
        : colorScheme.primary;
    final Color appBarFg = isDark
        ? colorScheme.onPrimaryContainer
        : colorScheme.onPrimary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: finalTextTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: appBarFg),
        iconTheme: IconThemeData(color: appBarFg),
        // แถบหัวเรื่องเป็นเขียวเข้ม ไอคอนของเครื่องต้องเป็นสีขาวจึงจะเห็น
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
        color: colorScheme.surface,
        shadowColor: colorScheme.shadow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey[400],
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
