import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/role_models.dart';
import '../controllers/roles_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_status_chip.dart';
import 'role_form_screen.dart';
import 'role_functions_screen.dart';

class RoleDetailScreen extends StatefulWidget {
  const RoleDetailScreen({
    super.key,
    required this.roleId,
    required this.controller,
  });

  final int roleId;
  final RolesController controller;

  @override
  State<RoleDetailScreen> createState() => _RoleDetailScreenState();
}

class _RoleDetailScreenState extends State<RoleDetailScreen> {
  late Future<RoleResponse> _future;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.getById(widget.roleId);
  }

  void _reload() => setState(() {
    _future = widget.controller.getById(widget.roleId);
  });

  void _reloadChanged() => setState(() {
    _changed = true;
    _future = widget.controller.getById(widget.roleId);
  });

  Future<void> _edit(RoleResponse role) async {
    final updated = await Navigator.of(context).push<RoleResponse>(
      MaterialPageRoute(
        builder: (_) =>
            RoleFormScreen(controller: widget.controller, existingRole: role),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _changed = true;
        _future = Future<RoleResponse>.value(updated);
      });
    }
  }

  Future<void> _openMatrix(RoleResponse role, bool canEdit) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoleFunctionsScreen(
          roleId: role.id,
          roleName: role.name,
          controller: widget.controller,
          canEdit: canEdit,
        ),
      ),
    );
    if (changed == true && mounted) _reloadChanged();
  }

  Future<void> _toggleStatus(RoleResponse role) async {
    final nextActive = !role.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextActive ? 'Kích hoạt vai trò?' : 'Ngừng vai trò?'),
        content: Text(
          nextActive
              ? 'Vai trò sẽ có hiệu lực trở lại.'
              : 'Vai trò sẽ ngừng hiệu lực sau khi backend xác nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(nextActive ? 'Kích hoạt' : 'Ngừng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.controller.setActive(role.id, nextActive);
      if (mounted) {
        setState(() {
          _changed = true;
          _future = Future<RoleResponse>.value(updated);
        });
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RoleResponse role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa vai trò?'),
        content: Text(
          'Xóa vai trò ${role.name}. Backend có thể từ chối nếu vai trò đang bảo vệ quyền quản trị cuối cùng.',
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
      await widget.controller.delete(role.id);
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
    if (!app.hasPermission(AccessFunctionCodes.roles, AccessPermission.view)) {
      return const NoAccessScreen();
    }
    final canUpdate = app.hasPermission(
      AccessFunctionCodes.roles,
      AccessPermission.update,
    );
    final canDelete = app.hasPermission(
      AccessFunctionCodes.roles,
      AccessPermission.delete,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Chi tiết vai trò')),
        body: FutureBuilder<RoleResponse>(
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
                          : 'Không thể tải thông tin vai trò.',
                      onRetry: _reload,
                    ),
                  ),
                ),
              );
            }
            final role = snapshot.data!;
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  role.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(role.code),
                                if (role.note?.trim().isNotEmpty == true) ...[
                                  const SizedBox(height: 10),
                                  Text(role.note!),
                                ],
                                const SizedBox(height: 12),
                                AccessStatusChip(isActive: role.isActive),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          AccessSection(
                            title: 'Tổng quan',
                            icon: Icons.analytics_outlined,
                            child: Column(
                              children: [
                                AccessInfoRow(
                                  label: 'Người dùng',
                                  value: '${role.userCount}',
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Số chức năng',
                                  value: '${role.functions.length}',
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Số quyền đang bật',
                                  value: '${role.grantedFunctionCount}',
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Cấp quản lý',
                                  value:
                                      role.levelRole?.toString() ?? 'Chưa đặt',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _busy
                                  ? null
                                  : () => _openMatrix(role, canUpdate),
                              icon: const Icon(Icons.rule_folder_outlined),
                              label: Text(
                                canUpdate
                                    ? 'Chỉnh quyền chức năng'
                                    : 'Xem quyền chức năng',
                              ),
                            ),
                          ),
                          if (canUpdate || canDelete) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (canUpdate)
                                  OutlinedButton.icon(
                                    onPressed: _busy ? null : () => _edit(role),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Cập nhật'),
                                  ),
                                if (canUpdate)
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _toggleStatus(role),
                                    icon: Icon(
                                      role.isActive
                                          ? Icons.pause_circle_outline
                                          : Icons.play_circle_outline,
                                    ),
                                    label: Text(
                                      role.isActive
                                          ? 'Ngừng hiệu lực'
                                          : 'Kích hoạt',
                                    ),
                                  ),
                                if (canDelete)
                                  TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _delete(role),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Xóa'),
                                  ),
                              ],
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
}
