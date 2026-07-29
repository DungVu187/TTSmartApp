import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/user_models.dart';
import '../controllers/users_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_status_chip.dart';
import 'reset_password_dialog.dart';
import 'user_form_screen.dart';
import 'user_roles_screen.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  final int userId;
  final UsersController controller;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late Future<UserResponse> _future;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.getById(widget.userId);
  }

  void _reload() => setState(() {
    _future = widget.controller.getById(widget.userId);
  });

  void _setUser(UserResponse user) {
    setState(() {
      _future = Future<UserResponse>.value(user);
      _changed = true;
    });
  }

  Future<void> _edit(UserResponse user) async {
    final updated = await Navigator.of(context).push<UserResponse>(
      MaterialPageRoute(
        builder: (_) =>
            UserFormScreen(controller: widget.controller, existingUser: user),
      ),
    );
    if (updated != null && mounted) _setUser(updated);
  }

  Future<void> _manageRoles(UserResponse user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            UserRolesScreen(controller: widget.controller, user: user),
      ),
    );
    if (changed == true && mounted) _reloadChanged();
  }

  void _reloadChanged() {
    setState(() {
      _changed = true;
      _future = widget.controller.getById(widget.userId);
    });
  }

  Future<void> _toggleStatus(UserResponse user) async {
    final nextActive = !user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextActive ? 'Mở lại tài khoản?' : 'Khóa tài khoản?'),
        content: Text(
          nextActive
              ? 'Người dùng sẽ có thể đăng nhập lại theo quyền hiện tại.'
              : 'Người dùng sẽ không thể tiếp tục đăng nhập.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(nextActive ? 'Mở lại' : 'Khóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.controller.setActive(user.id, nextActive);
      if (mounted) {
        _setUser(updated);
        _showMessage(
          nextActive ? 'Đã mở lại tài khoản.' : 'Đã khóa tài khoản.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword(UserResponse user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt lại mật khẩu?'),
        content: Text('Tạo mật khẩu mới cho ${user.displayName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ResetPasswordDialog(controller: widget.controller, userId: user.id),
    );
    if (changed == true && mounted) {
      _showMessage('Đã đặt lại mật khẩu.');
    }
  }

  Future<void> _delete(UserResponse user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa người dùng?'),
        content: Text(
          'Xóa ${user.displayName} khỏi danh sách hiệu lực. Thao tác này cần được backend xác nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.delete(user.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.hasPermission(AccessFunctionCodes.users, AccessPermission.view)) {
      return const NoAccessScreen();
    }
    final canUpdate = app.hasPermission(
      AccessFunctionCodes.users,
      AccessPermission.update,
    );
    final canDelete = app.hasPermission(
      AccessFunctionCodes.users,
      AccessPermission.delete,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Chi tiết người dùng')),
        body: FutureBuilder<UserResponse>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ErrorPanel(
                      message: error is ApiException
                          ? error.message
                          : 'Không thể tải thông tin người dùng.',
                      onRetry: _reload,
                    ),
                  ),
                ),
              );
            }
            final user = snapshot.data!;
            final isCurrentUser = app.session?.user.id == user.id;
            return Stack(
              children: [
                ListView(
                  padding: accessPagePadding(context, bottom: 32),
                  children: [
                    AccessConstrainedContent(
                      maxWidth: 820,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProfileHeader(user: user),
                          const SizedBox(height: 20),
                          AccessSection(
                            title: 'Tài khoản',
                            icon: Icons.manage_accounts_outlined,
                            child: Column(
                              children: [
                                AccessInfoRow(
                                  label: 'Tên đăng nhập',
                                  value: user.userName,
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Mã',
                                  value: _display(user.code),
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Ngày tạo',
                                  value: _date(user.createdAtUtc),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          AccessSection(
                            title: 'Liên hệ',
                            icon: Icons.contact_mail_outlined,
                            child: Column(
                              children: [
                                AccessInfoRow(
                                  label: 'Email',
                                  value: _display(user.email),
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Điện thoại',
                                  value: _display(user.phone),
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Địa chỉ',
                                  value: _display(user.address),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          AccessSection(
                            title: 'Tổ chức',
                            icon: Icons.apartment_outlined,
                            child: Column(
                              children: [
                                AccessInfoRow(
                                  label: 'Công ty',
                                  value: _number(user.companyId),
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Phòng ban',
                                  value: _number(user.departmentId),
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Chức vụ',
                                  value: _number(user.positionId),
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Đơn vị',
                                  value: _number(user.unitId),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          AccessSection(
                            title: 'Vai trò',
                            icon: Icons.badge_outlined,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: user.roles.isEmpty
                                  ? const Text('Chưa được gán vai trò.')
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: user.roles
                                          .map(
                                            (role) => Chip(
                                              label: Text(role.name),
                                              avatar: role.isActive
                                                  ? const Icon(
                                                      Icons.verified_outlined,
                                                      size: 18,
                                                    )
                                                  : const Icon(
                                                      Icons.pause_outlined,
                                                      size: 18,
                                                    ),
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                            ),
                          ),
                          if (canUpdate || canDelete) ...[
                            const SizedBox(height: 24),
                            _UserActions(
                              user: user,
                              busy: _busy,
                              canUpdate: canUpdate,
                              canDelete: canDelete,
                              canToggleStatus: !isCurrentUser || !user.isActive,
                              onEdit: () => _edit(user),
                              onRoles: () => _manageRoles(user),
                              onResetPassword: () => _resetPassword(user),
                              onToggleStatus: () => _toggleStatus(user),
                              onDelete: () => _delete(user),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (_busy) const LinearProgressIndicator(),
              ],
            );
          },
        ),
      ),
    );
  }

  String _display(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa cập nhật'
        : normalized;
  }

  String _number(int? value) => value?.toString() ?? 'Chưa cập nhật';

  String _date(DateTime? value) =>
      value == null ? 'Chưa cập nhật' : formatLocalDateTime(value);
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserResponse user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 34, child: Text(_initial(user.displayName))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text('@${user.userName}'),
                const SizedBox(height: 8),
                AccessStatusChip(isActive: user.isActive),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '?' : normalized[0].toUpperCase();
  }
}

class _UserActions extends StatelessWidget {
  const _UserActions({
    required this.user,
    required this.busy,
    required this.canUpdate,
    required this.canDelete,
    required this.canToggleStatus,
    required this.onEdit,
    required this.onRoles,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final UserResponse user;
  final bool busy;
  final bool canUpdate;
  final bool canDelete;
  final bool canToggleStatus;
  final VoidCallback onEdit;
  final VoidCallback onRoles;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (canUpdate)
          OutlinedButton.icon(
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Cập nhật'),
          ),
        if (canUpdate)
          OutlinedButton.icon(
            onPressed: busy ? null : onRoles,
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Gán vai trò'),
          ),
        if (canUpdate)
          OutlinedButton.icon(
            onPressed: busy ? null : onResetPassword,
            icon: const Icon(Icons.password_outlined),
            label: const Text('Đặt lại mật khẩu'),
          ),
        if (canUpdate)
          Tooltip(
            message: canToggleStatus
                ? ''
                : 'Không thể tự khóa tài khoản đang đăng nhập.',
            child: FilledButton.tonalIcon(
              onPressed: busy || !canToggleStatus ? null : onToggleStatus,
              icon: Icon(
                user.isActive ? Icons.lock_outline : Icons.lock_open_outlined,
              ),
              label: Text(user.isActive ? 'Khóa tài khoản' : 'Mở lại'),
            ),
          ),
        if (canDelete)
          TextButton.icon(
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Xóa'),
          ),
      ],
    );
  }
}
