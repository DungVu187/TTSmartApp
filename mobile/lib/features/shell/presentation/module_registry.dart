import 'package:flutter/material.dart';

import '../../../app_dependencies.dart';
import '../../../core/app_scope.dart';
import '../../company_management/data/repositories/company_repository.dart';
import '../../company_management/presentation/screens/companies_screen.dart';
import '../../mix_design_management/data/repositories/mix_design_repository.dart';
import '../../mix_design_management/presentation/screens/mix_designs_screen.dart';
import '../../material_reporting/data/repositories/material_report_repository.dart';
import '../../material_reporting/presentation/screens/material_report_screen.dart';
import '../../station_management/data/repositories/station_repository.dart';
import '../../station_management/presentation/screens/stations_screen.dart';
import '../../weigh_station_management/data/repositories/weigh_station_repository.dart';
import '../../weigh_station_management/presentation/screens/weigh_station_screen.dart';
import '../../access_management/data/models/permission_models.dart';
import '../../auth/data/models/auth_models.dart';
import '../../access_management/presentation/screens/functions_screen.dart';
import '../../access_management/presentation/screens/roles_screen.dart';
import '../../access_management/presentation/screens/users_screen.dart';
import '../../auth/presentation/controllers/app_controller.dart';
import 'screens/no_access_screen.dart';

class AccessModule {
  const AccessModule({
    required this.keyName,
    required this.functionCode,
    required this.label,
    required this.description,
    required this.icon,
    required this.builder,
    this.location,
  });

  final String keyName;
  final String functionCode;
  final String label;
  final String description;
  final IconData icon;
  final Widget Function(BuildContext, AppFeatureRepositories) builder;
  final int? location;

  bool canOpen(AppController controller) =>
      controller.hasPermission(functionCode, AccessPermission.dSach);

  AccessModule withFunction(GrantedFunction function) => AccessModule(
    keyName: keyName,
    functionCode: functionCode,
    label: _functionLabel(function, label),
    description: description,
    icon: _functionIcon(function, icon),
    builder: builder,
    location: function.location ?? location,
  );
}

/// A permission-filtered Function hierarchy returned by the backend.
/// Parents are retained even if their own ActiveKey is empty, matching web.
class FunctionMenuNode {
  const FunctionMenuNode({
    required this.function,
    required this.module,
    required this.children,
  });

  final GrantedFunction function;
  final AccessModule? module;
  final List<FunctionMenuNode> children;

  bool get canOpen => module != null;
}

final accessModules = <AccessModule>[
  AccessModule(
    keyName: 'users',
    functionCode: AccessFunctionCodes.users,
    label: 'Người dùng',
    description: 'Quản lý tài khoản và trạng thái sử dụng ứng dụng.',
    icon: Icons.people_alt_outlined,
    builder: (_, repositories) => UsersScreen(
      companyRepository: repositories.companies,
      stationRepository: repositories.stations,
    ),
  ),
  AccessModule(
    keyName: 'roles',
    functionCode: AccessFunctionCodes.roles,
    label: 'Phân quyền',
    description: 'Thiết lập vai trò và quyền sử dụng từng chức năng.',
    icon: Icons.admin_panel_settings_outlined,
    builder: (_, _) => const RolesScreen(),
  ),
  AccessModule(
    keyName: 'functions',
    functionCode: AccessFunctionCodes.functions,
    label: 'Chức năng',
    description: 'Quản lý danh mục chức năng được sử dụng trong hệ thống.',
    icon: Icons.account_tree_outlined,
    builder: (_, _) => const FunctionsScreen(),
  ),
];

List<AccessModule> visibleAccessModules(AppController controller) {
  if (!_hasDynamicFunctions(controller)) {
    return accessModules.where((module) => module.canOpen(controller)).toList();
  }
  final byCode = _functionsByCode(controller);
  final modules = accessModules
      .map((module) {
        final function = byCode[module.functionCode.toUpperCase()];
        return function == null ? null : module.withFunction(function);
      })
      .whereType<AccessModule>()
      .where((module) => module.canOpen(controller))
      .toList();
  _sortByLocation(modules);
  return modules;
}

