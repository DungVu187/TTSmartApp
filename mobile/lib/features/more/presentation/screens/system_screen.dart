import 'package:flutter/material.dart';

import '../../../../app_dependencies.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../shell/presentation/module_registry.dart';
import '../widgets/module_panel_grid.dart';

class SystemScreen extends StatelessWidget {
  const SystemScreen({super.key, required this.repositories});

  final AppFeatureRepositories repositories;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final modules = visibleAccessModules(controller);
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
            icon: module.icon,
            accent: _systemAccent(module.keyName),
            backgroundColor: _systemBackground(module.keyName),
            onTap: () => openAccessModule(context, module, repositories),
          ),
      ],
    );
  }
}

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
