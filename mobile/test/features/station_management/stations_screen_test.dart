import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/station_management/data/models/station_models.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';
import 'package:ttsmart_mobile/features/station_management/presentation/screens/stations_screen.dart';

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _AdminAppController extends AppController {
  _AdminAppController._(ApiClient apiClient)
    : super(
        apiClient: apiClient,
        authRepository: AuthRepository(apiClient),
        accessManagementRepository: AccessManagementRepository(apiClient),
        tokenStorage: _MemoryTokenStorage(),
      );

  factory _AdminAppController() {
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Không được gọi API trong widget test.'),
      ),
    );
    return _AdminAppController._(apiClient);
  }

  @override
  bool hasRole(String roleCode) => roleCode.toUpperCase() == 'ADMIN';

  @override
  bool hasPermission(String functionCode, AccessPermission permission) => true;
}

class _FakeStationRepository implements StationRepository {
  final List<int?> requestedTypes = <int?>[];

  @override
  Future<StationPage> getStations({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? companyId,
    int? typeTram,
    int? status = StationDataStatus.active,
  }) async {
    requestedTypes.add(typeTram);
    return StationPage(
      items: const [
        StationListItem(
          id: 10,
          name: 'Trạm Bình Chánh',
          phone: '0900000000',
          typeTram: 1,
        ),
      ],
      pageNumber: 1,
      pageSize: pageSize,
      totalCount: 1,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCompanyRepository implements CompanyRepository {
  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async {
    return const CompanyPage(
      items: [
        CompanyResponse(
          id: 1,
          code: 'CT01',
          name: 'Công ty An Phát',
          email: null,
          phone: null,
          address: null,
          fax: null,
          representative: null,
          contactName: null,
          contactEmail: null,
          contactPhone: null,
          createdAtUtc: null,
          updatedAtUtc: null,
          userId: null,
          status: CompanyDataStatus.active,
          isActive: true,
          countUser: 1,
          plan: CompanyPlan.paid,
          isLocked: false,
          note: null,
          logo: null,
          expiredDate: null,
        ),
      ],
      pageNumber: 1,
      pageSize: 20,
      totalCount: 1,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('station filters open and reset cleanly on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appController = _AdminAppController();
    final stationRepository = _FakeStationRepository();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: StationsScreen(
            repository: stationRepository,
            companyRepository: _FakeCompanyRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phạm vi: Toàn bộ công ty'), findsOneWidget);
    expect(find.text('1 trạm • Đang hoạt động'), findsOneWidget);
    expect(find.text('Trạm Bình Chánh'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Bộ lọc'));
    await tester.pumpAndSettle();

    expect(find.text('Bộ lọc trạm'), findsOneWidget);
    expect(find.text('Tất cả loại'), findsOneWidget);
    expect(find.text('Tất cả công ty'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('station-type-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trạm cân').last);
    await tester.pumpAndSettle();
    expect(find.text('Trạm cân'), findsOneWidget);

    await tester.tap(find.text('Đặt lại'));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả loại'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Áp dụng'));
    await tester.pumpAndSettle();

    expect(stationRepository.requestedTypes.last, isNull);
    expect(tester.takeException(), isNull);
  });
}
