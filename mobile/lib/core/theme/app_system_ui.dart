import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/app_palette.dart';

/// Status / navigation bar style for a palette.
///
/// The status bar is transparent with icons that contrast the canvas (Android
/// reads [SystemUiOverlayStyle.statusBarIconBrightness], iOS reads
/// [SystemUiOverlayStyle.statusBarBrightness]). The Android navigation bar
/// takes [navigationBar] (canvas by default), so it blends with whatever sits
/// at the bottom of the screen instead of the default black bar.
SystemUiOverlayStyle appSystemUiStyle(
  AppPalette p,
  Brightness brightness, {
  Color? navigationBar,
}) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: navigationBar ?? p.canvas,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Applies [appSystemUiStyle] to the area it covers. Flutter reads the region
/// at the top of the screen for the status bar and the one at the bottom for
/// the Android navigation bar, so bottom bars and sheets wrap themselves with
/// their own [navigationBar] colour.
class AppSystemUi extends StatelessWidget {
  const AppSystemUi({super.key, required this.child, this.navigationBar});

  final Widget child;
  final Color? navigationBar;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: appSystemUiStyle(
      context.palette,
      Theme.of(context).brightness,
      navigationBar: navigationBar,
    ),
    child: child,
  );
}
