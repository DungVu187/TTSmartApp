import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_helpers.dart';
import '../models/mix_design_models.dart';

abstract interface class MixDesignRepository {
  Future<List<MixDesignStation>> getStations({int? companyId});

  Future<MixDesignPage> getMixDesigns(MixDesignQuery query);
}

class ApiMixDesignRepository implements MixDesignRepository {
  ApiMixDesignRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<MixDesignStation>> getStations({int? companyId}) async {
    _validateId(companyId, 'companyId');
    final response = await _apiClient.get(
      '/api/mix-designs/stations',
      query: <String, Object?>{'companyId': companyId},
    );
    return _parse(
      () => requireJsonList(
        response,
        'danh sách trạm cấp phối',
      ).map(MixDesignStation.fromJson).toList(growable: false),
    );
  }

  @override
  Future<MixDesignPage> getMixDesigns(MixDesignQuery query) async {
    _validateId(query.companyId, 'companyId');
    _validateId(query.stationId, 'stationId');
    if (query.pageNumber < 1) {
      throw ArgumentError.value(query.pageNumber, 'pageNumber');
    }
    final response = await _apiClient.get(
      '/api/mix-designs',
      query: query.toQueryParameters(),
    );
    return _parse(() => MixDesignPage.fromJson(response));
  }

  void _validateId(int? value, String name) {
    if (value != null && value < 1) {
      throw ArgumentError.value(value, name, 'Phải lớn hơn 0.');
    }
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException.invalidResponse(error.message);
    }
  }
}
