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

import '../../support/phone_viewport.dart';

Future<void> _pumpScreen(
  WidgetTester tester,
  _DelayedWeighStationRepository repository,
) async {
  usePhoneViewport(tester);
  final appController = _AuthorizedAppController();
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
}

/// Opening a modal route needs a few frames; the sheet may show an
/// indeterminate progress bar, so pumpAndSettle cannot be used.
Future<void> _settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'advanced filter sheet can be reopened while options are loading',
    (tester) async {
      final repository = _DelayedWeighStationRepository();
      await _pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      // A single station in scope is picked and searched on a phone.
      expect(repository.detailQueries.single.branchId, 42);

      final openFilters = find.byKey(
        const ValueKey<String>('weigh-station-advanced-filters'),
      );
      Future<void> openAndClose({required bool expectFields}) async {
        await tester.tap(openFilters);
        await _settleRoute(tester);
        if (expectFields) {
          for (final key in const [
            'weigh-station-stage',
            'weigh-station-vehicle',
            'weigh-station-goods',
            'weigh-station-operator',
            'weigh-station-unit',
            'weigh-station-type',
          ]) {
            expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
          }
        }
        await tester.tap(find.byTooltip('Đóng'));
        await _settleRoute(tester);
      }

      await openAndClose(expectFields: true);
      await openAndClose(expectFields: false);

      repository.completeOptions();
      await tester.pumpAndSettle();

      await openAndClose(expectFields: true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picking a station from the chip searches immediately', (
    tester,
  ) async {
    final repository = _DelayedWeighStationRepository(
      stations: const [
        WeighStationStation(id: 42, name: 'Trạm cân 42'),
        WeighStationStation(id: 43, name: 'Trạm cân 43'),
      ],
      tickets: const [
        WeighStationItem(
          stt: 1,
          id: 't-1',
          ticketNumber: 10231,
          hasConversionConfiguration: false,
          vehiclePlate: '30A-123.45',
          goodsName: 'Đá 1x2',
          goodsWeightKg: 12450,
          weighingType: 'Nhập',
        ),
      ],
    )..completeOptions();
    await _pumpScreen(tester, repository);
    await tester.pumpAndSettle();

    // Two stations: nothing is searched until the user picks one.
    expect(repository.detailQueries, isEmpty);
    expect(find.text('Chọn trạm cân'), findsWidgets);

    // The test font is wider than real text, so bring the chip into view.
    final stationChip = find.byKey(
      const ValueKey<String>('weigh-station-station'),
    );
    await tester.ensureVisible(stationChip);
    await tester.pumpAndSettle();
    await tester.tap(stationChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trạm cân 43'));
    await tester.pumpAndSettle();

    expect(repository.detailQueries.single.branchId, 43);
    expect(find.text('30A-123.45'), findsOneWidget);
    expect(find.text('12.450 kg', findRichText: true), findsOneWidget);
    expect(find.text('1 phiếu cân'.toUpperCase()), findsOneWidget);
  });
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
  _DelayedWeighStationRepository({
    this.stations = const [WeighStationStation(id: 42, name: 'Trạm cân 42')],
    this.tickets = const [],
  });

  final List<WeighStationStation> stations;
  final List<WeighStationItem> tickets;
  final List<WeighStationSearchQuery> detailQueries = [];
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
  }) async => stations;

  @override
  Future<WeighStationFilterOptions> getFilterOptions(
    WeighStationFilterQuery query, {
    ApiRequestCancellation? cancellation,
  }) => _options.future;

  @override
  Future<WeighStationPage> searchDetail(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    detailQueries.add(query);
    return WeighStationPage(
      items: tickets,
      pageNumber: 1,
      pageSize: 20,
      totalCount: tickets.length,
      totalPages: tickets.isEmpty ? 0 : 1,
      canViewMaterialValue: false,
    );
  }

  @override
  Future<WeighStationSummary> searchSummary(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) async => const WeighStationSummary(
    items: [],
    pageNumber: 1,
    pageSize: 20,
    totalCount: 0,
    totalPages: 0,
    totalGoodsWeightKg: 0,
    totalConvertedQuantities: [],
    groups: [],
    canViewMaterialValue: false,
  );

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
