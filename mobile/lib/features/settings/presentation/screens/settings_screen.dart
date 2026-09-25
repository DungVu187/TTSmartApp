import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../auth/presentation/screens/account_screen.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _openChangePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công.')));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: LucideIcons.logOut,
      title: 'Đăng xuất?',
      message: 'Phiên đăng nhập trên thiết bị sẽ được xóa.',
      confirmLabel: 'Đăng xuất',
    );
    if (confirmed && mounted) {
      await AppScope.read(context).logout();
    }
  }

  void _openAccount() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Thông tin tài khoản')),
        body: const SafeArea(child: AccountScreen()),
      ),
    ),
  );

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).session!.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: SafeArea(
        child: ListView(
          children: [
            AppContent(
              maxWidth: 760,
              topPadding: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InsetGroup(
                    label: 'Tài khoản và bảo mật',
                    dividerIndent: 73,
                    children: [
                      NavRow(
                        leading: InitialsAvatar(
                          text: user.displayName,
                          initials: _initial(user.displayName),
                          tone: AppTone.info,
                          size: 48,
                          radius: 14,
                          fontSize: 18,
                        ),
                        title: user.displayName,
                        titleStyle: TextStyle(
                          color: context.palette.text1,
                          fontSize: 17,
                          height: 22 / 17,
                          fontWeight: FontWeight.w700,
                        ),
                        subtitle: 'Thông tin tài khoản',
                        onTap: _openAccount,
                      ),
                      NavRow(
                        leading: const IconTile(
                          icon: LucideIcons.keyRound,
                          tone: AppTone.warning,
                        ),
                        title: 'Đổi mật khẩu',
                        onTap: _openChangePassword,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  InsetCard(
                    children: [
                      ActionRow(
                        icon: LucideIcons.logOut,
                        label: 'Đăng xuất',
                        destructive: true,
                        onTap: _confirmLogout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const InsetGroup(
                    label: 'Ứng dụng',
                    children: [
                      NavRow(
                        leading: IconTile(
                          icon: LucideIcons.info,
                          tone: AppTone.neutral,
                        ),
                        title: 'Phiên bản',
                        value: '1.0.0',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
