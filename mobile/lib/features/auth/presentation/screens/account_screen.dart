import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/app_content.dart';

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
    final roles = session.roles.toList();
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppContent(
            maxWidth: 760,
            topPadding: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    InitialsAvatar(
                      text: user.displayName,
                      initials: user.displayName.trim().isEmpty
                          ? '?'
                          : user.displayName
                                .trim()
                                .characters
                                .first
                                .toUpperCase(),
                      tone: AppTone.info,
                      size: 60,
                      radius: 18,
                      fontSize: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: TextStyle(
                              color: p.text1,
                              fontSize: 19,
                              height: 24 / 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '@${user.userName}',
                            style: TextStyle(
                              color: p.text2,
                              fontSize: 15,
                              height: 19 / 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                InsetGroup(
                  label: 'Thông tin tài khoản',
                  children: [
                    FieldRow(label: 'Mã', value: _display(user.code)),
                    FieldRow(label: 'Email', value: _display(user.email)),
                    FieldRow(label: 'Điện thoại', value: _display(user.phone)),
                  ],
                ),
                const SizedBox(height: 20),
                InsetGroup(
                  label: 'Vai trò',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(13),
                      child: roles.isEmpty
                          ? Text(
                              'Chưa được gán vai trò',
                              style: TextStyle(color: p.text2),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < roles.length; i++)
                                  AppTag(
                                    label: roles[i].name,
                                    tone: i.isEven
                                        ? AppTone.violet
                                        : AppTone.info,
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppButton(
                  variant: AppButtonVariant.outline,
                  onPressed: _refreshing ? null : _refresh,
                  loading: _refreshing,
                  icon: Icons.refresh_rounded,
                  label: 'Cập nhật phiên và quyền',
                ),
                const SizedBox(height: 10),
                Text(
                  'Hoặc kéo xuống để làm mới',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.text3,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
}
