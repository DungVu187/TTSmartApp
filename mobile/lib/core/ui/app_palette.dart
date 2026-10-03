import 'package:flutter/material.dart';

/// Colour tokens of the redesign. Values mirror the `Theme` variable
/// collection in the Figma file (Light / Dark modes), so a token change there
/// maps 1:1 to a change here.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.onPrimary,
    required this.secondary,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.fieldBorder,
    required this.inputBorder,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.info,
    required this.infoBg,
    required this.violet,
    required this.violetBg,
    required this.scrim,
  });

  final Color primary;
  final Color primaryContainer;

  /// Text / icons on [primaryContainer] (tags, selected options), ≥4.5:1.
  final Color onPrimaryContainer;
  final Color onPrimary;
  final Color secondary;
  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color border;

  /// Input outline of the wide (web-parity) filter bars.
  final Color fieldBorder;

  /// Outline of text fields, selects, search boxes and unselected options
  /// (Figma `color/input-border`, ≥3:1 against surface and canvas).
  final Color inputBorder;
  final Color text1;
  final Color text2;
  final Color text3;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;
  final Color info;
  final Color infoBg;
  final Color violet;
  final Color violetBg;
  final Color scrim;

  static const light = AppPalette(
    primary: Color(0xFF2563EB),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1D4ED8),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF0F766E),
    canvas: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F4F9),
    border: Color(0xFFE6EAF0),
    fieldBorder: Color(0xFFCBD5E1),
    inputBorder: Color(0xFF7C8AA0),
    text1: Color(0xFF0F172A),
    text2: Color(0xFF475569),
    text3: Color(0xFF5B6B80),
    success: Color(0xFF15803D),
    successBg: Color(0xFFECFDF5),
    warning: Color(0xFFB45309),
    warningBg: Color(0xFFFFFBEB),
    danger: Color(0xFFB91C1C),
    dangerBg: Color(0xFFFEF2F2),
    info: Color(0xFF0369A1),
    infoBg: Color(0xFFF0F9FF),
    violet: Color(0xFF7C3AED),
    violetBg: Color(0xFFF3E8FF),
    scrim: Color(0xFF0F172A),
  );

  static const dark = AppPalette(
    primary: Color(0xFF60A5FA),
    primaryContainer: Color(0xFF1C3272),
    onPrimaryContainer: Color(0xFF93C5FD),
    onPrimary: Color(0xFF0B1220),
    secondary: Color(0xFF2DD4BF),
    canvas: Color(0xFF0B1220),
    surface: Color(0xFF131C2E),
    surfaceMuted: Color(0xFF1B2538),
    border: Color(0xFF253049),
    fieldBorder: Color(0xFF334155),
    inputBorder: Color(0xFF5B6B85),
    text1: Color(0xFFE5EAF3),
    text2: Color(0xFF94A3B8),
    text3: Color(0xFF8391A7),
    success: Color(0xFF4ADE80),
    successBg: Color(0xFF0F2A1E),
    warning: Color(0xFFFBBF24),
    warningBg: Color(0xFF2A2210),
    danger: Color(0xFFF87171),
    dangerBg: Color(0xFF2A1414),
    info: Color(0xFF38BDF8),
    infoBg: Color(0xFF0F2436),
    violet: Color(0xFFC4B5FD),
    violetBg: Color(0xFF2A1F4A),
    scrim: Color(0xFF000000),
  );

  /// Foreground / background pair for a semantic tone.
  (Color, Color) tone(AppTone tone) => switch (tone) {
    AppTone.primary => (onPrimaryContainer, primaryContainer),
    AppTone.success => (success, successBg),
    AppTone.warning => (warning, warningBg),
    AppTone.danger => (danger, dangerBg),
    AppTone.info => (info, infoBg),
    AppTone.violet => (violet, violetBg),
    AppTone.neutral => (text2, surfaceMuted),
  };

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: mix(primary, other.primary),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      onPrimaryContainer: mix(onPrimaryContainer, other.onPrimaryContainer),
      onPrimary: mix(onPrimary, other.onPrimary),
      secondary: mix(secondary, other.secondary),
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      border: mix(border, other.border),
      fieldBorder: mix(fieldBorder, other.fieldBorder),
      inputBorder: mix(inputBorder, other.inputBorder),
      text1: mix(text1, other.text1),
      text2: mix(text2, other.text2),
      text3: mix(text3, other.text3),
      success: mix(success, other.success),
      successBg: mix(successBg, other.successBg),
      warning: mix(warning, other.warning),
      warningBg: mix(warningBg, other.warningBg),
      danger: mix(danger, other.danger),
      dangerBg: mix(dangerBg, other.dangerBg),
      info: mix(info, other.info),
      infoBg: mix(infoBg, other.infoBg),
      violet: mix(violet, other.violet),
      violetBg: mix(violetBg, other.violetBg),
      scrim: mix(scrim, other.scrim),
    );
  }
}

enum AppTone { primary, success, warning, danger, info, violet, neutral }

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
