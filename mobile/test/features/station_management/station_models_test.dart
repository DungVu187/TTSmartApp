import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/station_management/data/models/station_models.dart';

Map<String, Object?> stationResponseJson({int id = 118}) => <String, Object?>{
  'id': id,
  'companyId': 22,
  'companyName': 'Công ty A',
  'code': 'tram1',
  'name': 'Trạm trộn số 1',
  'email': 'tram1@example.com',
  'phone': '0900000000',
  'address': 'Hà Nội',
  'typeTram': 1,
  'username': 'tram1_user',
  'password': '••••••••',
  'pmqlXe': null,
  'qlCamera': null,
  'status': 1,
  'isActive': true,
  'createdAtUtc': '2026-07-29T02:00:00Z',
  'updatedAtUtc': '2026-07-29T02:30:00Z',
};

void main() {
  test('parses paged station response and UTC timestamps', () {
    final page = StationPage.fromJson({
      'items': [
        {
          'id': 118,
          'name': 'Trạm trộn số 1',
          'phone': '0900000000',
          'typeTram': 1,
        },
      ],
      'pageNumber': 1,
      'pageSize': 20,
      'totalCount': 1,
      'totalPages': 1,
    });

    expect(page.items.single.displayName, 'Trạm trộn số 1');
    expect(page.items.single.type, StationType.mixing);
    expect(page.totalCount, 1);
  });

  test('maps station detail and request fields', () {
    final station = StationResponse.fromJson(stationResponseJson());
    expect(station.id, 118);
    expect(station.type, StationType.mixing);
    expect(station.createdAtUtc, DateTime.utc(2026, 7, 29, 2));
    expect(station.password, '••••••••');

    const create = CreateStationRequest(
      companyId: 22,
      code: 'tram1',
      name: 'Trạm trộn số 1',
      email: 'tram1@example.com',
      phone: '0900000000',
      username: 'tram1_user',
      password: 'Abc123@#',
      typeTram: 1,
    );
    expect(create.toJson(), {
      'companyId': 22,
      'code': 'tram1',
      'name': 'Trạm trộn số 1',
      'email': 'tram1@example.com',
      'phone': '0900000000',
      'address': null,
      'username': 'tram1_user',
      'password': 'Abc123@#',
      'pmqlXe': null,
      'qlCamera': null,
      'typeTram': 1,
    });

    const update = UpdateStationRequest(
      code: 'tram1-updated',
      address: '',
      pmqlXe: '',
      qlCamera: 'camera-v2',
    );
    expect(update.toJson(), {
      'code': 'tram1-updated',
      'address': '',
      'pmqlXe': '',
      'qlCamera': 'camera-v2',
    });
  });
}
