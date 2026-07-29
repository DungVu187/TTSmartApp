import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../shell/presentation/module_registry.dart';

class SystemScreen extends StatelessWidget {
  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = visibleAccessModules(AppScope.of(context));
    return Scaffold(
      appBar: AppBar(title: const Text('Hệ thống')),
      body: SafeArea(
        child: ListView(
          children: [
            AppContent(
              maxWidth: 920,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quản trị truy cập',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Các mục hiển thị theo quyền hiện tại của tài khoản.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (modules.isEmpty)
                    const Card(
                      child: AppEmptyState(
                        icon: Icons.lock_outline,
                        title: 'Không có chức năng quản trị',
                        message:
                            'Tài khoản hiện tại chưa được cấp quyền quản trị hệ thống.',
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 680 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: modules.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 154,
                              ),
                          itemBuilder: (context, index) =>
                              _SystemModuleCard(module: modules[index]),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemModuleCard extends StatelessWidget {
  const _SystemModuleCard({required this.module});

  final AccessModule module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openAccessModule(context, module),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Text(
                        module.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.arrow_forward, size: 20),
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
}
