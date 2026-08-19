import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/files/export_file.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/network/api_request_cancellation.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_filter_models.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_result_models.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/repositories/weigh_station_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/presentation/screens/weigh_station_screen.dart';

void main() {
  testWidgets(
    'advanced filters can be repeatedly toggled while options are loading',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final appController = _AuthorizedAppController();
      final repository = _DelayedWeighStationRepository();
      addTearDown(appController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppScope(
            controller: appController,
            child: WeighStationScreen(
              repository: repository,
              companyRepository: _UnusedCompanyRepository(),
              now: () => DateTime(2026, 8, 19),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final stationField = find.byKey(
        const ValueKey<String>('weigh-station-station'),
      );
      final stationInput = find.descendant(
        of: stationField,
        matching: find.byType(TextFormField),
      );
      await tester.tap(stationInput);
      await tester.enterText(stationInput, '42');
      await tester.pump();
      await tester.tap(find.text('Trạm cân 42').last);
      await tester.pump();

      final toggle = find.byKey(
        const ValueKey<String>('weigh-station-advanced-filters'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('weigh-station-vehicle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('weigh-station-goods')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('weigh-station-operator')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('weigh-station-unit')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('weigh-station-type')),
        findsOneWidget,
      );

      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(toggle);
      await tester.pump();

      repository.completeOptions();
      await tester.pumpAndSettle();

      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _AuthorizedAppController extends AppController {
  _AuthorizedAppController._(ApiClient apiClient)
    : super(
        apiClient: apiClient,
        authRepository: AuthRepository(apiClient),
        accessManagementRepository: AccessManagementRepository(apiClient),
        tokenStorage: _MemoryTokenStorage(),
      );

  factory _AuthorizedAppController() {
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Network calls are forbidden in tests.'),
      ),
    );
    return _AuthorizedAppController._(apiClient);
  }

  @override
  CurrentSession? get session => const CurrentSession(
    user: AuthenticatedUser(
      id: 1,
      userName: 'weigh-station-tester',
      fullName: 'Weigh station tester',
      email: null,
      code: null,
      phone: null,
      companyId: 7,
      departmentId: null,
      positionId: null,
      unitId: null,
      branchId: '42',
      status: 1,
    ),
    roles: <AuthRole>[],
    functions: <GrantedFunction>[],
    roleFunctions: <AuthRoleFunction>[],
  );

  @override
  bool hasPermission(String functionCode, AccessPermission permission) =>
      functionCode == AccessFunctionCodes.weighStations &&
      permission == AccessPermission.dSach;

  @override
  bool hasRole(String roleCode) => false;
}

class _DelayedWeighStationRepository implements WeighStationRepository {
  final _options = Completer<WeighStationFilterOptions>();

  void completeOptions() {
    if (_options.isCompleted) return;
    _options.complete(
      const WeighStationFilterOptions(
        vehiclePlates: <String>['30A-123.45'],
        goodsNames: <String>['Đá 1x2'],
        operatorNames: <String>['Nguyễn Văn A'],
        unitNames: <String>['kg'],
        weighingTypes: <String>['Nhập'],
      ),
    );
  }

  @override
  Future<List<WeighStationStation>> getStations({
    int? companyId,
    ApiRequestCancellation? cancellation,
  }) async => const <WeighStationStation>[
    WeighStationStation(id: 42, name: 'Trạm cân 42'),
  ];

  @override
  Future<WeighStationFilterOptions> getFilterOptions(
    WeighStationFilterQuery query, {
    ApiRequestCancellation? cancellation,
  }) => _options.future;

  @override
  Future<WeighStationPage> searchDetail(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) => throw UnimplementedError();

  @override
  Future<WeighStationSummary> searchSummary(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) => throw UnimplementedError();

  @override
  Future<ExportFile> exportDetail(WeighStationSearchQuery query) =>
      throw UnimplementedError();

  @override
  Future<ExportFile> exportSummary(WeighStationSearchQuery query) =>
      throw UnimplementedError();
}

class _UnusedCompanyRepository implements CompanyRepository {
  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
