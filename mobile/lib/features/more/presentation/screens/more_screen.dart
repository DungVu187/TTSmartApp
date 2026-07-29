import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../shell/presentation/module_registry.dart';
import '../more_module_registry.dart';
import 'module_preview_screen.dart';
import 'system_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.companyRepository});

  final CompanyRepository companyRepository;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final hasSystemAccess = visibleAccessModules(controller).isNotEmpty;
    final organizationModules = visibleOrganizationModules(controller);
    final organizationPreviewModules = _group(MoreModuleGroup.organization);
    return ListView(
      key: const PageStorageKey<String>('more-scroll'),
      children: [
        AppContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                title: 'Xem thêm',
                subtitle: 'Các phân hệ vận hành và quản trị khác',
              ),
              const SizedBox(height: 22),
              if (organizationModules.isNotEmpty) ...[
                _OrganizationModuleSection(
                  modules: organizationModules,
                  repository: companyRepository,
                ),
                if (organizationPreviewModules.isNotEmpty)
                  const SizedBox(height: 26),
              ],
              _ModuleGroupSection(
                title: 'Vận hành',
                modules: _group(MoreModuleGroup.operations),
              ),
              if (organizationPreviewModules.isNotEmpty) ...[
                const SizedBox(height: 26),
                _ModuleGroupSection(
                  title: organizationModules.isNotEmpty
                      ? 'Tổ chức khác'
                      : 'Tổ chức',
                  modules: organizationPreviewModules,
                ),
              ],
              if (hasSystemAccess) ...[
                const SizedBox(height: 26),
                const _AdministrationSection(),
              ],
              const SizedBox(height: 24),
              const Card(
                child: AppEmptyState(
                  icon: Icons.extension_outlined,
                  title: 'Các phân hệ được hoàn thiện theo từng giai đoạn',
                  message:
                      'Giao diện đã tạo sẵn điểm mở module. API và nghiệp vụ '
                      'sẽ được nối theo từng vertical slice ở giai đoạn sau.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<MoreModuleDefinition> _group(MoreModuleGroup group) => previewModules
      .where((module) => module.group == group)
      .toList(growable: false);
}

class _OrganizationModuleSection extends StatelessWidget {
  const _OrganizationModuleSection({
    required this.modules,
    required this.repository,
  });

  final List<OrganizationModule> modules;
  final CompanyRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổ chức',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...modules.map(
          (module) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                minTileHeight: 72,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(module.icon, color: theme.colorScheme.primary),
                ),
                title: Text(module.label),
                subtitle: Text(module.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    openOrganizationModule(context, module, repository),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleGroupSection extends StatelessWidget {
  const _ModuleGroupSection({required this.title, required this.modules});

  final String title;
  final List<MoreModuleDefinition> modules;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: modules.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 142,
              ),
              itemBuilder: (context, index) =>
                  _ModuleTile(module: modules[index]),
            );
          },
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});

  final MoreModuleDefinition module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ModulePreviewScreen(module: module),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  module.icon,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const Spacer(),
              Text(
                module.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Bản xem trước',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdministrationSection extends StatelessWidget {
  const _AdministrationSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quản trị',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            minTileHeight: 72,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            title: const Text('Hệ thống'),
            subtitle: const Text('Người dùng, phân quyền và chức năng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SystemScreen())),
          ),
        ),
      ],
    );
  }
}
