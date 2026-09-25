import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/role_models.dart';
import '../controllers/roles_controller.dart';
import '../widgets/access_layout.dart';
import 'function_permission_screen.dart';

class RoleFunctionsScreen extends StatefulWidget {
  const RoleFunctionsScreen({
    super.key,
    required this.roleId,
    required this.roleName,
    required this.controller,
    required this.canEdit,
  });

  final int roleId;
  final String roleName;
  final RolesController controller;
  final bool canEdit;

  @override
  State<RoleFunctionsScreen> createState() => _RoleFunctionsScreenState();
}

class _RoleFunctionsScreenState extends State<RoleFunctionsScreen> {
  late Future<List<RoleFunctionMatrixItemResponse>> _future;
  Map<int, RoleFunctionMatrixItemResponse> _items =
      <int, RoleFunctionMatrixItemResponse>{};
  Map<int, String> _baseline = <int, String>{};
  ApiException? _error;
  bool _submitting = false;

  bool get _hasChanges {
    if (_items.length != _baseline.length) return true;
    for (final item in _items.values) {
      final state = '${item.isAssigned}:${item.activeKey}';
      if (_baseline[item.functionId] != state) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _future = _loadMatrix();
  }

  Future<List<RoleFunctionMatrixItemResponse>> _loadMatrix() async {
    final result = await widget.controller.getFunctionMatrix(widget.roleId);
    _items = <int, RoleFunctionMatrixItemResponse>{
      for (final item in result) item.functionId: item,
    };
    _baseline = <int, String>{
      for (final item in result)
        item.functionId: '${item.isAssigned}:${item.activeKey}',
    };
    return result;
  }

  void _retry() => setState(() {
    _error = null;
    _future = _loadMatrix();
  });

  void _setPermissions(int functionId, PermissionSet permissions) {
    final current = _items[functionId];
    if (current == null || !widget.canEdit || _submitting) return;
    setState(() {
      _items[functionId] = current.withPermissions(permissions);
      _error = null;
    });
  }

  Future<void> _openPermissionDetail(int functionId) async {
    final item = _items[functionId];
    if (item == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FunctionPermissionScreen(
          item: item,
          canEdit: widget.canEdit && !_submitting,
          onChanged: (permissions) => _setPermissions(functionId, permissions),
        ),
      ),
    );
  }

  void _applyAllPermissions(PermissionSet permissions) {
    if (!widget.canEdit || _submitting) return;
    setState(() {
      for (final current in _items.values.toList()) {
        _items[current.functionId] = permissions.isEmpty
            ? current.withAssignment(false)
            : current.withPermissions(permissions);
      }
      _error = null;
    });
  }

