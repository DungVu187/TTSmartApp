import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../auth/presentation/screens/account_screen.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initialize();
    });
  }

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Phiên đăng nhập trên thiết bị sẽ được xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AppScope.read(context).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => ListView(
            children: [
              AppContent(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsSection(
                      title: 'Thông báo',
                      children: [
                        SwitchListTile(
                          value: widget.controller.notificationsEnabled,
                          onChanged: widget.controller.isLoading
                              ? null
                              : widget.controller.setNotificationsEnabled,
                          secondary: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                          title: const Text('Nhận thông báo'),
                          subtitle: const Text(
                            'Bản FE hiện lưu trạng thái trên bộ nhớ. Quyền hệ thống sẽ nối sau.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SettingsSection(
                      title: 'Tài khoản và bảo mật',
                      children: [
                        ListTile(
                          minTileHeight: 64,
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Thông tin tài khoản'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: const Text('Thông tin tài khoản'),
                                ),
                                body: const SafeArea(child: AccountScreen()),
                              ),
                            ),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          minTileHeight: 64,
                          leading: const Icon(Icons.password_outlined),
                          title: const Text('Đổi mật khẩu'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openChangePassword,
                        ),
                        const Divider(),
                        ListTile(
                          minTileHeight: 64,
                          leading: Icon(
                            Icons.logout,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            'Đăng xuất',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: _confirmLogout,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SettingsSection(
                      title: 'Ứng dụng',
                      children: [
                        ListTile(
                          minTileHeight: 64,
                          leading: Icon(Icons.info_outline),
                          title: Text('Phiên bản'),
                          trailing: Text('1.0.0'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
