import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/station_management/data/models/station_models.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';
import 'package:ttsmart_mobile/features/station_management/presentation/controllers/stations_controller.dart';

class _FakeStationRepository implements StationRepository {
  final List<int> requestedPages = <int>[];
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
    requestedPages.add(pageNumber);
    requestedTypes.add(typeTram);
    final id = pageNumber == 1 ? 1 : 2;
    return StationPage(
      items: [
        StationListItem(
          id: id,
          name: 'Trạm $id',
          phone: '090000000$id',
          typeTram: typeTram ?? 1,
        ),
      ],
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: 2,
      totalPages: 2,
    );
  }

  @override
  Future<StationResponse> getStation(int id) => throw UnimplementedError();

  @override
  Future<StationResponse> createStation(CreateStationRequest request) =>
      throw UnimplementedError();

  @override
  Future<StationResponse> updateStation(int id, UpdateStationRequest request) =>
      throw UnimplementedError();

  @override
  Future<StationResponse> deleteStation(int id) => throw UnimplementedError();

  @override
  Future<StationResponse> restoreStation(int id) => throw UnimplementedError();
}

void main() {
  test('loads pages, removes duplicate ids and preserves filters', () async {
    final repository = _FakeStationRepository();
    final controller = StationsController(repository);
    controller.setTypeTram(StationType.scale.value);
    controller.setCompanyId(22);

    await controller.load();
    await controller.loadMore();

    expect(controller.items.map((item) => item.id), [1, 2]);
    expect(controller.totalCount, 2);
    expect(repository.requestedPages, [1, 2]);
    expect(repository.requestedTypes, [2, 2]);

    controller.dispose();
  });
}
