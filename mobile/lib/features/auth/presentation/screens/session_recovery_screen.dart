import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/error_panel.dart';

class SessionRecoveryScreen extends StatelessWidget {
  const SessionRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 66),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: IconTile(
                      icon: Icons.cloud_off_outlined,
                      tone: AppTone.danger,
                      size: 78,
                      radius: 39,
                      iconSize: 33,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chưa thể xác minh phiên đăng nhập',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 19,
                      height: 25 / 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ErrorPanel(
                    message:
                        controller.startupError?.message ??
                        'Không thể kết nối máy chủ.',
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    onPressed: controller.initialize,
                    icon: Icons.refresh_rounded,
                    label: 'Thử lại',
                  ),
                  const SizedBox(height: 4),
                  AppButton(
                    variant: AppButtonVariant.text,
                    onPressed: controller.discardStoredSession,
                    label: 'Xóa phiên và về đăng nhập',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
