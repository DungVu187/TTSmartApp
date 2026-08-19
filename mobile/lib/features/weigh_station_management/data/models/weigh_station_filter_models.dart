import '../../../../core/network/json_helpers.dart';
import '../../../../core/utils/vietnam_time.dart';

enum WeighStationStage {
  first,
  second;

  String get apiValue => switch (this) {
    WeighStationStage.first => 'First',
    WeighStationStage.second => 'Second',
  };

  String get label => switch (this) {
    WeighStationStage.first => 'Xe chưa ra',
    WeighStationStage.second => 'Xe đã ra',
  };
}

class WeighStationStation {
  const WeighStationStation({required this.id, required this.name});

  factory WeighStationStation.fromJson(Object? value) {
    final json = requireJsonObject(value, 'trạm cân');
    return WeighStationStation(
      id: requireInt(json, 'stationId'),
      name: optionalString(json, 'stationName'),
    );
  }

  final int id;
  final String? name;

  String get displayName {
    final normalized = name?.trim();
    return normalized == null || normalized.isEmpty ? 'Trạm #$id' : normalized;
  }
}

class WeighStationFilterOptions {
  const WeighStationFilterOptions({
    required this.vehiclePlates,
    required this.goodsNames,
    required this.operatorNames,
    required this.unitNames,
    required this.weighingTypes,
  });

  factory WeighStationFilterOptions.fromJson(Object? value) {
    final json = requireJsonObject(value, 'bộ lọc cân ô tô');
    return WeighStationFilterOptions(
      vehiclePlates: _stringList(json, 'vehiclePlates'),
      goodsNames: _stringList(json, 'goodsNames'),
      operatorNames: _stringList(json, 'operatorNames'),
      unitNames: _stringList(json, 'unitNames'),
      weighingTypes: _stringList(json, 'weighingTypes'),
    );
  }

  static const empty = WeighStationFilterOptions(
    vehiclePlates: <String>[],
    goodsNames: <String>[],
    operatorNames: <String>[],
    unitNames: <String>[],
    weighingTypes: <String>[],
  );

  final List<String> vehiclePlates;
  final List<String> goodsNames;
  final List<String> operatorNames;
  final List<String> unitNames;
  final List<String> weighingTypes;
}

class WeighStationFilterQuery {
  const WeighStationFilterQuery({
    required this.branchId,
    required this.from,
    required this.to,
    this.companyId,
    this.stage,
  });

  final int? companyId;
  final int branchId;
  final WeighStationStage? stage;
  final DateTime from;
  final DateTime to;

  Map<String, Object?> toQueryParameters() => <String, Object?>{
    'companyId': companyId,
    'branchId': branchId,
    if (stage case final stage?) 'stage': stage.apiValue,
    'from': formatVietnamIsoOffset(from),
    'to': formatVietnamIsoOffset(to),
  };
}

class WeighStationSearchQuery {
  const WeighStationSearchQuery({
    required this.branchId,
    required this.from,
    required this.to,
    required this.pageNumber,
    this.companyId,
    this.stage,
    this.vehiclePlate,
    this.goodsName,
    this.operatorName,
    this.unitName,
    this.weighingType,
  });

  final int? companyId;
  final int branchId;
  final WeighStationStage? stage;
  final DateTime from;
  final DateTime to;
  final String? vehiclePlate;
  final String? goodsName;
  final String? operatorName;
  final String? unitName;
  final String? weighingType;
  final int pageNumber;

  WeighStationSearchQuery withPageNumber(int value) => WeighStationSearchQuery(
    companyId: companyId,
    branchId: branchId,
    stage: stage,
    from: from,
    to: to,
    vehiclePlate: vehiclePlate,
    goodsName: goodsName,
    operatorName: operatorName,
    unitName: unitName,
    weighingType: weighingType,
    pageNumber: value,
  );

  Map<String, Object?> toQueryParameters({bool includePageNumber = true}) =>
      <String, Object?>{
        'companyId': companyId,
        'branchId': branchId,
        if (stage case final stage?) 'stage': stage.apiValue,
        'from': formatVietnamIsoOffset(from),
        'to': formatVietnamIsoOffset(to),
        'vehiclePlate': _normalized(vehiclePlate),
        'goodsName': _normalized(goodsName),
        'operatorName': _normalized(operatorName),
        'unitName': _normalized(unitName),
        'weighingType': _normalized(weighingType),
        if (includePageNumber) 'pageNumber': pageNumber,
      };
}

List<String> _stringList(Map<String, dynamic> json, String key) =>
    requireJsonList(json[key], key)
        .map((value) {
          if (value is String) return value;
          throw FormatException('$key phải là danh sách chuỗi.');
        })
        .toList(growable: false);

String? _normalized(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
