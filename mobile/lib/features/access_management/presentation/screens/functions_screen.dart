import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/function_models.dart';
import '../../data/models/permission_models.dart';
import '../controllers/functions_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_search_filter.dart';
import '../widgets/access_status_chip.dart';
import 'function_detail_screen.dart';
import 'function_form_screen.dart';

class FunctionsScreen extends StatefulWidget {
  const FunctionsScreen({super.key});

  @override
  State<FunctionsScreen> createState() => _FunctionsScreenState();
}

class _FunctionsScreenState extends State<FunctionsScreen> {
  late final FunctionsController _controller;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expanded = <int>{};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _controller = FunctionsController(
      AppScope.read(context).accessManagementRepository,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _controller.setSearch(value);
      _controller.load();
    });
  }

  void _onStatusChanged(int? value) {
    _controller.setStatus(value);
    _controller.load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<FunctionResponse>(
      MaterialPageRoute(
        builder: (_) => FunctionFormScreen(controller: _controller),
      ),
    );
    if (created != null) await _controller.load();
  }

  Future<void> _openDetail(FunctionTreeNodeResponse function) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FunctionDetailScreen(
          functionId: function.id,
          controller: _controller,
        ),
      ),
    );
    if (changed == true) await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.hasPermission(
      AccessFunctionCodes.functions,
      AccessPermission.dSach,
    )) {
      return const NoAccessScreen();
    }
    final canCreate = app.hasPermission(
      AccessFunctionCodes.functions,
      AccessPermission.create,
    );
    final canView = app.hasPermission(
      AccessFunctionCodes.functions,
      AccessPermission.view,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chức năng & menu'),
        /* actions: [
          IconButton(
            tooltip: 'Mở tất cả',
            onPressed: () => setState(() {
              _expanded.addAll(
                _controller.items
                    .expand((item) => item.flatten())
                    .where((item) => item.isContainer)
                    .map((item) => item.id),
              );
            }),
            icon: const Icon(Icons.expand_more),
          ),
          IconButton(
            tooltip: 'Thu gọn',
            onPressed: () => setState(_expanded.clear),
            icon: const Icon(Icons.expand_less),
          ),
        ], */
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            AccessConstrainedContent(
              child: Padding(
                padding: accessPagePadding(context, top: 12, bottom: 8),
                child: AccessSearchFilter(
                  controller: _searchController,
                  hintText: 'Tìm theo tên, mã hoặc đường dẫn',
                  selectedStatus: _controller.status,
                  onSearchChanged: _onSearchChanged,
                  onStatusChanged: _onStatusChanged,
                ),
              ),
            ),
            Expanded(child: _buildTree(canView)),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Tạo chức năng'),
            )
          : null,
    );
  }

  Widget _buildTree(bool canView) {
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null && _controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ErrorPanel(
              message: _controller.error!.message,
              onRetry: _controller.load,
            ),
          ),
        ),
      );
    }
    if (_controller.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            AccessEmptyState(
              icon: Icons.account_tree_outlined,
              title: 'Không có chức năng',
              message: 'Thử thay đổi từ khóa hoặc bộ lọc trạng thái.',
            ),
          ],
        ),
      );
    }
    final visible = _visibleNodes(_controller.items);
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView.separated(
        key: const PageStorageKey<String>('functions-tree'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: accessPagePadding(context, top: 8, bottom: 104),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final node = visible[index];
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: EdgeInsets.only(
                  left: (node.depth * 14).clamp(0, 56).toDouble(),
                ),
                child: _ModernFunctionTreeItem(
                  item: node.item,
                  onTap: canView ? () => _openDetail(node.item) : null,
                  expanded: _expanded.contains(node.item.id),
                  onExpand: node.item.isContainer
                      ? () => setState(() {
                          if (!_expanded.add(node.item.id)) {
                            _expanded.remove(node.item.id);
                          }
                        })
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_VisibleFunctionNode> _visibleNodes(
    List<FunctionTreeNodeResponse> roots,
  ) {
    final result = <_VisibleFunctionNode>[];
    void visit(FunctionTreeNodeResponse item, int depth) {
      result.add(_VisibleFunctionNode(item: item, depth: depth));
      if (_expanded.contains(item.id)) {
        for (final child in item.children) {
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

class _ModernFunctionTreeItem extends StatelessWidget {
  const _ModernFunctionTreeItem({
    required this.item,
    required this.onTap,
    required this.expanded,
    required this.onExpand,
  });

  final FunctionTreeNodeResponse item;
  final VoidCallback? onTap;
  final bool expanded;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = item.isContainer
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface,
                Color.alphaBlend(
                  accent.withValues(alpha: 0.08),
                  theme.colorScheme.surface,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      item.isContainer
                          ? Icons.folder_rounded
                          : Icons.hub_rounded,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.code.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            letterSpacing: 0.8,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.isContainer)
                    IconButton(
                      tooltip: expanded ? 'Thu gon' : 'Mo rong',
                      onPressed: onExpand,
                      style: IconButton.styleFrom(
                        backgroundColor: accent.withValues(alpha: 0.10),
                      ),
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    )
                  else if (onTap != null)
                    Icon(Icons.arrow_forward_rounded, color: accent),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: AccessStatusChip(isActive: item.isActive)),
                  if (item.isContainer) ...[
                    const SizedBox(width: 8),
                    _FunctionMetric(
                      label: 'Con',
                      value: '${item.children.length}',
                    ),
                  ],
                  const SizedBox(width: 8),
                  _FunctionMetric(
                    label: 'Vai trò',
                    value: '${item.assignedRoleCount}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FunctionMetric extends StatelessWidget {
  const _FunctionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.labelMedium,
          children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            TextSpan(
              text: label,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibleFunctionNode {
  const _VisibleFunctionNode({required this.item, required this.depth});

  final FunctionTreeNodeResponse item;
  final int depth;
}

// ignore: unused_element, retained for reference during the legacy UI migration.
class _FunctionTreeItem extends StatelessWidget {
  const _FunctionTreeItem({
    required this.item,
    required this.onTap,
    required this.expanded,
    required this.onExpand,
  });

  final FunctionTreeNodeResponse item;
  final VoidCallback? onTap;
  final bool expanded;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 1,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (item.isContainer)
                IconButton(
                  tooltip: expanded ? 'Thu gọn' : 'Mở rộng',
                  onPressed: onExpand,
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                )
              else
                const SizedBox(width: 48),
              CircleAvatar(
                radius: 20,
                backgroundColor: item.isContainer
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.primaryContainer,
                foregroundColor: item.isContainer
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onPrimaryContainer,
                child: Icon(
                  item.isContainer
                      ? Icons.folder_outlined
                      : Icons.webhook_outlined,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.code,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AccessStatusChip(isActive: item.isActive),
                        if (item.isContainer)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${item.children.length} mục con'),
                          ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${item.assignedRoleCount} vai trò'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