List<FunctionMenuNode> visibleAccessFunctionTree(AppController controller) {
  if (!_hasDynamicFunctions(controller)) return const <FunctionMenuNode>[];
  final modulesByCode = <String, AccessModule>{
    for (final module in accessModules)
      module.functionCode.toUpperCase(): module,
  };
  final allFunctions = controller.session!.functions;
  final byId = {for (final function in allFunctions) function.id: function};
  final includedIds = <int>{
    for (final function in allFunctions)
      if (modulesByCode.containsKey(function.code.toUpperCase())) function.id,
  };
  for (final functionId in includedIds.toList()) {
    var parentId = byId[functionId]?.parentFunctionId;
    while (parentId != null && includedIds.add(parentId)) {
      parentId = byId[parentId]?.parentFunctionId;
    }
  }
  final functions = allFunctions
      .where((function) => includedIds.contains(function.id))
      .toList(growable: false);
  final functionIds = functions.map((item) => item.id).toSet();
  final childrenByParent = <int, List<GrantedFunction>>{};
  final roots = <GrantedFunction>[];
  for (final function in functions) {
    final parentId = function.parentFunctionId;
    if (parentId == null || !functionIds.contains(parentId)) {
      roots.add(function);
    } else {
      childrenByParent.putIfAbsent(parentId, () => []).add(function);
    }
  }
  int compare(GrantedFunction left, GrantedFunction right) =>
      (left.location ?? 1 << 30).compareTo(right.location ?? 1 << 30);
  FunctionMenuNode build(GrantedFunction function) {
    final module = modulesByCode[function.code.toUpperCase()];
    final children =
        (childrenByParent[function.id] ?? const <GrantedFunction>[])
            .map(build)
            .toList()
          ..sort((left, right) => compare(left.function, right.function));
    return FunctionMenuNode(
      function: function,
      module: module?.withFunction(function),
      children: children,
    );
  }

  return roots.map(build).toList()
    ..sort((left, right) => compare(left.function, right.function));
}

Future<void> openAccessModule(
  BuildContext context,
  AccessModule module,
  AppFeatureRepositories repositories,
) async {
  final controller = AppScope.read(context);
  if (!module.canOpen(controller)) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoAccessScreen()));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => module.builder(context, repositories),
    ),
  );
}

class OrganizationModule {
  const OrganizationModule({
    required this.keyName,
    required this.functionCode,
    required this.label,
    required this.description,
    required this.icon,
    this.location,
  });

  final String keyName;
  final String functionCode;
  final String label;
  final String description;
  final IconData icon;
  final int? location;

  bool canOpen(AppController controller) =>
      controller.hasPermission(functionCode, AccessPermission.dSach);

  OrganizationModule withFunction(GrantedFunction function) =>
      OrganizationModule(
        keyName: keyName,
        functionCode: functionCode,
        label: _functionLabel(function, label),
        description: description,
        icon: _functionIcon(function, icon),
        location: function.location ?? location,
      );
}

const organizationModules = <OrganizationModule>[
  OrganizationModule(
    keyName: 'companies',
    functionCode: AccessFunctionCodes.companies,
    label: 'Quản lý công ty',
    description: 'Thông tin công ty và đơn vị trực thuộc.',
    icon: Icons.apartment_outlined,
  ),
];

class StationModule {
  const StationModule({
    required this.keyName,
    required this.functionCode,
    required this.label,
    required this.description,
    required this.icon,
    this.location,
  });

  final String keyName;
  final String functionCode;
  final String label;
  final String description;
  final IconData icon;
  final int? location;

  bool canOpen(AppController controller) =>
      controller.hasRole('ADMIN') ||
      controller.hasPermission(functionCode, AccessPermission.dSach);

  StationModule withFunction(GrantedFunction function) => StationModule(
    keyName: keyName,
    functionCode: functionCode,
    label: _functionLabel(function, label),
    description: description,
    icon: _functionIcon(function, icon),
    location: function.location ?? location,
  );
}

