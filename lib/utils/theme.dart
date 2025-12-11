import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData getLightTheme() {
    final ColorScheme lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    );

    final TextTheme baseTextTheme = GoogleFonts.notoSansThaiTextTheme();
    final TextTheme enhancedTextTheme = baseTextTheme.copyWith(
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

    return ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      textTheme: enhancedTextTheme.copyWith(
        titleLarge: enhancedTextTheme.titleLarge?.copyWith(color: lightScheme.onSurface),
        titleMedium: enhancedTextTheme.titleMedium?.copyWith(color: lightScheme.onSurface),
        titleSmall: enhancedTextTheme.titleSmall?.copyWith(color: lightScheme.onSurface),
        bodyLarge: enhancedTextTheme.bodyLarge?.copyWith(color: lightScheme.onSurface),
        bodyMedium: enhancedTextTheme.bodyMedium?.copyWith(color: lightScheme.onSurface),
        bodySmall: enhancedTextTheme.bodySmall?.copyWith(color: lightScheme.onSurface),
        labelLarge: enhancedTextTheme.labelLarge?.copyWith(color: lightScheme.onSurface),
        labelMedium: enhancedTextTheme.labelMedium?.copyWith(color: lightScheme.onSurface),
        labelSmall: enhancedTextTheme.labelSmall?.copyWith(color: lightScheme.onSurface),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: enhancedTextTheme.titleMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: lightScheme.onSurface,
        ),
        contentTextStyle: enhancedTextTheme.bodyLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightScheme.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: enhancedTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          foregroundColor: lightScheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightScheme.surface,
        foregroundColor: lightScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: lightScheme.onPrimary,
          backgroundColor: lightScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          elevation: 4,
          shadowColor: lightScheme.shadow,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: lightScheme.onPrimary,
          backgroundColor: lightScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          elevation: 4,
          shadowColor: lightScheme.shadow,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(color: lightScheme.primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      iconTheme: IconThemeData(
        color: lightScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: lightScheme.surface,
        shadowColor: lightScheme.shadow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: lightScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: lightScheme.onSurfaceVariant),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: lightScheme.primary,
        unselectedItemColor: lightScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        backgroundColor: lightScheme.surface,
      ),
      scaffoldBackgroundColor: lightScheme.surface,
    );
  }

  static ThemeData getDarkTheme() {
    final ColorScheme darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
    );

    final TextTheme baseTextTheme = GoogleFonts.notoSansThaiTextTheme();
    final TextTheme enhancedTextTheme = baseTextTheme.copyWith(
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

    return ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      textTheme: enhancedTextTheme.copyWith(
        titleLarge: enhancedTextTheme.titleLarge?.copyWith(color: darkScheme.onSurface),
        titleMedium: enhancedTextTheme.titleMedium?.copyWith(color: darkScheme.onSurface),
        titleSmall: enhancedTextTheme.titleSmall?.copyWith(color: darkScheme.onSurface),
        bodyLarge: enhancedTextTheme.bodyLarge?.copyWith(color: darkScheme.onSurface),
        bodyMedium: enhancedTextTheme.bodyMedium?.copyWith(color: darkScheme.onSurface),
        bodySmall: enhancedTextTheme.bodySmall?.copyWith(color: darkScheme.onSurface),
        labelLarge: enhancedTextTheme.labelLarge?.copyWith(color: darkScheme.onSurface),
        labelMedium: enhancedTextTheme.labelMedium?.copyWith(color: darkScheme.onSurface),
        labelSmall: enhancedTextTheme.labelSmall?.copyWith(color: darkScheme.onSurface),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: enhancedTextTheme.titleMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: darkScheme.onSurface,
        ),
        contentTextStyle: enhancedTextTheme.bodyLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkScheme.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: enhancedTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          foregroundColor: darkScheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkScheme.surface,
        foregroundColor: darkScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: darkScheme.onPrimary,
          backgroundColor: darkScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          elevation: 4,
          shadowColor: darkScheme.shadow,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: darkScheme.onPrimary,
          backgroundColor: darkScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          elevation: 4,
          shadowColor: darkScheme.shadow,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkScheme.primary,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(color: darkScheme.primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: darkScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: darkScheme.onSurfaceVariant),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: darkScheme.primary,
        unselectedItemColor: darkScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        backgroundColor: darkScheme.surface,
      ),
      iconTheme: IconThemeData(
        color: darkScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: darkScheme.surface,
        shadowColor: darkScheme.shadow,
        elevation: 4,
      ),
      scaffoldBackgroundColor: darkScheme.surface,
    );
  }
}