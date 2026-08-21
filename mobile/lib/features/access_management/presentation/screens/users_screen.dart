import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../station_management/data/repositories/station_repository.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/user_models.dart';
import '../controllers/users_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_search_filter.dart';
import '../widgets/access_status_chip.dart';
import 'user_detail_screen.dart';
import 'user_form_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.companyRepository,
    required this.stationRepository,
  });

  final CompanyRepository companyRepository;
  final StationRepository stationRepository;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final UsersController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _controller = UsersController(
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
    final created = await Navigator.of(context).push<UserResponse>(
      MaterialPageRoute(
        builder: (_) => UserFormScreen(
          controller: _controller,
          companyRepository: widget.companyRepository,
          stationRepository: widget.stationRepository,
        ),
      ),
    );
    if (created != null) await _controller.load();
  }

  Future<void> _openDetail(UserResponse user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserDetailScreen(
          userId: user.id,
          controller: _controller,
          companyRepository: widget.companyRepository,
          stationRepository: widget.stationRepository,
        ),
      ),
    );
    if (changed == true) await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.hasPermission(AccessFunctionCodes.users, AccessPermission.dSach)) {
      return const NoAccessScreen();
    }
    final canCreate = app.hasPermission(
      AccessFunctionCodes.users,
      AccessPermission.create,
    );
    final canView = app.hasPermission(
      AccessFunctionCodes.users,
      AccessPermission.view,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Người dùng')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            AccessConstrainedContent(
              child: Padding(
                padding: accessPagePadding(context, top: 12, bottom: 8),
                child: AccessSearchFilter(
                  controller: _searchController,
                  hintText: 'Tìm theo tên, mã, email hoặc số điện thoại',
                  selectedStatus: _controller.status,
                  onSearchChanged: _onSearchChanged,
                  onStatusChanged: _onStatusChanged,
                ),
              ),
            ),
            Expanded(child: _buildList(canView: canView)),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Tạo người dùng'),
            )
          : null,
    );
  }

  Widget _buildList({required bool canView}) {
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
              icon: Icons.person_search_outlined,
              title: 'Không tìm thấy người dùng',
              message: 'Thử thay đổi từ khóa hoặc bộ lọc trạng thái.',
            ),
          ],
        ),
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
        child: LayoutBuilder(
          builder: (context, constraints) => ListView.separated(
            key: const PageStorageKey<String>('users-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: accessPagePadding(context, top: 8, bottom: 104),
            itemCount:
                _controller.items.length +
                (_controller.isLoadingMore || _controller.loadMoreError != null
                    ? 1
                    : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _controller.items.length) {
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
              final user = _controller.items[index];
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: _UserListItem(
                    user: user,
                    onTap: canView ? () => _openDetail(user) : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  const _UserListItem({required this.user, required this.onTap});

  final UserResponse user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contact = _firstNonEmpty(<String?>[user.email, user.phone]);
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
              CircleAvatar(radius: 24, child: Text(_initial(user.displayName))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.code?.trim().isNotEmpty == true
                          ? '${user.userName} • ${user.code}'
                          : user.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (contact != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        contact,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AccessStatusChip(isActive: user.isActive),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.badge_outlined, size: 18),
                          label: Text('${user.roles.length} vai trò'),
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

  String _initial(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '?' : normalized[0].toUpperCase();
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }
    return null;
  }
}
