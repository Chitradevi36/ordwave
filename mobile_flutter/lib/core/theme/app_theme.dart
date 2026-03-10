import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// App-wide [ThemeData] built from OrderLane Pro design tokens.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: OlColors.primary,
          onPrimary: Colors.white,
          primaryContainer: OlColors.primary50,
          onPrimaryContainer: OlColors.primary900,
          secondary: OlColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: OlColors.secondary50,
          onSecondaryContainer: OlColors.primary900,
          error: OlColors.error,
          onError: Colors.white,
          surface: OlColors.surface,
          onSurface: OlColors.textPrimary,
          surfaceContainerHighest: OlColors.backgroundSubtle,
          onSurfaceVariant: OlColors.textSecondary,
          outline: OlColors.border,
          outlineVariant: OlColors.borderLight,
        ),
        scaffoldBackgroundColor: OlColors.background,
        fontFamily: 'Inter',
        textTheme: OlTextTheme.textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: OlColors.surface,
          foregroundColor: OlColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: OlColors.border,
          titleTextStyle: OlTextTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: OlColors.textPrimary,
          ),
        ),
        cardTheme: CardTheme(
          color: OlColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: OlColors.border),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: OlColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: OlColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: OlColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: OlColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: OlColors.error),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(color: OlColors.textTertiary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: OlColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: OlColors.primary,
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(color: OlColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: OlColors.primary,
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: OlColors.backgroundSubtle,
          selectedColor: OlColors.primary50,
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: OlColors.textSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: OlColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        dividerTheme: DividerThemeData(
          color: OlColors.border,
          thickness: 1,
          space: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: OlColors.surface,
          selectedItemColor: OlColors.primary,
          unselectedItemColor: OlColors.textTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 11,
          ),
        ),
      );
}
