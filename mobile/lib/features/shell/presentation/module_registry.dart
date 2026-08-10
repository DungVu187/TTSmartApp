import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../company_management/data/repositories/company_repository.dart';
import '../../company_management/presentation/screens/companies_screen.dart';
import '../../mix_design_management/data/repositories/mix_design_repository.dart';
import '../../mix_design_management/presentation/screens/mix_designs_screen.dart';
import '../../station_management/data/repositories/station_repository.dart';
import '../../station_management/presentation/screens/stations_screen.dart';
import '../../weigh_station_management/data/repositories/weigh_station_repository.dart';
import '../../weigh_station_management/presentation/screens/weigh_station_screen.dart';
import '../../access_management/data/models/permission_models.dart';
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
  });

  final String keyName;
  final String functionCode;
  final String label;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;

  bool canOpen(AppController controller) =>
      controller.hasPermission(functionCode, AccessPermission.dSach);
}

final accessModules = <AccessModule>[
  AccessModule(
    keyName: 'users',
    functionCode: AccessFunctionCodes.users,
    label: 'Người dùng',
    description: 'Quản lý tài khoản và trạng thái sử dụng ứng dụng.',
    icon: Icons.people_alt_outlined,
    builder: (_) => const UsersScreen(),
  ),
  AccessModule(
    keyName: 'roles',
    functionCode: AccessFunctionCodes.roles,
    label: 'Phân quyền',
    description: 'Thiết lập vai trò và quyền sử dụng từng chức năng.',
    icon: Icons.admin_panel_settings_outlined,
    builder: (_) => const RolesScreen(),
  ),
  AccessModule(
    keyName: 'functions',
    functionCode: AccessFunctionCodes.functions,
    label: 'Chức năng',
    description: 'Quản lý danh mục chức năng được sử dụng trong hệ thống.',
    icon: Icons.account_tree_outlined,
    builder: (_) => const FunctionsScreen(),
  ),
];

List<AccessModule> visibleAccessModules(AppController controller) =>
    accessModules.where((module) => module.canOpen(controller)).toList();

Future<void> openAccessModule(BuildContext context, AccessModule module) async {
  final controller = AppScope.read(context);
  if (!module.canOpen(controller)) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NoAccessScreen()));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: module.builder));
}

class OrganizationModule {
  const OrganizationModule({
    required this.keyName,
    required this.functionCode,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String keyName;
  final String functionCode;
  final String label;
  final String description;
  final IconData icon;

  bool canOpen(AppController controller) =>
      controller.hasPermission(functionCode, AccessPermission.dSach);
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
  });

  final String keyName;
  final String functionCode;
  final String label;
  final String description;
  final IconData icon;

  bool canOpen(AppController controller) =>
      controller.hasRole('ADMIN') ||
      controller.hasPermission(functionCode, AccessPermission.dSach);
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
  });

  final String keyName;
  final String functionCode;
  final String label;
  final String description;
  final IconData icon;

  bool canOpen(AppController controller) =>
      controller.hasPermission(functionCode, AccessPermission.dSach);
}

const operationalModules = <OperationalModule>[
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

List<OperationalModule> visibleOperationalModules(AppController controller) =>
    operationalModules.where((module) => module.canOpen(controller)).toList();

List<StationModule> visibleStationModules(AppController controller) =>
    stationModules.where((module) => module.canOpen(controller)).toList();

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

List<OrganizationModule> visibleOrganizationModules(AppController controller) =>
    organizationModules.where((module) => module.canOpen(controller)).toList();

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