  Future<void> _showBulkActions() async {
    if (!widget.canEdit || _submitting) return;
    final choice = await showAppSheet<_BulkPermissionAction>(
      context: context,
      title: 'Áp dụng cho tất cả chức năng',
      footer: (sheetContext) => AppButton(
        label: 'Hủy',
        variant: AppButtonVariant.ghost,
        onPressed: () => Navigator.pop(sheetContext),
      ),
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thay đổi sẽ ghi đè quyền hiện tại của ${_items.length} chức năng.',
            style: TextStyle(color: sheetContext.palette.text2),
          ),
          const SizedBox(height: 16),
          InsetCard(
            children: [
              NavRow(
                title: 'Cấp toàn quyền',
                subtitle: 'Bật cả 9 quyền cho mọi chức năng',
                onTap: () =>
                    Navigator.pop(sheetContext, _BulkPermissionAction.full),
              ),
              NavRow(
                title: 'Chỉ cho xem',
                subtitle: 'Chỉ bật quyền Xem và D.Sách',
                onTap: () =>
                    Navigator.pop(sheetContext, _BulkPermissionAction.readOnly),
              ),
              NavRow(
                title: 'Bỏ toàn bộ quyền',
                subtitle: 'Tắt hết, vai trò sẽ không vào được mục nào',
                titleStyle: TextStyle(
                  color: sheetContext.palette.danger,
                  fontWeight: FontWeight.w600,
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _BulkPermissionAction.none),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final permissions = switch (choice) {
      _BulkPermissionAction.full => const PermissionSet.full(),
      _BulkPermissionAction.readOnly => const PermissionSet(
        view: true,
        create: false,
        update: false,
        delete: false,
        importData: false,
        exportData: false,
        print: false,
        other: false,
        dSach: true,
      ),
      _BulkPermissionAction.none => const PermissionSet.none(),
    };
    _applyAllPermissions(permissions);
  }

  Future<void> _save() async {
    if (_submitting || !_hasChanges || !widget.canEdit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.controller.setFunctions(widget.roleId, _items.values);
      if (!mounted) return;
      await AppScope.read(context).refreshCurrentSession();
      if (!mounted) return;
      _baseline = <int, String>{
        for (final item in _items.values)
          item.functionId: '${item.isAssigned}:${item.activeKey}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu phân quyền và cập nhật phiên.')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestPop() async {
    if (!_hasChanges || _submitting) {
      Navigator.pop(context, false);
      return;
    }
    final discard = await showAppConfirmDialog(
      context,
      icon: LucideIcons.penOff,
      title: 'Bỏ thay đổi chưa lưu?',
      message: 'Các thay đổi phân quyền sẽ không được lưu.',
      confirmLabel: 'Bỏ thay đổi',
      cancelLabel: 'Ở lại',
    );
    if (discard && mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestPop();
      },
      child: Scaffold(
        // Figma S06: the role name as title, ⋮ opens the bulk sheet (S17).
        appBar: AppBar(
          title: Text(widget.roleName),
          actions: [
            if (widget.canEdit)
              IconButton(
                key: const ValueKey<String>('role-functions-bulk'),
                tooltip: 'Áp dụng cho tất cả chức năng',
                onPressed: _submitting ? null : _showBulkActions,
                icon: const Icon(LucideIcons.ellipsisVertical),
              ),
          ],
        ),
        body: FutureBuilder<List<RoleFunctionMatrixItemResponse>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SkeletonList();
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return LoadErrorView(
                title: 'Không tải được phân quyền',
                message: error is ApiException
                    ? error.message
                    : 'Không thể tải danh sách phân quyền.',
                onRetry: _retry,
              );
            }
            final roots = _buildTree(_items.values);
            if (roots.isEmpty) {
              return const AccessEmptyState(
                icon: LucideIcons.folder,
                title: 'Chưa có chức năng',
                message: 'Chưa có chức năng nào để phân quyền.',
              );
            }
            final groups = roots
                .where((root) => root.children.isNotEmpty)
                .toList(growable: false);
            final loose = roots
                .where((root) => root.children.isEmpty)
                .toList(growable: false);
            final p = context.palette;
            return ListView(
              key: const PageStorageKey<String>('role-function-matrix'),
              padding: accessPagePadding(context, top: 8, bottom: 24),
              children: [
                AccessConstrainedContent(
                  maxWidth: 1080,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!widget.canEdit) ...[
                        Text(
                          'Bạn đang xem ở chế độ chỉ đọc.',
                          style: TextStyle(color: p.text2, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_error != null) ...[
                        ErrorBanner(message: _error!.message),
                        const SizedBox(height: 12),
                      ],
                      for (final group in groups) ...[
                        _GroupHeader(
                          item: _items[group.item.functionId]!,
                          onTap: () =>
                              _openPermissionDetail(group.item.functionId),
                        ),
                        const SizedBox(height: 8),
                        InsetCard(
                          children: [
                            for (final (node, depth) in _descendants(group))
                              _PermissionRow(
                                item: _items[node.item.functionId]!,
                                depth: depth,
                                onTap: () =>
                                    _openPermissionDetail(node.item.functionId),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (loose.isNotEmpty) ...[
                        GroupLabel(groups.isEmpty ? 'Chức năng' : 'Khác'),
                        const SizedBox(height: 8),
                        InsetCard(
                          children: [
                            for (final node in loose)
                              _PermissionRow(
                                item: _items[node.item.functionId]!,
                                depth: 0,
                                onTap: () =>
                                    _openPermissionDetail(node.item.functionId),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        // Drafts only: the save bar appears once something changed.
        bottomNavigationBar: widget.canEdit && (_hasChanges || _submitting)
            ? SafeArea(
                top: false,
                child: Material(
                  color: context.palette.surface,
                  child: Padding(
                    padding: accessPagePadding(context, top: 10, bottom: 12),
                    child: AppButton(
                      key: const ValueKey<String>('role-functions-save'),
                      label: _submitting ? 'Đang lưu...' : 'Lưu phân quyền',
                      icon: LucideIcons.save,
                      loading: _submitting,
                      onPressed: _submitting ? null : _save,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  List<_MatrixNode> _buildTree(Iterable<RoleFunctionMatrixItemResponse> items) {
    final nodes = <int, _MatrixNode>{
      for (final item in items) item.functionId: _MatrixNode(item),
    };
    final roots = <_MatrixNode>[];
    for (final node in nodes.values) {
      final parent = nodes[node.item.parentFunctionId];
      if (parent == null) {
        roots.add(node);
      } else {
        parent.children.add(node);
      }
    }
    void sortNodes(List<_MatrixNode> values) {
      values.sort((a, b) {
        final location = (a.item.location ?? 1 << 30).compareTo(
          b.item.location ?? 1 << 30,
        );
        return location != 0 ? location : a.item.name.compareTo(b.item.name);
      });
      for (final value in values) {
        sortNodes(value.children);
      }
    }

    sortNodes(roots);
    return roots;
  }

  /// Children and grandchildren of [root] with their depth (1 = child).
  List<(_MatrixNode, int)> _descendants(_MatrixNode root) {
    final result = <(_MatrixNode, int)>[];
    void visit(_MatrixNode node, int depth) {
      result.add((node, depth));
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }

    for (final child in root.children) {
      visit(child, 1);
    }
    return result;
  }
}

enum _BulkPermissionAction { full, readOnly, none }

class _MatrixNode {
  _MatrixNode(this.item);

  final RoleFunctionMatrixItemResponse item;
  final List<_MatrixNode> children = <_MatrixNode>[];
}

/// "Toàn quyền" (green), "Chỉ xem", "Chưa cấp quyền" (muted) or the list of
/// granted permissions (D.Sách only when it is the sole one).
(String, Color) _summaryOf(BuildContext context, PermissionSet permissions) {
  final p = context.palette;
  if (permissions.full) return ('Toàn quyền', p.success);
  if (permissions.isEmpty) return ('Chưa cấp quyền', p.text3);
  final granted = PermissionSet.definitions
      .where((definition) => permissions.allows(definition.permission))
      .toList(growable: false);
  final withoutList = granted
      .where((definition) => definition.permission != AccessPermission.dSach)
      .toList(growable: false);
  if (withoutList.length == 1 &&
      withoutList.single.permission == AccessPermission.view) {
    return ('Chỉ xem', p.text2);
  }
  final shown = withoutList.isEmpty ? granted : withoutList;
  return (shown.map((definition) => definition.label).join(' · '), p.text2);
}

/// Group label of a parent function plus its own permission (tap to edit).
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.item, required this.onTap});

  final RoleFunctionMatrixItemResponse item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (summary, color) = _summaryOf(context, item.permissions);
    return Row(
      children: [
        Expanded(child: GroupLabel(item.name)),
        Semantics(
          button: true,
          label: 'Quyền của nhóm ${item.name}: $summary',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: context.palette.text3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.item,
    required this.depth,
    required this.onTap,
  });

  final RoleFunctionMatrixItemResponse item;
  final int depth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (summary, color) = _summaryOf(context, item.permissions);
    final row = NavRow(
      title: item.name,
      subtitle: summary,
      subtitleColor: color,
      onTap: onTap,
    );
    if (depth <= 1) return row;
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * (depth - 1)),
      child: row,
    );
  }
}
