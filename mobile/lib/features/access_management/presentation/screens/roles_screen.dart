import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/role_models.dart';
import '../controllers/roles_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_search_filter.dart';
import 'role_detail_screen.dart';
import 'role_form_screen.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late final RolesController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _controller = RolesController(
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
    final created = await Navigator.of(context).push<RoleResponse>(
      MaterialPageRoute(
        builder: (_) => RoleFormScreen(controller: _controller),
      ),
    );
    if (created != null) await _controller.load();
  }

  Future<void> _openDetail(RoleListItemResponse role) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            RoleDetailScreen(roleId: role.id, controller: _controller),
      ),
    );
    if (changed == true) await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.hasPermission(AccessFunctionCodes.roles, AccessPermission.dSach)) {
      return const NoAccessScreen();
    }
    final canCreate = app.hasPermission(
      AccessFunctionCodes.roles,
      AccessPermission.create,
    );
    final canView = app.hasPermission(
      AccessFunctionCodes.roles,
      AccessPermission.view,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân quyền'),
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm',
            onPressed: () => setState(() => _showSearch = !_showSearch),
            icon: const Icon(LucideIcons.search),
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
                    hintText: 'Tìm theo tên hoặc mã vai trò',
                    selectedStatus: _controller.status,
                    onSearchChanged: _onSearchChanged,
                    onStatusChanged: _onStatusChanged,
                  ),
                ),
              ),
            Expanded(child: _buildList(canView, canCreate)),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: _openCreate,
              tooltip: 'Tạo vai trò',
              child: const Icon(LucideIcons.plus),
            )
          : null,
    );
  }

  Widget _buildList(bool canView, bool canCreate) {
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
        icon: LucideIcons.shield,
        emptyTitle: 'Chưa có vai trò nào',
        emptyMessage: 'Tạo vai trò để gom quyền và gán cho người dùng.',
        noMatchTitle: 'Không tìm thấy vai trò',
        createLabel: 'Tạo vai trò',
        onCreate: canCreate ? _openCreate : null,
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 320) {
            _controller.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          key: const PageStorageKey<String>('roles-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: accessPagePadding(context, top: 8, bottom: 104),
          itemCount:
              1 +
              ((_controller.items.length + 19) ~/ 20) +
              (_controller.isLoadingMore || _controller.loadMoreError != null
                  ? 1
                  : 0),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GroupLabel('${_controller.totalCount} vai trò'),
              );
            }
            final groupCount = (_controller.items.length + 19) ~/ 20;
            if (index > groupCount) {
              if (_controller.loadMoreError != null) {
                return ErrorPanel(
                  message: _controller.loadMoreError!.message,
                  onRetry: _controller.loadMore,
                );
              }
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final start = (index - 1) * 20;
            final end = (start + 20).clamp(0, _controller.items.length);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InsetCard(
                    children: [
                      for (final role in _controller.items.sublist(start, end))
                        NavRow(
                          title: role.name,
                          subtitle:
                              '${role.userCount} người dùng · ${role.grantedFunctionCount} chức năng',
                          onTap: canView ? () => _openDetail(role) : null,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
