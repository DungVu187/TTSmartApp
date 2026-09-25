import 'package:flutter/material.dart';

import '../../../../app_dependencies.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../auth/presentation/controllers/app_controller.dart';
import '../../../shell/presentation/module_registry.dart';

/// Figma "05 More (sheet)": every module that is not a bottom tab, grouped
/// into VẬN HÀNH and TỔ CHỨC & HỆ THỐNG. Covers the bottom navigation.
Future<void> showMoreSheet(
  BuildContext context,
  AppFeatureRepositories repositories,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) =>
      MoreSheet(hostContext: context, repositories: repositories),
);

class MoreSheet extends StatelessWidget {
  const MoreSheet({
    super.key,
    required this.hostContext,
    required this.repositories,
  });

  /// Context that outlives the sheet; modules are pushed from it.
  final BuildContext hostContext;
  final AppFeatureRepositories repositories;

  @override
  Widget build(BuildContext context) {
    // Read from the host: the sheet route may sit outside the scope.
    final controller = AppScope.read(hostContext);
    final operations = _operationTiles(controller)
      ..sort((left, right) => left.order.compareTo(right.order));
    final organization = _organizationTiles(controller)
      ..sort((left, right) => left.order.compareTo(right.order));
    final p = context.palette;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey<String>('more-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Xem thêm',
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 20,
                      height: 24 / 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Đóng',
                  child: Material(
                    key: const ValueKey<String>('more-sheet-close'),
                    color: p.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox.square(
                        dimension: 32,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: p.text2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (operations.isEmpty && organization.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: StateView(
                  icon: Icons.grid_view_outlined,
                  title: 'Chưa có chức năng',
                  message: 'Tài khoản chưa được cấp thêm chức năng nào.',
                ),
              ),
            if (operations.isNotEmpty) ...[
              const SizedBox(height: 20),
              const GroupLabel('Vận hành'),
              const SizedBox(height: 10),
              _ModuleGrid(tiles: operations),
            ],
            if (organization.isNotEmpty) ...[
              const SizedBox(height: 16),
              const GroupLabel('Tổ chức & hệ thống'),
              const SizedBox(height: 10),
              _ModuleGrid(tiles: organization),
            ],
          ],
        ),
      ),
    );
  }

  /// Closes the sheet, then opens [open] from the host context.
  VoidCallback _launch(BuildContext sheetContext, void Function() open) => () {
    Navigator.of(sheetContext).pop();
    open();
  };

  List<_ModuleTile> _operationTiles(AppController controller) {
    final context = hostContext;
    final operational = visibleOperationalModules(controller);
    OperationalModule? byKey(String key) =>
        operational.where((module) => module.keyName == key).firstOrNull;
    final mixDesigns = byKey('mix-designs');
    final weighStations = byKey('weigh-stations');
    final materials = byKey('material-reports');
    return [
      if (mixDesigns != null)
        _ModuleTile(
          label: mixDesigns.label,
          icon: Icons.science_outlined,
          tone: AppTone.info,
          order: mixDesigns.location ?? 10,
          open: () => openMixDesignModule(
            context,
            mixDesigns,
            repositories.mixDesigns,
            repositories.companies,
          ),
        ),
      if (weighStations != null)
        _ModuleTile(
          label: weighStations.label,
          icon: Icons.balance_outlined,
          tone: AppTone.success,
          order: weighStations.location ?? 20,
          open: () => openWeighStationModule(
            context,
            weighStations,
            repositories.weighStations,
            repositories.companies,
          ),
        ),
      if (materials != null)
        _ModuleTile(
          label: materials.label,
          icon: Icons.inventory_2_outlined,
          tone: AppTone.warning,
          order: materials.location ?? 30,
          open: () => openMaterialReportModule(
            context,
            materials,
            repositories.materialReports,
            repositories.companies,
          ),
        ),
      for (final module in visibleStationModules(controller))
        _ModuleTile(
          label: module.label,
          icon: Icons.factory_outlined,
          tone: AppTone.violet,
          order: module.location ?? 40,
          open: () => openStationModule(
            context,
            module,
            repositories.stations,
            repositories.companies,
          ),
        ),
    ];
  }

  List<_ModuleTile> _organizationTiles(AppController controller) {
    final context = hostContext;
    return [
      for (final module in visibleOrganizationModules(controller))
        _ModuleTile(
          label: module.label,
          icon: Icons.apartment_outlined,
          tone: AppTone.danger,
          order: module.location ?? 10,
          open: () =>
              openOrganizationModule(context, module, repositories.companies),
        ),
      for (final module in visibleAccessModules(controller))
        _ModuleTile(
          label: module.label,
          icon: switch (module.keyName) {
            'users' => Icons.group_outlined,
            'roles' => Icons.shield_outlined,
            _ => Icons.account_tree_outlined,
          },
          tone: switch (module.keyName) {
            'users' => AppTone.primary,
            'roles' => AppTone.success,
            _ => AppTone.neutral,
          },
          order: 100 + (module.location ?? 0),
          open: () => openAccessModule(context, module, repositories),
        ),
    ];
  }
}

class _ModuleTile {
  const _ModuleTile({
    required this.label,
    required this.icon,
    required this.tone,
    required this.order,
    required this.open,
  });

  final String label;
  final IconData icon;
  final AppTone tone;
  final int order;
  final VoidCallback open;
}

/// Four columns of 58px tinted icon tiles with a two-line label.
class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.tiles});

  final List<_ModuleTile> tiles;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sheet = context.findAncestorWidgetOfExactType<MoreSheet>()!;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 12,
      childAspectRatio: 80 / 94,
      children: [
        for (final tile in tiles)
          Semantics(
            button: true,
            label: tile.label,
            child: InkWell(
              key: ValueKey<String>('more-tile-${tile.label}'),
              borderRadius: BorderRadius.circular(18),
              onTap: sheet._launch(context, tile.open),
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      final (fg, bg) = p.tone(tile.tone);
                      return Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(tile.icon, size: 26, color: fg),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tile.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 11,
                      height: 14 / 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
