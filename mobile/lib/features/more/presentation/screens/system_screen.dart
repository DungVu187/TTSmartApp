import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app_dependencies.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../access_management/data/repositories/access_management_repository.dart';
import '../../../shell/presentation/module_registry.dart';

/// Figma S01: "Hệ thống" tab with one row per access module and its count
/// ("147 tài khoản", "12 vai trò", "34 mục trong menu").
class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key, required this.repositories});

  final AppFeatureRepositories repositories;

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  final Map<String, int> _counts = <String, int>{};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_loadCounts());
  }

  /// Counts are a nice-to-have: a failed request keeps the description.
  Future<void> _loadCounts() async {
    final app = AppScope.read(context);
    final repository = app.accessManagementRepository;
    final keys = visibleAccessModules(app).map((module) => module.keyName);
    Future<void> load(String key, Future<int> Function() count) async {
      try {
        final value = await count();
        if (mounted) setState(() => _counts[key] = value);
      } catch (_) {}
    }

    await Future.wait([
      if (keys.contains('users')) load('users', () => _userCount(repository)),
      if (keys.contains('roles'))
        load('roles', () async {
          final page = await repository.getRoles(pageSize: 1);
          return page.totalCount;
        }),
      if (keys.contains('functions'))
        load('functions', () async {
          final functions = await repository.getFunctions();
          return functions.length;
        }),
    ]);
  }

  Future<int> _userCount(AccessManagementRepository repository) async {
    final page = await repository.getUsers(pageSize: 1);
    return page.totalCount;
  }

  String? _countLabel(String keyName) {
    final count = _counts[keyName];
    if (count == null) return null;
    return switch (keyName) {
      'users' => '$count tài khoản',
      'roles' => '$count vai trò',
      'functions' => '$count mục trong menu',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final modules = visibleAccessModules(controller);
    return Column(
      children: [
        const SafeArea(
          bottom: false,
          child: TabTitleBar(title: 'Hệ thống', large: true),
        ),
        Expanded(
          child: modules.isEmpty
              ? const SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: AppEmptyState(
                    icon: LucideIcons.lock,
                    title: 'Không có chức năng quản trị',
                    message:
                        'Tài khoản hiện tại chưa được cấp quyền quản trị hệ thống.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCounts,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 11, 16, 24),
                    children: [
                      InsetCard(
                        dividerIndent: kLeadingDividerIndent,
                        children: [
                          for (final module in modules)
                            NavRow(
                              key: ValueKey<String>('system-${module.keyName}'),
                              title: module.label,
                              subtitle:
                                  _countLabel(module.keyName) ??
                                  module.description,
                              leading: IconTile(
                                icon: _systemIcon(module.keyName, module.icon),
                                tone: _systemTone(module.keyName),
                              ),
                              onTap: () async {
                                await openAccessModule(
                                  context,
                                  module,
                                  widget.repositories,
                                );
                                if (mounted) unawaited(_loadCounts());
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

IconData _systemIcon(String keyName, IconData fallback) => switch (keyName) {
  'users' => LucideIcons.users,
  'roles' => LucideIcons.shield,
  'functions' => LucideIcons.gitBranch,
  _ => fallback,
};

AppTone _systemTone(String keyName) => switch (keyName) {
  'users' => AppTone.info,
  'roles' => AppTone.violet,
  'functions' => AppTone.success,
  _ => AppTone.primary,
};
