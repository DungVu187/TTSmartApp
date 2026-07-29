import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'core/app_scope.dart';
import 'core/theme/app_theme.dart';
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
  });

  final AppController controller;
  final AppFeatureRepositories repositories;
  final bool initializeOnStart;

  @override
  State<TTsmartApp> createState() => _TTsmartAppState();
}

class _TTsmartAppState extends State<TTsmartApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initializeOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.initialize();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => AppScope(
        controller: widget.controller,
        child: MaterialApp(
          key: ValueKey(widget.controller.status),
          debugShowCheckedModeBanner: false,
          title: 'TTsmart',
          theme: AppTheme.light,
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
    );
  }
}
