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
        title: const Text('Function & menu'),
        actions: [
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
            icon: const Icon(Icons.unfold_more),
          ),
          IconButton(
            tooltip: 'Thu gọn',
            onPressed: () => setState(_expanded.clear),
            icon: const Icon(Icons.unfold_less),
          ),
        ],
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
                  hintText: 'Tìm theo mã, tên hoặc URL function',
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
              label: const Text('Tạo function'),
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
              title: 'Không có function',
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
                child: _FunctionTreeItem(
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

class _VisibleFunctionNode {
  const _VisibleFunctionNode({required this.item, required this.depth});

  final FunctionTreeNodeResponse item;
  final int depth;
}

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
      color: theme.colorScheme.surface,
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
                            label: Text('${item.children.length} con'),
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