const stationModules = <StationModule>[
  StationModule(
    keyName: 'stations',
    functionCode: AccessFunctionCodes.branches,
    label: 'Quản lý trạm',
    description: 'Theo dõi và quản lý các trạm trong phạm vi được cấp.',
    icon: Icons.factory_outlined,
  ),
];

class OperationalModule {
  const OperationalModule({
    required this.keyName,
    required this.functionCode,
    required this.label,
    required this.description,
    required this.icon,
    this.permission = AccessPermission.dSach,
    this.location,
  });

  final String keyName;
  final String functionCode;
  final String label;
  final String description;
  final IconData icon;
  final AccessPermission permission;
  final int? location;

  bool canOpen(AppController controller) =>
      controller.hasPermission(functionCode, permission);

  OperationalModule withFunction(GrantedFunction function) => OperationalModule(
    keyName: keyName,
    functionCode: functionCode,
    label: _functionLabel(function, label),
    description: description,
    icon: _functionIcon(function, icon),
    permission: permission,
    location: function.location ?? location,
  );
}

const operationalModules = <OperationalModule>[
  OperationalModule(
    keyName: 'material-reports',
    functionCode: AccessFunctionCodes.materialReports,
    label: 'Quản lý vật liệu',
    description:
        'Xem nhập, xuất, tồn kho và giá trị vật liệu theo từng trạm trộn.',
    icon: Icons.inventory_2_outlined,
    permission: AccessPermission.view,
  ),
  OperationalModule(
    keyName: 'order-reports',
    functionCode: AccessFunctionCodes.orderReports,
    label: 'Đơn hàng',
    description: 'Tra cứu đơn hàng và khối lượng sản xuất theo trạm.',
    icon: Icons.receipt_long_outlined,
  ),
  OperationalModule(
    keyName: 'order-statistics',
    functionCode: AccessFunctionCodes.orderStatistics,
    label: 'Thống kê',
    description: 'Thống kê chi tiết và tổng hợp mẻ trộn theo trạm.',
    icon: Icons.query_stats_outlined,
  ),
  OperationalModule(
    keyName: 'mix-designs',
    functionCode: AccessFunctionCodes.mixDesigns,
    label: 'Quản lý cấp phối',
    description: 'Tra cứu thông số mác và định lượng vật liệu theo trạm.',
    icon: Icons.science_outlined,
  ),
  OperationalModule(
    keyName: 'weigh-stations',
    functionCode: AccessFunctionCodes.weighStations,
    label: 'Quản lý cân ô tô',
    description: 'Tra cứu phiếu cân và tổng hợp theo từng trạm cân.',
    icon: Icons.scale_outlined,
  ),
];

Future<void> openMaterialReportModule(
  BuildContext context,
  OperationalModule module,
  MaterialReportRepository repository,
  CompanyRepository companyRepository,
) async {
  final controller = AppScope.read(context);
  if (!module.canOpen(controller)) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoAccessScreen()));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AppScope(
        controller: controller,
        child: MaterialReportScreen(
          repository: repository,
          companyRepository: companyRepository,
          isAdmin: controller.hasRole('ADMIN'),
        ),
      ),
    ),
  );
}

List<OperationalModule> visibleOperationalModules(AppController controller) {
  if (!_hasDynamicFunctions(controller)) {
    return operationalModules
        .where((module) => module.canOpen(controller))
        .toList();
  }
  final byCode = _functionsByCode(controller);
  final modules = operationalModules
      .map((module) {
        final function = byCode[module.functionCode.toUpperCase()];
        return function == null ? null : module.withFunction(function);
      })
      .whereType<OperationalModule>()
      .where((module) => module.canOpen(controller))
      .toList();
  _sortByLocation(modules);
  return modules;
}

List<StationModule> visibleStationModules(AppController controller) {
  if (!_hasDynamicFunctions(controller)) {
    return stationModules
        .where((module) => module.canOpen(controller))
        .toList();
  }
  final byCode = _functionsByCode(controller);
  final modules = stationModules
      .map((module) {
        final function = byCode[module.functionCode.toUpperCase()];
        if (function == null && controller.hasRole('ADMIN')) return module;
        return function == null ? null : module.withFunction(function);
      })
      .whereType<StationModule>()
      .where((module) => module.canOpen(controller))
      .toList();
  _sortByLocation(modules);
  return modules;
}

