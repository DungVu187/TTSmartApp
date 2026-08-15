import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/app.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/app_dependencies.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/home/data/repositories/home_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';
import 'package:ttsmart_mobile/features/order_reporting/data/repositories/order_report_repository.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/repositories/weigh_station_repository.dart';

class _MemoryTokenStorage implements TokenStorage {
  StoredSession? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<StoredSession?> read() async => value;

  @override
  Future<void> write(StoredSession session) async => value = session;
}

void main() {
  testWidgets('Hiển thị màn hình đăng nhập khi chưa có token', (tester) async {
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Không được gọi API'),
      ),
    );
    final controller = AppController(
      apiClient: apiClient,
      authRepository: AuthRepository(apiClient),
      accessManagementRepository: AccessManagementRepository(apiClient),
      tokenStorage: _MemoryTokenStorage(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      TTsmartApp(
        controller: controller,
        repositories: AppFeatureRepositories(
          home: ApiHomeRepository(apiClient),
          mixDesigns: ApiMixDesignRepository(apiClient),
          materialReports: ApiMaterialReportRepository(apiClient),
          orderReports: ApiOrderReportRepository(apiClient),
          reports: const MockReportsRepository(),
          companies: ApiCompanyRepository(apiClient),
          stations: ApiStationRepository(apiClient),
          weighStations: ApiWeighStationRepository(apiClient),
        ),
        initializeOnStart: false,
      ),
    );

    expect(find.text('TTsmart'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);

    controller.dispose();
  });
}
