import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../station_management/data/repositories/station_repository.dart';
import '../../../station_management/data/models/station_models.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/role_models.dart';
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

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<_UserScopeFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserScopeFilterSheet(
        companyRepository: widget.companyRepository,
        stationRepository: widget.stationRepository,
        controller: _controller,
      ),
    );
    if (filters == null) return;
    _controller.setScopeFilters(
      companyId: filters.companyId,
      branchId: filters.branchId,
      withoutRole: filters.withoutRole,
    );
    _controller.setRoleId(filters.roleId);
    await _controller.load();
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
      appBar: AppBar(
        title: const Text('Người dùng'),
        actions: [
          IconButton(
            tooltip: 'Bộ lọc',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible:
                  _controller.companyId != null ||
                  _controller.branchId != null ||
                  _controller.roleId != null ||
                  _controller.withoutRole,
              child: const Icon(Icons.tune),
            ),
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
                  child: _ModernUserListItem(
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

class _ModernUserListItem extends StatelessWidget {
  const _ModernUserListItem({required this.user, required this.onTap});

  final UserResponse user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final contact = _firstNonEmpty(<String?>[user.email, user.phone]);
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
            border: Border.all(color: accent.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: accent.withValues(alpha: 0.15),
                foregroundColor: accent,
                child: Text(
                  _initial(user.displayName),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (onTap != null)
                          Icon(Icons.arrow_forward_rounded, color: accent),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (contact != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        contact,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AccessStatusChip(isActive: user.isActive),
                        _UserRoleMetric(value: '${user.roles.length} vai tro'),
                      ],
                    ),
                  ],
                ),
              ),
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

class _UserRoleMetric extends StatelessWidget {
  const _UserRoleMetric({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.badge_outlined, size: 16),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _UserScopeFilters {
  const _UserScopeFilters({
    required this.companyId,
    required this.branchId,
    required this.roleId,
    required this.withoutRole,
  });

  final int? companyId;
  final int? branchId;
  final int? roleId;
  final bool withoutRole;
}

class _UserScopeFilterSheet extends StatefulWidget {
  const _UserScopeFilterSheet({
    required this.companyRepository,
    required this.stationRepository,
    required this.controller,
  });

  final CompanyRepository companyRepository;
  final StationRepository stationRepository;
  final UsersController controller;

  @override
  State<_UserScopeFilterSheet> createState() => _UserScopeFilterSheetState();
}

class _UserScopeFilterSheetState extends State<_UserScopeFilterSheet> {
  late int? _companyId = widget.controller.companyId;
  late int? _branchId = widget.controller.branchId;
  late int? _roleId = widget.controller.roleId;
  late bool _withoutRole = widget.controller.withoutRole;
  late final Future<_UserFilterOptions> _options = _UserFilterOptions.load(
    widget.companyRepository,
    widget.controller,
  );
  late Future<StationPage> _stationsFuture = widget.stationRepository
      .getStations(pageSize: 100, companyId: _companyId);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FutureBuilder<_UserFilterOptions>(
          future: _options,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final options = snapshot.data!;
            return FutureBuilder<StationPage>(
              future: _stationsFuture,
              builder: (context, stationSnapshot) {
                final stations =
                    stationSnapshot.data?.items ?? const <StationListItem>[];
                if (_branchId != null &&
                    stationSnapshot.hasData &&
                    !stations.any((item) => item.id == _branchId)) {
                  _branchId = null;
                }
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Lọc người dùng',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'user-filter-company-$_companyId',
                        ),
                        initialValue: _companyId,
                        decoration: const InputDecoration(labelText: 'Công ty'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả công ty'),
                          ),
                          for (final company in options.companies)
                            DropdownMenuItem(
                              value: company.id,
                              child: Text(company.displayName),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _companyId = value;
                          _branchId = null;
                          _stationsFuture = widget.stationRepository
                              .getStations(pageSize: 100, companyId: value);
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey<String>('user-filter-branch-$_branchId'),
                        initialValue: _branchId,
                        decoration: const InputDecoration(labelText: 'Trạm'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả trạm'),
                          ),
                          for (final station in stations)
                            DropdownMenuItem(
                              value: station.id,
                              child: Text(station.displayName),
                            ),
                        ],
                        onChanged: (value) => setState(() => _branchId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey<String>('user-filter-role-$_roleId'),
                        initialValue: _roleId,
                        decoration: const InputDecoration(labelText: 'Vai trò'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả vai trò'),
                          ),
                          for (final role in options.roles)
                            DropdownMenuItem(
                              value: role.id,
                              child: Text(role.name),
                            ),
                        ],
                        onChanged: (value) => setState(() => _roleId = value),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _withoutRole,
                        title: const Text('Chỉ người dùng chưa có vai trò'),
                        onChanged: (value) =>
                            setState(() => _withoutRole = value ?? false),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(
                              context,
                              const _UserScopeFilters(
                                companyId: null,
                                branchId: null,
                                roleId: null,
                                withoutRole: false,
                              ),
                            ),
                            child: const Text('Xóa lọc'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.pop(
                              context,
                              _UserScopeFilters(
                                companyId: _companyId,
                                branchId: _branchId,
                                roleId: _roleId,
                                withoutRole: _withoutRole,
                              ),
                            ),
                            child: const Text('Áp dụng'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserFilterOptions {
  const _UserFilterOptions(this.companies, this.roles);

  final List<CompanyResponse> companies;
  final List<RoleListItemResponse> roles;

  static Future<_UserFilterOptions> load(
    CompanyRepository companies,
    UsersController controller,
  ) async {
    final results = await Future.wait<Object>([
      companies.getCompanies(pageSize: 100),
      controller.getAvailableRoles(),
    ]);
    return _UserFilterOptions(
      (results[0] as CompanyPage).items,
      results[1] as List<RoleListItemResponse>,
    );
  }
}

// ignore: unused_element, retained for reference during the legacy UI migration.
class _UserListItem extends StatelessWidget {
  const _UserListItem({required this.user, required this.onTap});

  final UserResponse user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contact = _firstNonEmpty(<String?>[user.email, user.phone]);
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
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(_initial(user.displayName)),
              ),
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
