import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/files/export_file.dart';
import 'package:ttsmart_mobile/core/network/api_request_cancellation.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_filter_models.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_result_models.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/repositories/weigh_station_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/presentation/controllers/weigh_station_controller.dart';

void main() {
  test('không chọn stage vẫn tải options và tìm kiếm được', () async {
    final repository = _FakeWeighStationRepository();
    final controller = WeighStationController(
      repository: repository,
      companyRepository: _UnusedCompanyRepository(),
      isAdmin: false,
      initialCompanyId: 7,
      now: () => DateTime(2026, 8, 10),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.selectStation(42);

    expect(controller.selectedStage, isNull);
    expect(controller.canLoadOptions, isTrue);
    expect(repository.filterQueries.single.stage, isNull);

    await controller.search();

    expect(controller.hasSearched, isTrue);
    expect(repository.detailQueries.single.stage, isNull);
    expect(repository.summaryQueries.single.stage, isNull);
    expect(controller.feedbackMessage, isNot('Chưa chọn giai đoạn cân.'));
  });
}

class _FakeWeighStationRepository implements WeighStationRepository {
  final filterQueries = <WeighStationFilterQuery>[];
  final detailQueries = <WeighStationSearchQuery>[];
  final summaryQueries = <WeighStationSearchQuery>[];

  @override
  Future<List<WeighStationStation>> getStations({
    int? companyId,
    ApiRequestCancellation? cancellation,
  }) async => const [WeighStationStation(id: 42, name: 'Trạm cân 42')];

  @override
  Future<WeighStationFilterOptions> getFilterOptions(
    WeighStationFilterQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    filterQueries.add(query);
    return WeighStationFilterOptions.empty;
  }

  @override
  Future<WeighStationPage> searchDetail(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    detailQueries.add(query);
    return const WeighStationPage(
      items: [],
      pageNumber: 1,
      pageSize: 10,
      totalCount: 0,
      totalPages: 0,
      canViewMaterialValue: false,
    );
  }

  @override
  Future<WeighStationSummary> searchSummary(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    summaryQueries.add(query);
    return const WeighStationSummary(
      items: [],
      pageNumber: 1,
      pageSize: 10,
      totalCount: 0,
      totalPages: 0,
      totalGoodsWeightKg: 0,
      totalConvertedQuantities: [],
      groups: [],
      canViewMaterialValue: false,
    );
  }

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
  Future<CompanyResponse> getCompany(int id) => throw UnimplementedError();

  @override
  Future<CompanyResponse> createCompany(CompanyUpsertRequest request) =>
      throw UnimplementedError();

  @override
  Future<CompanyResponse> updateCompany(int id, CompanyUpsertRequest request) =>
      throw UnimplementedError();

  @override
  Future<CompanyResponse> setCompanyLock(int id, bool isLocked) =>
      throw UnimplementedError();

  @override
  Future<CompanyResponse> setCompanyExpiration(int id, DateTime? expiredDate) =>
      throw UnimplementedError();

  @override
  Future<CompanyResponse> uploadCompanyLogo({
    required int id,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) => throw UnimplementedError();

  @override
  Future<Uint8List> getCompanyLogo(int id) => throw UnimplementedError();

  @override
  Future<CompanyResponse> deleteCompany(int id) => throw UnimplementedError();

  @override
  Future<CompanyResponse> restoreCompany(int id) => throw UnimplementedError();
}
