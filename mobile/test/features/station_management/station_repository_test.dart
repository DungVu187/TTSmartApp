import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/station_management/data/models/station_models.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';

http.Response jsonResponse(Object value, [int statusCode = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), statusCode);

Map<String, Object?> detailJson() => <String, Object?>{
  'id': 12,
  'companyId': 1,
  'companyName': 'Công ty 1',
  'code': 'TRAM_1',
  'name': 'Trạm 1',
  'email': 'tram1@example.test',
  'phone': '0900000000',
  'address': null,
  'typeTram': 2,
  'username': 'tram_user',
  'password': '••••••••',
  'pmqlXe': null,
  'qlCamera': null,
  'status': 1,
  'isActive': true,
  'createdAtUtc': null,
  'updatedAtUtc': null,
};

void main() {
  test('getStations sends supported pagination and filters', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/branches');
        expect(request.url.queryParameters, {
          'pageNumber': '2',
          'pageSize': '20',
          'search': 'tram',
          'companyId': '22',
          'typeTram': '2',
          'status': '99',
        });
        return jsonResponse({
          'items': [
            {'id': 12, 'name': 'Trạm 1', 'phone': '0900000000', 'typeTram': 2},
          ],
          'pageNumber': 2,
          'pageSize': 20,
          'totalCount': 21,
          'totalPages': 2,
        });
      }),
    )..accessToken = 'token';
    final repository = ApiStationRepository(client);

    final page = await repository.getStations(
      pageNumber: 2,
      search: ' tram ',
      companyId: 22,
      typeTram: 2,
      status: StationDataStatus.deleted,
    );

    expect(page.items.single.id, 12);
    expect(page.items.single.type, StationType.scale);
  });

  test('updateStation omits fields outside the allowlist when null', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/branches/12');
        expect(jsonDecode(request.body), {
          'code': 'TRAM_1_UPDATED',
          'name': 'Trạm đã sửa',
          'email': 'updated@example.test',
          'phone': '0911111111',
          'address': '',
          'pmqlXe': '',
          'qlCamera': 'camera-v2',
        });
        return jsonResponse(detailJson());
      }),
    )..accessToken = 'token';
    final repository = ApiStationRepository(client);

    final station = await repository.updateStation(
      12,
      const UpdateStationRequest(
        code: 'TRAM_1_UPDATED',
        name: 'Trạm đã sửa',
        email: 'updated@example.test',
        phone: '0911111111',
        address: '',
        pmqlXe: '',
        qlCamera: 'camera-v2',
      ),
    );

    expect(station.id, 12);
  });
}