Map<String, GrantedFunction> _functionsByCode(AppController controller) => {
  for (final function
      in controller.session?.functions ?? const <GrantedFunction>[])
    function.code.toUpperCase(): function,
};

bool _hasDynamicFunctions(AppController controller) =>
    controller.session?.functions.isNotEmpty ?? false;

void _sortByLocation<T>(List<T> modules) {
  int? locationOf(T module) => switch (module) {
    AccessModule value => value.location,
    OrganizationModule value => value.location,
    StationModule value => value.location,
    OperationalModule value => value.location,
    _ => null,
  };
  modules.sort(
    (left, right) =>
        (locationOf(left) ?? 1 << 30).compareTo(locationOf(right) ?? 1 << 30),
  );
}

String _functionLabel(GrantedFunction function, String fallback) {
  final name = function.name.trim();
  return name.isEmpty ? fallback : name;
}

IconData _functionIcon(GrantedFunction function, IconData fallback) {
  final icon = function.icon?.toLowerCase() ?? '';
  if (icon.contains('user') || icon.contains('people')) {
    return Icons.people_alt_outlined;
  }
  if (icon.contains('role') || icon.contains('admin')) {
    return Icons.admin_panel_settings_outlined;
  }
  if (icon.contains('function') || icon.contains('setting')) {
    return Icons.settings_outlined;
  }
  if (icon.contains('company') || icon.contains('building')) {
    return Icons.apartment_outlined;
  }
  if (icon.contains('branch') || icon.contains('factory')) {
    return Icons.factory_outlined;
  }
  if (icon.contains('scale') || icon.contains('weigh')) {
    return Icons.scale_outlined;
  }
  if (icon.contains('order') || icon.contains('receipt')) {
    return Icons.receipt_long_outlined;
  }
  return fallback;
}

Future<void> openStationModule(
  BuildContext context,
  StationModule module,
  StationRepository stationRepository,
  CompanyRepository companyRepository,
) async {
  final controller = AppScope.read(context);
  if (!module.canOpen(controller)) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoAccessScreen()));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => StationsScreen(
        repository: stationRepository,
        companyRepository: companyRepository,
      ),
    ),
  );
}

Future<void> openMixDesignModule(
  BuildContext context,
  OperationalModule module,
  MixDesignRepository repository,
  CompanyRepository companyRepository,
) async {
  final controller = AppScope.read(context);
  if (!module.canOpen(controller)) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoAccessScreen()));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AppScope(
        controller: controller,
        child: MixDesignsScreen(
          repository: repository,
          companyRepository: companyRepository,
        ),
      ),
    ),
  );
}

Future<void> openWeighStationModule(
  BuildContext context,
  OperationalModule module,
  WeighStationRepository repository,
  CompanyRepository companyRepository,
) async {
  final controller = AppScope.read(context);
  if (!module.canOpen(controller)) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoAccessScreen()));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AppScope(
        controller: controller,
        child: WeighStationScreen(
          repository: repository,
          companyRepository: companyRepository,
        ),
      ),
    ),
  );
}

List<OrganizationModule> visibleOrganizationModules(AppController controller) {
  if (!_hasDynamicFunctions(controller)) {
    return organizationModules
        .where((module) => module.canOpen(controller))
        .toList();
  }
  final byCode = _functionsByCode(controller);
  final modules = organizationModules
      .map((module) {
        final function = byCode[module.functionCode.toUpperCase()];
        return function == null ? null : module.withFunction(function);
      })
      .whereType<OrganizationModule>()
      .where((module) => module.canOpen(controller))
      .toList();
  _sortByLocation(modules);
  return modules;
}

Future<void> openOrganizationModule(
  BuildContext context,
  OrganizationModule module,
  CompanyRepository repository,
) async {
  final controller = AppScope.read(context);
  if (!module.canOpen(controller)) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoAccessScreen()));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CompaniesScreen(repository: repository)),
  );
}
