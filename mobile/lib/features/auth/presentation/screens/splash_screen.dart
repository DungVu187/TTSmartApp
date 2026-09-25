import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        // Figma A01 centres the group ~20pt above the middle of the screen.
        minimum: const EdgeInsets.only(bottom: 87),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo.large(),
              const SizedBox(height: 40),
              SizedBox.square(
                dimension: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  backgroundColor: p.surfaceMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Đang kiểm tra phiên đăng nhập...',
                style: TextStyle(
                  color: p.text2,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
