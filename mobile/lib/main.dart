import 'package:flutter/material.dart';

import 'app.dart';
import 'app_dependencies.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/company_management/data/repositories/company_repository.dart';
import 'features/auth/presentation/controllers/app_controller.dart';
import 'features/access_management/data/repositories/access_management_repository.dart';
import 'features/home/data/repositories/home_repository.dart';
import 'features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'features/material_reporting/data/repositories/material_report_repository.dart';
import 'features/order_reporting/data/repositories/order_report_repository.dart';
import 'features/reports/data/repositories/reports_repository.dart';
import 'features/station_management/data/repositories/station_repository.dart';
import 'features/weigh_station_management/data/repositories/weigh_station_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final apiClient = ApiClient(
    baseUri: config.apiBaseUri,
    timeout: config.requestTimeout,
  );
  final controller = AppController(
    apiClient: apiClient,
    authRepository: AuthRepository(apiClient),
    accessManagementRepository: AccessManagementRepository(apiClient),
    tokenStorage: SecureTokenStorage(),
  );
  final repositories = AppFeatureRepositories(
    home: ApiHomeRepository(apiClient),
    mixDesigns: ApiMixDesignRepository(apiClient),
    materialReports: ApiMaterialReportRepository(apiClient),
    orderReports: ApiOrderReportRepository(apiClient),
    reports: ApiReportsRepository(apiClient),
    companies: ApiCompanyRepository(apiClient),
    stations: ApiStationRepository(apiClient),
    weighStations: ApiWeighStationRepository(apiClient),
  );
  runApp(TTsmartApp(controller: controller, repositories: repositories));
}
