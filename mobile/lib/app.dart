import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'core/app_scope.dart';
import 'core/theme/app_system_ui.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/controllers/app_controller.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/session_recovery_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/shell/presentation/screens/app_shell.dart';

class TTsmartApp extends StatefulWidget {
  const TTsmartApp({
    super.key,
    required this.controller,
    required this.repositories,
    this.initializeOnStart = true,
    this.themeController,
  });

  final AppController controller;
  final AppFeatureRepositories repositories;
  final bool initializeOnStart;

  /// Light / Dark / System choice; defaults to following the phone.
  final ThemeController? themeController;

  @override
  State<TTsmartApp> createState() => _TTsmartAppState();
}

class _TTsmartAppState extends State<TTsmartApp> with WidgetsBindingObserver {
  late final ThemeController _theme =
      widget.themeController ?? ThemeController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initializeOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.initialize();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshCurrentSessionSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _theme]),
      builder: (context, _) => AppScope(
        controller: widget.controller,
        child: ThemeScope(
          controller: _theme,
          child: MaterialApp(
            key: ValueKey(widget.controller.status),
            debugShowCheckedModeBanner: false,
            title: 'TTsmart',
            theme: AppTheme.light,
            // Figma Light / Dark; "Theo hệ thống" follows the phone.
            darkTheme: AppTheme.dark,
            themeMode: _theme.mode,
            builder: (context, child) =>
                AppSystemUi(child: child ?? const SizedBox.shrink()),
            home: switch (widget.controller.status) {
              SessionStatus.initializing => const SplashScreen(),
              SessionStatus.recoveryRequired => const SessionRecoveryScreen(),
              SessionStatus.unauthenticated => const LoginScreen(),
              SessionStatus.authenticated => AppShell(
                repositories: widget.repositories,
              ),
            },
          ),
        ),
      ),
    );
  }
}
