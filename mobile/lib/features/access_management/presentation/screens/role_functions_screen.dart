import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/role_models.dart';
import '../controllers/roles_controller.dart';
import '../widgets/access_layout.dart';

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
  final Set<int> _expanded = <int>{};
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
    final parentIds = result
        .where((item) => item.parentFunctionId == null)
        .map((item) => item.functionId);
    _expanded
      ..clear()
      ..addAll(parentIds);
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

  void _setAssigned(int functionId, bool assigned) {
    final current = _items[functionId];
    if (current == null || !widget.canEdit || _submitting) return;
    setState(() {
      _items[functionId] = current.withAssignment(assigned);
      _error = null;
    });
  }

  void _setVisiblePermissions(
    List<_VisibleMatrixNode> visible,
    PermissionSet permissions,
  ) {
    if (!widget.canEdit || _submitting) return;
    setState(() {
      for (final node in visible) {
        final current = _items[node.item.functionId]!;
        _items[node.item.functionId] = current.withPermissions(permissions);
      }
      _error = null;
    });
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
        const SnackBar(
          content: Text('Đã lưu ma trận quyền và cập nhật phiên.'),
        ),
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
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thay đổi chưa lưu?'),
        content: const Text(
          'Các thay đổi trong ma trận quyền sẽ không được lưu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.canEdit ? 'Ma trận quyền' : 'Xem ma trận quyền'),
          actions: [
            IconButton(
              tooltip: 'Mở tất cả',
              onPressed: () => setState(() {
                _expanded.addAll(
                  _items.values
                      .where(
                        (item) => _items.values.any(
                          (child) => child.parentFunctionId == item.functionId,
                        ),
                      )
                      .map((item) => item.functionId),
                );
              }),
              icon: const Icon(Icons.unfold_more),
            ),
            IconButton(
              tooltip: 'Thu gọn',
              onPressed: () => setState(_expanded.clear),
              icon: const Icon(Icons.unfold_less),
            ),
          ],
        ),
        body: FutureBuilder<List<RoleFunctionMatrixItemResponse>>(
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
                          : 'Không thể tải ma trận quyền.',
                      onRetry: _retry,
                    ),
                  ),
                ),
              );
            }
            final roots = _buildTree(_items.values);
            final visible = _visibleNodes(roots);
            if (visible.isEmpty) {
              return const AccessEmptyState(
                icon: Icons.rule_folder_outlined,
                title: 'Chưa có function',
                message: 'Backend chưa trả function cho ma trận quyền.',
              );
            }
            return Column(
              children: [
                AccessConstrainedContent(
                  maxWidth: 1080,
                  child: Padding(
                    padding: accessPagePadding(context, top: 12, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.roleName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.canEdit
                              ? 'Chọn trạng thái gán và các quyền cho từng function.'
                              : 'Bạn đang xem ở chế độ chỉ đọc.',
                        ),
                        if (widget.canEdit) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : () => _setVisiblePermissions(
                                        visible,
                                        const PermissionSet.full(),
                                      ),
                                icon: const Icon(Icons.done_all),
                                label: const Text('Đầy đủ phần đang hiển thị'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : () => _setVisiblePermissions(
                                        visible,
                                        const PermissionSet.none(),
                                      ),
                                icon: const Icon(Icons.remove_done),
                                label: const Text('Xóa quyền đang hiển thị'),
                              ),
                            ],
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ErrorPanel(message: _error!.message),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    key: const PageStorageKey<String>('role-function-matrix'),
                    padding: accessPagePadding(context, top: 4, bottom: 104),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final node = visible[index];
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: (node.depth * 12).clamp(0, 48).toDouble(),
                            ),
                            child: _PermissionNodeCard(
                              item: _items[node.item.functionId]!,
                              hasChildren: node.hasChildren,
                              expanded: _expanded.contains(
                                node.item.functionId,
                              ),
                              canEdit: widget.canEdit && !_submitting,
                              onExpand: node.hasChildren
                                  ? () => setState(() {
                                      if (!_expanded.add(
                                        node.item.functionId,
                                      )) {
                                        _expanded.remove(node.item.functionId);
                                      }
                                    })
                                  : null,
                              onAssigned: (value) =>
                                  _setAssigned(node.item.functionId, value),
                              onPermission: (permission, value) {
                                final current = _items[node.item.functionId]!;
                                _setPermissions(
                                  node.item.functionId,
                                  current.permissions.withPermission(
                                    permission,
                                    value,
                                  ),
                                );
                              },
                              onFull: (value) => _setPermissions(
                                node.item.functionId,
                                _items[node.item.functionId]!.permissions
                                    .withFull(value),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: widget.canEdit
            ? SafeArea(
                top: false,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: accessPagePadding(context, top: 10, bottom: 12),
                    child: Align(
                      alignment: Alignment.center,
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting || !_hasChanges
                                ? null
                                : _save,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _submitting ? 'Đang lưu...' : 'Lưu ma trận quyền',
                            ),
                          ),
                        ),
                      ),
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

  List<_VisibleMatrixNode> _visibleNodes(List<_MatrixNode> roots) {
    final result = <_VisibleMatrixNode>[];
    void visit(_MatrixNode node, int depth) {
      result.add(
        _VisibleMatrixNode(
          item: node.item,
          depth: depth,
          hasChildren: node.children.isNotEmpty,
        ),
      );
      if (_expanded.contains(node.item.functionId)) {
        for (final child in node.children) {
          visit(child, depth + 1);
        }
      }
    }

    for (final root in roots) {
      visit(root, 0);
    }
    return result;
  }
}

class _MatrixNode {
  _MatrixNode(this.item);

  final RoleFunctionMatrixItemResponse item;
  final List<_MatrixNode> children = <_MatrixNode>[];
}

class _VisibleMatrixNode {
  const _VisibleMatrixNode({
    required this.item,
    required this.depth,
    required this.hasChildren,
  });

  final RoleFunctionMatrixItemResponse item;
  final int depth;
  final bool hasChildren;
}

class _PermissionNodeCard extends StatelessWidget {
  const _PermissionNodeCard({
    required this.item,
    required this.hasChildren,
    required this.expanded,
    required this.canEdit,
    required this.onExpand,
    required this.onAssigned,
    required this.onPermission,
    required this.onFull,
  });

  final RoleFunctionMatrixItemResponse item;
  final bool hasChildren;
  final bool expanded;
  final bool canEdit;
  final VoidCallback? onExpand;
  final ValueChanged<bool> onAssigned;
  final void Function(AccessPermission permission, bool value) onPermission;
  final ValueChanged<bool> onFull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: item.isAssigned
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (hasChildren)
                  IconButton(
                    tooltip: expanded ? 'Thu gọn' : 'Mở rộng',
                    onPressed: onExpand,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.code,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(item.isAssigned ? 'Đã gán' : 'Chưa gán'),
                Switch(
                  value: item.isAssigned,
                  onChanged: canEdit ? onAssigned : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilterChip(
              label: const Text('Đầy đủ'),
              avatar: const Icon(Icons.done_all, size: 18),
              selected: item.permissions.full,
              onSelected: canEdit ? onFull : null,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PermissionSet.definitions
                  .map(
                    (definition) => FilterChip(
                      label: Text(definition.label),
                      selected: item.permissions.allows(definition.permission),
                      onSelected: canEdit
                          ? (value) =>
                                onPermission(definition.permission, value)
                          : null,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
