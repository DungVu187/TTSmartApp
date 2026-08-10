import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../mix_design_management/data/repositories/mix_design_repository.dart';
import '../../../shell/presentation/module_registry.dart';
import '../../../station_management/data/repositories/station_repository.dart';
import '../../../weigh_station_management/data/repositories/weigh_station_repository.dart';
import '../more_module_registry.dart';
import '../widgets/module_panel_grid.dart';
import 'module_preview_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.companyRepository,
    required this.mixDesignRepository,
    required this.stationRepository,
    required this.weighStationRepository,
  });

  final CompanyRepository companyRepository;
  final MixDesignRepository mixDesignRepository;
  final StationRepository stationRepository;
  final WeighStationRepository weighStationRepository;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final organizationModules = visibleOrganizationModules(controller);
    final stationModules = visibleStationModules(controller);
    final operationalModules = visibleOperationalModules(controller);
    final mixDesignModules = operationalModules
        .where((module) => module.keyName == 'mix-designs')
        .toList(growable: false);
    final weighStationModules = operationalModules
        .where((module) => module.keyName == 'weigh-stations')
        .toList(growable: false);
    final previewByKey = {
      for (final module in previewModules) module.keyName: module,
    };
    final actions = <_MoreAction>[];

    void addPreview(String keyName) {
      final module = previewByKey.remove(keyName);
      if (module == null) return;
      actions.add(
        _MoreAction(
          label: _panelLabel(module),
          icon: module.icon,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ModulePreviewScreen(module: module),
            ),
          ),
        ),
      );
    }

    actions.addAll(
      mixDesignModules.map(
        (module) => _MoreAction(
          label: module.label,
          icon: module.icon,
          onTap: () => openMixDesignModule(
            context,
            module,
            mixDesignRepository,
            companyRepository,
          ),
        ),
      ),
    );
    actions.addAll(
      weighStationModules.map(
        (module) => _MoreAction(
          label: module.label,
          icon: module.icon,
          onTap: () => openWeighStationModule(
            context,
            module,
            weighStationRepository,
            companyRepository,
          ),
        ),
      ),
    );
    actions.addAll(
      stationModules.map(
        (module) => _MoreAction(
          label: module.label,
          icon: module.icon,
          onTap: () => openStationModule(
            context,
            module,
            stationRepository,
            companyRepository,
          ),
        ),
      ),
    );
    actions.addAll(
      organizationModules.map(
        (module) => _MoreAction(
          label: module.label,
          icon: module.icon,
          onTap: () =>
              openOrganizationModule(context, module, companyRepository),
        ),
      ),
    );
    for (final module in previewByKey.values) {
      actions.add(
        _MoreAction(
          label: _panelLabel(module),
          icon: module.icon,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ModulePreviewScreen(module: module),
            ),
          ),
        ),
      );
    }

    return ModulePanelGrid(
      compactColumnCount: 4,
      items: [
        for (var index = 0; index < actions.length; index++)
          ModulePanelItem(
            label: actions[index].label,
            icon: actions[index].icon,
            accent: _modulePalettes[index % _modulePalettes.length].accent,
            backgroundColor:
                _modulePalettes[index % _modulePalettes.length].background,
            onTap: actions[index].onTap,
          ),
      ],
    );
  }
}

String _panelLabel(MoreModuleDefinition module) => switch (module.keyName) {
  PreviewModuleKeys.materials => 'Quản lý vật liệu',
  _ => module.label,
};

class _MoreAction {
  const _MoreAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _ModulePalette {
  const _ModulePalette({required this.accent, required this.background});

  final Color accent;
  final Color background;
}

const _modulePalettes = <_ModulePalette>[
  _ModulePalette(accent: Color(0xFF2563EB), background: Color(0xFFEEF2FF)),
  _ModulePalette(accent: Color(0xFF047857), background: Color(0xFFECFDF5)),
  _ModulePalette(accent: Color(0xFFEA580C), background: Color(0xFFFFF7ED)),
  _ModulePalette(accent: Color(0xFF7C3AED), background: Color(0xFFF3E8FF)),
  _ModulePalette(accent: Color(0xFFD97706), background: Color(0xFFFFFBEB)),
  _ModulePalette(accent: Color(0xFF0284C7), background: Color(0xFFF0F9FF)),
  _ModulePalette(accent: Color(0xFFE11D48), background: Color(0xFFFFF1F2)),
];
