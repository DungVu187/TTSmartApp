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
    final tree = visibleAccessFunctionTree(controller);
    if (tree.isNotEmpty) {
      return ListView(
        key: const PageStorageKey<String>('system-function-tree'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final node in tree)
            _FunctionMenuTreeTile(node: node, repositories: repositories),
        ],
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

class _FunctionMenuTreeTile extends StatelessWidget {
  const _FunctionMenuTreeTile({required this.node, required this.repositories});

  final FunctionMenuNode node;
  final AppFeatureRepositories repositories;

  @override
  Widget build(BuildContext context) {
    final module = node.module;
    final icon = module?.icon ?? Icons.folder_outlined;
    if (node.children.isNotEmpty) {
      return ExpansionTile(
        key: ValueKey<String>('system-function-node-${node.function.id}'),
        leading: Icon(icon),
        title: Text(node.function.name),
        children: [
          if (module != null)
            ListTile(
              leading: Icon(module.icon),
              title: Text(module.label),
              onTap: () => openAccessModule(context, module, repositories),
            ),
          for (final child in node.children)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _FunctionMenuTreeTile(
                node: child,
                repositories: repositories,
              ),
            ),
        ],
      );
    }
    return ListTile(
      key: ValueKey<String>('system-function-node-${node.function.id}'),
      leading: Icon(icon),
      title: Text(module?.label ?? node.function.name),
      enabled: module != null,
      onTap: module == null
          ? null
          : () => openAccessModule(context, module, repositories),
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
