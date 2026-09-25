import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';

/// Figma S15: lock ring, "Bạn không có quyền truy cập" and who to ask.
class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key, this.title = 'Không có quyền'});

  /// App bar title, e.g. the module the user tried to open.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: StateView(
              icon: LucideIcons.lock,
              title: 'Bạn không có quyền truy cập',
              message:
                  'Tài khoản hiện tại chưa được cấp quyền dùng chức năng này. '
                  'Liên hệ quản trị viên để được cấp quyền.',
            ),
          ),
        ),
      ),
    );
  }
}
