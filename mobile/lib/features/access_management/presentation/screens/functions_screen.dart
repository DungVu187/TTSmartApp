import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/function_models.dart';
import '../../data/models/permission_models.dart';
import '../controllers/functions_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_search_filter.dart';
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
  Timer? _searchDebounce;
  bool _showSearch = false;

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
        title: const Text('Chức năng'),
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm',
            onPressed: () => setState(() => _showSearch = !_showSearch),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            if (_showSearch)
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
            Expanded(child: _buildTree(canView, canCreate)),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: _openCreate,
              tooltip: 'Tạo chức năng',
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildTree(bool canView, bool canCreate) {
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const SkeletonList();
    }
    if (_controller.error != null && _controller.items.isEmpty) {
      return LoadErrorView(
        message: _controller.error!.message,
        onRetry: _controller.load,
      );
    }
    if (_controller.items.isEmpty) {
      return AccessEmptyList(
        onRefresh: _controller.load,
        filtered:
            _controller.search.trim().isNotEmpty || _controller.status != null,
        icon: Icons.account_tree_outlined,
        emptyTitle: 'Chưa có chức năng nào',
        emptyMessage: 'Tạo chức năng để hiển thị trong menu và phân quyền.',
        noMatchTitle: 'Không có chức năng phù hợp',
        createLabel: 'Tạo chức năng',
        onCreate: canCreate ? _openCreate : null,
      );
    }
    final total = _controller.items.expand((item) => item.flatten()).length;
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView(
        key: const PageStorageKey<String>('functions-tree'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: accessPagePadding(context, top: 8, bottom: 104),
        children: [
          AccessConstrainedContent(
            maxWidth: 960,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GroupLabel('$total mục trong menu'),
                const SizedBox(height: 8),
                _FunctionRows(
                  items: _controller.items,
                  canView: canView,
                  onOpen: _openNode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Figma S10: a folder opens its children; a leaf opens its detail.
  Future<void> _openNode(FunctionTreeNodeResponse node, bool canView) async {
    if (!node.isContainer) {
      if (canView) await _openDetail(node);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _FunctionFolderScreen(
          controller: _controller,
          folderId: node.id,
          canView: canView,
          onOpen: _openNode,
          onOpenDetail: _openDetail,
        ),
      ),
    );
  }
}

/// One card of function rows (folder / link icon, count or url, chevron).
class _FunctionRows extends StatelessWidget {
  const _FunctionRows({
    required this.items,
    required this.canView,
    required this.onOpen,
  });

  final List<FunctionTreeNodeResponse> items;
  final bool canView;
  final Future<void> Function(FunctionTreeNodeResponse node, bool canView)
  onOpen;

  @override
  Widget build(BuildContext context) {
    return InsetCard(
      dividerIndent: kLeadingDividerIndent,
      children: [
        for (final item in items)
          NavRow(
            key: ValueKey<String>('function-row-${item.id}'),
            leading: IconTile(
              icon: item.isContainer
                  ? Icons.folder_outlined
                  : Icons.link_rounded,
              tone: item.isContainer ? AppTone.primary : AppTone.neutral,
            ),
            title: item.name,
            subtitle: item.isContainer
                ? '${item.children.length} mục con'
                : (item.url?.isNotEmpty == true ? item.url! : item.code),
            onTap: item.isContainer || canView
                ? () => onOpen(item, canView)
                : null,
          ),
      ],
    );
  }
}

/// Children of one folder, same look as the root list. The ⓘ action opens
/// the folder's own detail (edit / status).
class _FunctionFolderScreen extends StatelessWidget {
  const _FunctionFolderScreen({
    required this.controller,
    required this.folderId,
    required this.canView,
    required this.onOpen,
    required this.onOpenDetail,
  });

  final FunctionsController controller;
  final int folderId;
  final bool canView;
  final Future<void> Function(FunctionTreeNodeResponse node, bool canView)
  onOpen;
  final Future<void> Function(FunctionTreeNodeResponse node) onOpenDetail;

  FunctionTreeNodeResponse? _find(List<FunctionTreeNodeResponse> nodes) {
    for (final node in nodes) {
      if (node.id == folderId) return node;
      final found = _find(node.children);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final folder = _find(controller.items);
        return Scaffold(
          appBar: AppBar(
            title: Text(folder?.name ?? 'Chức năng'),
            actions: [
              if (folder != null && canView)
                IconButton(
                  tooltip: 'Chi tiết mục',
                  onPressed: () => onOpenDetail(folder),
                  icon: const Icon(Icons.info_outline_rounded),
                ),
            ],
          ),
          body: folder == null
              ? const AccessEmptyState(
                  icon: Icons.folder_off_outlined,
                  title: 'Không còn mục này',
                  message: 'Mục đã bị xóa hoặc chuyển chỗ.',
                )
              : ListView(
                  padding: accessPagePadding(context, top: 8, bottom: 32),
                  children: [
                    GroupLabel('${folder.children.length} mục con'),
                    const SizedBox(height: 8),
                    if (folder.children.isEmpty)
                      const AccessEmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'Chưa có mục con',
                        message: 'Thêm chức năng và chọn mục này làm mục cha.',
                      )
                    else
                      _FunctionRows(
                        items: folder.children,
                        canView: canView,
                        onOpen: onOpen,
                      ),
                  ],
                ),
        );
      },
    );
  }
}
