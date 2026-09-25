import 'package:flutter/material.dart';

/// TTSmart logo. Dark mode uses the white-outlined artwork, which Figma
/// ("01 Login · Dark", "02 Home · Dark") draws taller because the file keeps
/// its margins.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.lightSize,
    required this.darkSize,
    this.alignment = Alignment.center,
  });

  /// Login / splash size (Figma 200×43 light, 210×76 dark).
  const AppLogo.large({super.key})
    : lightSize = const Size(200, 43),
      darkSize = const Size(210, 76),
      alignment = Alignment.center;

  /// Home header size (Figma 122×26 light, 122×44 dark).
  const AppLogo.header({super.key})
    : lightSize = const Size(122, 26),
      darkSize = const Size(122, 44),
      alignment = Alignment.centerLeft;

  final Size lightSize;
  final Size darkSize;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = dark ? darkSize : lightSize;
    return Image.asset(
      dark
          ? 'assets/images/logodarkmode.png'
          : 'assets/images/ttsmart_logo_transparent.png',
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Logo TTSmart',
    );
  }
}
