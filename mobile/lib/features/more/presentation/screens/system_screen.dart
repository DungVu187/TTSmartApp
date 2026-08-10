import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../shell/presentation/module_registry.dart';
import '../widgets/module_panel_grid.dart';

class SystemScreen extends StatelessWidget {
  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = visibleAccessModules(AppScope.of(context))
      ..sort(
        (first, second) =>
            _moduleOrder(first.keyName).compareTo(_moduleOrder(second.keyName)),
      );
    if (modules.isEmpty) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: AppEmptyState(
          icon: Icons.lock_outline,
          title: 'Không có chức năng quản trị',
          message: 'Tài khoản hiện tại chưa được cấp quyền quản trị hệ thống.',
        ),
      );
    }
    return ModulePanelGrid(
      compactColumnCount: 4,
      items: [
        for (final module in modules)
          ModulePanelItem(
            label: module.label,
            icon: _systemIcon(module.keyName, module.icon),
            accent: _systemAccent(module.keyName),
            backgroundColor: _systemBackground(module.keyName),
            onTap: () => openAccessModule(context, module),
          ),
      ],
    );
  }

  int _moduleOrder(String keyName) => switch (keyName) {
    'functions' => 0,
    'roles' => 1,
    'users' => 2,
    _ => 3,
  };
}

IconData _systemIcon(String keyName, IconData fallback) => switch (keyName) {
  'functions' => Icons.settings_outlined,
  'roles' => Icons.admin_panel_settings_outlined,
  'users' => Icons.person_outline,
  _ => fallback,
};

Color _systemAccent(String keyName) => switch (keyName) {
  'functions' => const Color(0xFF2563EB),
  'roles' => const Color(0xFF047857),
  'users' => const Color(0xFF7C3AED),
  _ => const Color(0xFF2563EB),
};

Color _systemBackground(String keyName) => switch (keyName) {
  'functions' => const Color(0xFFEEF2FF),
  'roles' => const Color(0xFFECFDF5),
  'users' => const Color(0xFFF3E8FF),
  _ => const Color(0xFFEEF2FF),
};
