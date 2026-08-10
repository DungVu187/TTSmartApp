import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/network/api_exception.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/models/mix_design_models.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';

http.Response _jsonResponse(Object value) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), 200);

void main() {
  test('sends company station and page parameters to mix design API', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/stations')) {
          return _jsonResponse([
            {'stationId': 10, 'stationName': 'Trạm 10'},
          ]);
        }
        return _jsonResponse({
          'items': <Object?>[],
          'pageNumber': 2,
          'pageSize': 10,
          'totalCount': 12,
          'totalPages': 2,
        });
      }),
    )..accessToken = 'token';
    final repository = ApiMixDesignRepository(client);

    final stations = await repository.getStations(companyId: 3);
    final page = await repository.getMixDesigns(
      const MixDesignQuery(companyId: 3, stationId: 10, pageNumber: 2),
    );

    expect(stations.single.displayName, 'Trạm 10');
    expect(page.pageNumber, 2);
    expect(requests[0].url.path, '/api/mix-designs/stations');
    expect(requests[0].url.queryParameters, {'companyId': '3'});
    expect(requests[1].url.path, '/api/mix-designs');
    expect(requests[1].url.queryParameters, {
      'companyId': '3',
      'stationId': '10',
      'pageNumber': '2',
    });
    client.close();
  });

  test('maps malformed response to invalid response error', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((_) async => _jsonResponse({'items': 'invalid'})),
    )..accessToken = 'token';
    final repository = ApiMixDesignRepository(client);

    expect(
      () => repository.getMixDesigns(
        const MixDesignQuery(stationId: 10, pageNumber: 1),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.type,
          'type',
          ApiFailureType.invalidResponse,
        ),
      ),
    );
    client.close();
  });
}
