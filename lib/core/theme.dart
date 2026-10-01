import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized design tokens for the app.
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
    primaryContainer: isDark ? AppColors.dark3 : AppColors.greenSoft,
    onPrimaryContainer: isDark ? AppColors.green : AppColors.greenDark,
    secondary: AppColors.green,
    onSecondary: isDark ? AppColors.dark : Colors.white,
    secondaryContainer: isDark ? AppColors.dark3 : AppColors.greenSoft,
    onSecondaryContainer: isDark ? AppColors.green : AppColors.greenDark,
    tertiary: AppColors.blue,
    onTertiary: Colors.white,
    tertiaryContainer:
        isDark ? const Color(0xFF172A38) : const Color(0xFFEAF5FD),
    onTertiaryContainer:
        isDark ? const Color(0xFF9ED4FA) : const Color(0xFF1769A0),
    error: AppColors.red,
    onError: Colors.white,
    errorContainer: isDark ? const Color(0xFF3A1F20) : const Color(0xFFFFEBEB),
    onErrorContainer:
        isDark ? const Color(0xFFFFB4B4) : const Color(0xFF9C2C2C),
    surface: isDark ? AppColors.darkSurface : AppColors.surface,
    onSurface: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    surfaceContainerHighest: isDark ? AppColors.dark3 : AppColors.surfaceSoft,
    onSurfaceVariant:
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
    outline: isDark ? AppColors.darkBorder : AppColors.border,
    outlineVariant: isDark ? const Color(0xFF202A26) : const Color(0xFFEEF1F2),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? Colors.white : AppColors.dark,
    onInverseSurface: isDark ? AppColors.dark : Colors.white,
    inversePrimary: AppColors.greenDark,
  );

  final border = isDark ? AppColors.darkBorder : AppColors.border;
  final hint = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

  // ---------- Typography: Plus Jakarta Sans ----------
  final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    var text = base.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  text = text.copyWith(
    displayLarge: text.displayLarge?.copyWith(
        fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5),
    displayMedium: text.displayMedium?.copyWith(
        fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
    headlineLarge: text.headlineLarge?.copyWith(
        fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6),
    headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
    titleLarge:
        text.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium:
        text.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
    titleSmall:
        text.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
    bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
    bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
    bodySmall: text.bodySmall?.copyWith(fontSize: 12, height: 1.35),
    labelLarge:
        text.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
  );

  OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? AppColors.dark : AppColors.bg,
    canvasColor: isDark ? AppColors.dark : AppColors.bg,
    textTheme: text,

    // Smooth slide transition on every platform (incl. Chrome on Windows).
    // pageTransitionsTheme: const PageTransitionsTheme(
    //   builders: {
    //     TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    //     TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    //     TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    //     TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    //     TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    //   },
    // ),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: border),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder(border),
      enabledBorder: inputBorder(border),
      focusedBorder: inputBorder(AppColors.green, 1.6),
      errorBorder: inputBorder(AppColors.red),
      focusedErrorBorder: inputBorder(AppColors.red, 1.6),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: hint),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),

    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.green,
      selectionHandleColor: AppColors.green,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? AppColors.green : AppColors.greenDark,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.green,
      foregroundColor: AppColors.dark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    chipTheme: ChipThemeData(
      showCheckmark: false,
      backgroundColor: scheme.surface,
      selectedColor: isDark ? const Color(0xFF234A39) : AppColors.greenSoft,
      side: BorderSide(color: border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.green,
      linearTrackColor: scheme.outlineVariant,
    ),

    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),

    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: isDark ? AppColors.dark3 : AppColors.dark,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}