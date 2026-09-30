import 'package:flutter/material.dart';

/// Centralized design tokens for the app.
///
/// The existing color names are kept so current screens that reference
/// AppColors.* continue to compile.
class AppColors {
  // Brand
  static const green = Color(0xFF39D98A);
  static const greenDark = Color(0xFF20B875);
  static const greenSoft = Color(0xFFE7FAF0);

  // Status
  static const red = Color(0xFFEF5350);
  static const blue = Color(0xFF42A5F5);
  static const purple = Color(0xFF8B6FE8);
  static const orange = Color(0xFFFFA726);

  // Light surfaces
  static const bg = Color(0xFFF5F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF8FAFA);
  static const border = Color(0xFFE4E9EC);

  // Dark surfaces
  static const dark = Color(0xFF111715);
  static const dark2 = Color(0xFF17211D);
  static const dark3 = Color(0xFF1E2A25);
  static const darkSurface = Color(0xFF151D1A);
  static const darkBorder = Color(0xFF29352F);

  // Text
  static const textPrimary = Color(0xFF17201C);
  static const textSecondary = Color(0xFF6D7873);
  static const textMuted = Color(0xFF9AA49F);

  static const darkTextPrimary = Color(0xFFF3F7F5);
  static const darkTextSecondary = Color(0xFFB5C0BA);
  static const darkTextMuted = Color(0xFF7F8B85);
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme(
    brightness: brightness,

    primary: AppColors.green,
    onPrimary: isDark ? AppColors.dark : Colors.white,

    primaryContainer:
        isDark ? AppColors.dark3 : AppColors.greenSoft,

    onPrimaryContainer:
        isDark ? AppColors.green : AppColors.greenDark,

    secondary: AppColors.green,
    onSecondary: isDark ? AppColors.dark : Colors.white,

    secondaryContainer:
        isDark ? AppColors.dark3 : AppColors.greenSoft,

    onSecondaryContainer:
        isDark ? AppColors.green : AppColors.greenDark,

    tertiary: AppColors.blue,
    onTertiary: Colors.white,

    tertiaryContainer: isDark
        ? const Color(0xFF172A38)
        : const Color(0xFFEAF5FD),

    onTertiaryContainer: isDark
        ? const Color(0xFF9ED4FA)
        : const Color(0xFF1769A0),

    error: AppColors.red,
    onError: Colors.white,

    errorContainer: isDark
        ? const Color(0xFF3A1F20)
        : const Color(0xFFFFEBEB),

    onErrorContainer: isDark
        ? const Color(0xFFFFB4B4)
        : const Color(0xFF9C2C2C),

    surface:
        isDark ? AppColors.darkSurface : AppColors.surface,

    onSurface:
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,

    surfaceContainerHighest:
        isDark ? AppColors.dark3 : AppColors.surfaceSoft,

    onSurfaceVariant:
        isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary,

    outline:
        isDark ? AppColors.darkBorder : AppColors.border,

    outlineVariant:
        isDark
            ? const Color(0xFF202A26)
            : const Color(0xFFEEF1F2),

    shadow: Colors.black,
    scrim: Colors.black,

    inverseSurface:
        isDark ? Colors.white : AppColors.dark,

    onInverseSurface:
        isDark ? AppColors.dark : Colors.white,

    inversePrimary: AppColors.greenDark,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,

    scaffoldBackgroundColor:
        isDark ? AppColors.dark : AppColors.bg,

    canvasColor:
        isDark ? AppColors.dark : AppColors.bg,

    // ─────────────────────────────────────
    // Typography
    // ─────────────────────────────────────

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),

      displayMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),

      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),

      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),

      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),

      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),

      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.45,
      ),

      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
      ),

      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.35,
      ),

      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),

    // ─────────────────────────────────────
    // Cards
    // ─────────────────────────────────────

    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,

      color:
          isDark ? AppColors.darkSurface : AppColors.surface,

      surfaceTintColor: Colors.transparent,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              isDark
                  ? AppColors.darkBorder
                  : AppColors.border,
        ),
      ),
    ),

    // ─────────────────────────────────────
    // Text Fields
    // ─────────────────────────────────────

    inputDecorationTheme: InputDecorationTheme(
      filled: true,

      fillColor:
          isDark
              ? AppColors.darkSurface
              : AppColors.surface,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color:
              isDark
                  ? AppColors.darkBorder
                  : AppColors.border,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color:
              isDark
                  ? AppColors.darkBorder
                  : AppColors.border,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.green,
          width: 1.5,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.red,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.red,
          width: 1.5,
        ),
      ),

      labelStyle: TextStyle(
        color:
            isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
      ),

      hintStyle: TextStyle(
        color:
            isDark
                ? AppColors.darkTextMuted
                : AppColors.textMuted,
      ),
    ),

    // ─────────────────────────────────────
    // Elevated Buttons
    // ─────────────────────────────────────

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,

        minimumSize: const Size(0, 50),

        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ),

        backgroundColor: AppColors.green,
        foregroundColor: AppColors.dark,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),

        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // ─────────────────────────────────────
    // Filled Buttons
    // ─────────────────────────────────────

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),

        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ),

        backgroundColor: AppColors.green,
        foregroundColor: AppColors.dark,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),

        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // ─────────────────────────────────────
    // Outlined Buttons
    // ─────────────────────────────────────

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),

        padding: const EdgeInsets.symmetric(
          horizontal: 18,
        ),

        foregroundColor:
            isDark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,

        side: BorderSide(
          color:
              isDark
                  ? AppColors.darkBorder
                  : AppColors.border,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    // ─────────────────────────────────────
    // Text Buttons
    // ─────────────────────────────────────

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.greenDark,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // ─────────────────────────────────────
    // Navigation Bar
    // ─────────────────────────────────────

    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,

      backgroundColor:
          isDark
              ? AppColors.darkSurface
              : AppColors.surface,

      indicatorColor:
          isDark
              ? const Color(0xFF234A39)
              : AppColors.greenSoft,

      labelTextStyle:
          WidgetStateProperty.resolveWith(
        (states) {
          final selected =
              states.contains(WidgetState.selected);

          return TextStyle(
            fontSize: 11,
            fontWeight:
                selected
                    ? FontWeight.w700
                    : FontWeight.w500,

            color:
                selected
                    ? (isDark
                        ? AppColors.green
                        : AppColors.greenDark)
                    : (isDark
                        ? AppColors.darkTextMuted
                        : AppColors.textMuted),
          );
        },
      ),

      iconTheme:
          WidgetStateProperty.resolveWith(
        (states) {
          final selected =
              states.contains(WidgetState.selected);

          return IconThemeData(
            size: 22,

            color:
                selected
                    ? (isDark
                        ? AppColors.green
                        : AppColors.greenDark)
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
          );
        },
      ),
    ),

    // ─────────────────────────────────────
    // Dialogs
    // ─────────────────────────────────────

    dialogTheme: DialogThemeData(
      elevation: 0,

      backgroundColor:
          isDark
              ? AppColors.darkSurface
              : AppColors.surface,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),

    // ─────────────────────────────────────
    // Bottom Sheets
    // ─────────────────────────────────────

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor:
          isDark
              ? AppColors.darkSurface
              : AppColors.surface,

      modalBackgroundColor:
          isDark
              ? AppColors.darkSurface
              : AppColors.surface,

      elevation: 0,

      showDragHandle: true,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
    ),

    // ─────────────────────────────────────
    // Divider
    // ─────────────────────────────────────

    dividerTheme: DividerThemeData(
      color:
          isDark
              ? AppColors.darkBorder
              : AppColors.border,

      thickness: 1,
      space: 1,
    ),

    // ─────────────────────────────────────
    // Snackbars
    // ─────────────────────────────────────

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,

      backgroundColor:
          isDark
              ? AppColors.dark3
              : AppColors.dark,

      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}