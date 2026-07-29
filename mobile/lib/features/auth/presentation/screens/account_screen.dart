import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../access_management/presentation/widgets/access_layout.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await AppScope.read(context).refreshCurrentSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật thông tin tài khoản.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session!;
    final user = session.user;
    final roleNames = session.roles.map((role) => role.name).join(', ');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: accessPagePadding(context, bottom: 32),
        children: [
          AccessConstrainedContent(
            maxWidth: 760,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        child: Text(
                          _initial(user.displayName),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.displayName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('@${user.userName}'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AccessSection(
                  title: 'Thông tin tài khoản',
                  icon: Icons.person_outline,
                  child: Column(
                    children: [
                      AccessInfoRow(label: 'Mã', value: _display(user.code)),
                      const Divider(height: 1),
                      AccessInfoRow(
                        label: 'Email',
                        value: _display(user.email),
                      ),
                      const Divider(height: 1),
                      AccessInfoRow(
                        label: 'Điện thoại',
                        value: _display(user.phone),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AccessSection(
                  title: 'Vai trò',
                  icon: Icons.admin_panel_settings_outlined,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        roleNames.isEmpty ? 'Chưa được gán vai trò' : roleNames,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Cập nhật phiên và quyền'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _display(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa cập nhật'
        : normalized;
  }

  String _initial(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '?' : normalized[0].toUpperCase();
  }
}
