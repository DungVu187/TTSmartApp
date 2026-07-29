import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/error_panel.dart';

class SessionRecoveryScreen extends StatelessWidget {
  const SessionRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chưa thể xác minh phiên đăng nhập',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ErrorPanel(
                    message:
                        controller.startupError?.message ??
                        'Không thể kết nối máy chủ.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: controller.initialize,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: controller.discardStoredSession,
                    child: const Text('Xóa phiên và về đăng nhập'),
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
