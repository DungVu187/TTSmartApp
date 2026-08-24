import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/role_models.dart';
import '../controllers/roles_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_search_filter.dart';
import '../widgets/access_status_chip.dart';
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
      appBar: AppBar(title: const Text('Vai trò')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
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
            Expanded(child: _buildList(canView)),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_moderator_outlined),
              label: const Text('Tạo vai trò'),
            )
          : null,
    );
  }

  Widget _buildList(bool canView) {
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
              icon: Icons.admin_panel_settings_outlined,
              title: 'Không tìm thấy vai trò',
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
        child: ListView.separated(
          key: const PageStorageKey<String>('roles-list'),
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
            final role = _controller.items[index];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _ModernRoleListItem(
                  role: role,
                  onTap: canView ? () => _openDetail(role) : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModernRoleListItem extends StatelessWidget {
  const _ModernRoleListItem({required this.role, required this.onTap});

  final RoleListItemResponse role;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.tertiary;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface,
                Color.alphaBlend(
                  accent.withValues(alpha: 0.09),
                  theme.colorScheme.surface,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: accent.withValues(alpha: 0.16),
                    foregroundColor: accent,
                    child: Text(
                      role.name.trim().isEmpty ? '?' : role.name[0],
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          role.code.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            letterSpacing: 0.8,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_rounded, color: accent),
                ],
              ),
              if (role.note?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  role.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AccessStatusChip(isActive: role.isActive),
                  _RoleMetric(
                    icon: Icons.people_alt_outlined,
                    value: '${role.userCount}',
                  ),
                  _RoleMetric(
                    icon: Icons.account_tree_outlined,
                    value: '${role.functionCount}',
                  ),
                  _RoleMetric(
                    icon: Icons.verified_outlined,
                    value: '${role.grantedFunctionCount}',
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

class _RoleMetric extends StatelessWidget {
  const _RoleMetric({required this.icon, required this.value});
  final IconData icon;
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
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

// ignore: unused_element, retained for reference during the legacy UI migration.
class _RoleListItem extends StatelessWidget {
  const _RoleListItem({required this.role, required this.onTap});

  final RoleListItemResponse role;
  final VoidCallback? onTap;

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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    foregroundColor: theme.colorScheme.onTertiaryContainer,
                    child: Text(role.name.trim().isEmpty ? '?' : role.name[0]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          role.code,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right),
                ],
              ),
              if (role.note?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(role.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AccessStatusChip(isActive: role.isActive),
                  Chip(label: Text('${role.userCount} người dùng')),
                  Chip(label: Text('${role.functionCount} chức năng')),
                  Chip(
                    label: Text('${role.grantedFunctionCount} quyền đang bật'),
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
