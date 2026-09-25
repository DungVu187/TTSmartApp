import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/role_models.dart';
import '../controllers/roles_controller.dart';
import '../widgets/access_layout.dart';
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
    final confirmed = await showAppConfirmDialog(
      context,
      icon: nextActive ? LucideIcons.circlePlay : LucideIcons.circlePause,
      title: nextActive ? 'Kích hoạt vai trò?' : 'Ngừng vai trò?',
      message: nextActive
          ? 'Vai trò sẽ có hiệu lực trở lại.'
          : 'Vai trò sẽ ngừng hiệu lực sau khi backend xác nhận.',
      confirmLabel: nextActive ? 'Kích hoạt' : 'Ngừng',
      destructive: !nextActive,
    );
    if (!confirmed || !mounted || _busy) return;
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
    final confirmed = await showAppConfirmDialog(
      context,
      icon: LucideIcons.trash2,
      title: 'Xóa vai trò?',
      message:
          'Xóa vai trò ${role.name}. Backend có thể từ chối nếu vai trò đang bảo vệ quyền quản trị cuối cùng.',
      confirmLabel: 'Xóa',
    );
    if (!confirmed || !mounted || _busy) return;
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
        // Figma S05: no title, the header names the role.
        appBar: AppBar(),
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
                          Row(
                            children: [
                              const IconTile(
                                icon: LucideIcons.shield,
                                tone: AppTone.violet,
                                size: 60,
                                radius: 18,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role.name,
                                      style: TextStyle(
                                        color: context.palette.text1,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      role.code,
                                      style: TextStyle(
                                        color: context.palette.text2,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          InsetGroup(
                            label: 'Phạm vi',
                            children: [
                              NavRow(
                                title: 'Quyền chức năng',
                                subtitle:
                                    '${role.grantedFunctionCount} / ${role.functions.length} chức năng được cấp',
                                onTap: _busy
                                    ? null
                                    : () => _openMatrix(role, canUpdate),
                              ),
                              NavRow(
                                title: 'Người dùng được gán',
                                subtitle: '${role.userCount} người',
                                showChevron: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          InsetGroup(
                            label: 'Thông tin',
                            children: [
                              FieldRow(
                                label: 'Ghi chú',
                                value: role.note?.trim().isNotEmpty == true
                                    ? role.note!
                                    : 'Chưa cập nhật',
                              ),
                            ],
                          ),
                          if (canUpdate || canDelete) ...[
                            const SizedBox(height: 20),
                            InsetCard(
                              dividerIndent: 46,
                              children: [
                                if (canUpdate)
                                  ActionRow(
                                    icon: LucideIcons.pencil,
                                    label: 'Sửa vai trò',
                                    onTap: _busy ? null : () => _edit(role),
                                  ),
                                if (canUpdate)
                                  ActionRow(
                                    onTap: _busy
                                        ? null
                                        : () => _toggleStatus(role),
                                    icon: role.isActive
                                        ? LucideIcons.circlePause
                                        : LucideIcons.circlePlay,
                                    label: role.isActive
                                        ? 'Ngừng hiệu lực'
                                        : 'Kích hoạt',
                                  ),
                                if (canDelete)
                                  ActionRow(
                                    icon: LucideIcons.trash2,
                                    label: 'Xóa vai trò',
                                    destructive: true,
                                    onTap: _busy ? null : () => _delete(role),
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
