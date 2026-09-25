import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ui/app_palette.dart';

/// Legacy colour constants still referenced by screens that have not moved to
/// [AppPalette] yet. New UI must read colours from `context.palette`.
abstract final class AppColors {
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandTeal = Color(0xFF087F70);
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE5E7EB);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color success = Color(0xFF16845B);
  static const Color warning = Color(0xFFB76A00);
  static const Color danger = Color(0xFFC43D4B);
}

class AppTheme {
  /// Family for every text style of the theme: the bundled Inter (Figma
  /// font). `null` = platform font. Change before the first theme is built.
  static String? fontFamily = 'Inter';

  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: p.primary,
          brightness: brightness,
        ).copyWith(
          primary: p.primary,
          onPrimary: p.onPrimary,
          primaryContainer: p.primaryContainer,
          onPrimaryContainer: isLight ? p.primary : p.text1,
          secondary: p.secondary,
          secondaryContainer: p.infoBg,
          onSecondaryContainer: p.info,
          surface: p.surface,
          onSurface: p.text1,
          onSurfaceVariant: p.text2,
          surfaceContainerLowest: p.surface,
          surfaceContainerLow: p.surface,
          surfaceContainer: p.surfaceMuted,
          surfaceContainerHigh: p.surfaceMuted,
          surfaceContainerHighest: p.surfaceMuted,
          outline: p.text3,
          outlineVariant: p.border,
          error: p.danger,
          onError: p.onPrimary,
          errorContainer: p.dangerBg,
          onErrorContainer: p.danger,
          scrim: p.scrim,
        );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: p.border),
    );
    final buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.canvas,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[p],
      // Back / close buttons drawn by Flutter use the Lucide glyphs too.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(LucideIcons.arrowLeft),
        closeButtonIconBuilder: (_) => const Icon(LucideIcons.x),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        // Figma app bar: back button then the title at x = 52. Every
        // AppBar in the app is on a pushed route, so it always has a leading.
        leadingWidth: 52,
        titleSpacing: 0,
        backgroundColor: p.canvas,
        foregroundColor: p.text1,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: p.text1, size: 22),
        actionsIconTheme: IconThemeData(color: p.text1, size: 22),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.text1,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: p.text3,
          fontWeight: FontWeight.w500,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: p.text1,
          side: BorderSide(color: p.border, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.primary : p.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceMuted,
        circularTrackColor: p.surfaceMuted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: p.surface,
        elevation: 0,
        indicatorColor: p.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            color: selected ? p.primary : p.text2,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 3,
        highlightElevation: 5,
        sizeConstraints: const BoxConstraints.tightFor(width: 54, height: 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconSize: 26,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
