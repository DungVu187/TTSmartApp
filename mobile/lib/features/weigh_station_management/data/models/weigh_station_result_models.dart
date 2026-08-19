import '../../../../core/network/json_helpers.dart';

class WeighStationItem {
  const WeighStationItem({
    required this.stt,
    required this.id,
    required this.ticketNumber,
    required this.hasConversionConfiguration,
    this.ticketCode,
    this.weighingAt,
    this.vehiclePlate,
    this.driverName,
    this.sealNumber,
    this.inboundWeightKg,
    this.outboundWeightKg,
    this.goodsWeightKg,
    this.convertedQuantity,
    this.convertedUnit,
    this.conversionMessage,
    this.materialValueVnd,
    this.unitName,
    this.goodsName,
    this.weighingType,
    this.firstOperatorName,
    this.secondOperatorName,
    this.weighedInAt,
    this.weighedOutAt,
  });

  factory WeighStationItem.fromJson(Object? value) {
    final json = requireJsonObject(value, 'phiếu cân');
    return WeighStationItem(
      stt: requireInt(json, 'stt'),
      id: requireString(json, 'id'),
      ticketNumber: requireInt(json, 'ticketNumber'),
      ticketCode: optionalString(json, 'ticketCode'),
      weighingAt: optionalUtcDateTime(json, 'weighingAt'),
      vehiclePlate: optionalString(json, 'vehiclePlate'),
      driverName: optionalString(json, 'driverName'),
      sealNumber: optionalString(json, 'sealNumber'),
      inboundWeightKg: _optionalNumber(json, 'inboundWeightKg'),
      outboundWeightKg: _optionalNumber(json, 'outboundWeightKg'),
      goodsWeightKg: _optionalNumber(json, 'goodsWeightKg'),
      hasConversionConfiguration: requireBool(
        json,
        'hasConversionConfiguration',
      ),
      convertedQuantity: _optionalNumber(json, 'convertedQuantity'),
      convertedUnit: optionalString(json, 'convertedUnit'),
      conversionMessage: _optionalTrimmedString(json, 'conversionMessage'),
      materialValueVnd: _optionalNumber(json, 'materialValueVnd'),
      unitName: optionalString(json, 'unitName'),
      goodsName: optionalString(json, 'goodsName'),
      weighingType: optionalString(json, 'weighingType'),
      firstOperatorName: optionalString(json, 'firstOperatorName'),
      secondOperatorName: optionalString(json, 'secondOperatorName'),
      weighedInAt: optionalUtcDateTime(json, 'weighedInAt'),
      weighedOutAt: optionalUtcDateTime(json, 'weighedOutAt'),
    );
  }

  final int stt;
  final String id;
  final int ticketNumber;
  final String? ticketCode;
  final DateTime? weighingAt;
  final String? vehiclePlate;
  final String? driverName;
  final String? sealNumber;
  final double? inboundWeightKg;
  final double? outboundWeightKg;
  final double? goodsWeightKg;
  final bool hasConversionConfiguration;
  final double? convertedQuantity;
  final String? convertedUnit;
  final String? conversionMessage;
  final double? materialValueVnd;
  final String? unitName;
  final String? goodsName;
  final String? weighingType;
  final String? firstOperatorName;
  final String? secondOperatorName;
  final DateTime? weighedInAt;
  final DateTime? weighedOutAt;
}

class WeighStationPage {
  const WeighStationPage({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.canViewMaterialValue,
  });

  factory WeighStationPage.fromJson(Object? value) {
    final json = requireJsonObject(value, 'kết quả phiếu cân');
    return WeighStationPage(
      items: _objectList(json, 'items', WeighStationItem.fromJson),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
      canViewMaterialValue: requireBool(json, 'canViewMaterialValue'),
    );
  }

  final List<WeighStationItem> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool canViewMaterialValue;
}

class WeighStationConvertedQuantity {
  const WeighStationConvertedQuantity({
    required this.quantity,
    required this.unit,
  });

  factory WeighStationConvertedQuantity.fromJson(Object? value) {
    final json = requireJsonObject(value, 'khối lượng quy đổi');
    return WeighStationConvertedQuantity(
      quantity: _requiredNumber(json, 'quantity'),
      unit: requireString(json, 'unit'),
    );
  }

  final double quantity;
  final String unit;
}

class WeighStationSummaryItem {
  const WeighStationSummaryItem({
    required this.stt,
    required this.goodsWeightKg,
    required this.convertedQuantities,
    this.ticketCount = 0,
    this.goodsName,
    this.conversionMessage,
    this.materialValueVnd,
  });

  factory WeighStationSummaryItem.fromJson(Object? value) {
    final json = requireJsonObject(value, 'dòng tổng hợp cân');
    return WeighStationSummaryItem(
      stt: requireInt(json, 'stt'),
      goodsName: optionalString(json, 'goodsName'),
      goodsWeightKg: _requiredNumber(json, 'goodsWeightKg'),
      convertedQuantities: _objectList(
        json,
        'convertedQuantities',
        WeighStationConvertedQuantity.fromJson,
      ),
      ticketCount: optionalInt(json, 'ticketCount') ?? 0,
      conversionMessage: _optionalTrimmedString(json, 'conversionMessage'),
      materialValueVnd: _optionalNumber(json, 'materialValueVnd'),
    );
  }

  final int stt;
  final String? goodsName;
  final double goodsWeightKg;
  final List<WeighStationConvertedQuantity> convertedQuantities;
  final int ticketCount;
  final String? conversionMessage;
  final double? materialValueVnd;
}

class WeighStationTopGoods {
  const WeighStationTopGoods({required this.goodsWeightKg, this.goodsName});

  factory WeighStationTopGoods.fromJson(Object? value) {
    final json = requireJsonObject(value, 'loại hàng nhiều nhất');
    return WeighStationTopGoods(
      goodsName: optionalString(json, 'goodsName'),
      goodsWeightKg: _requiredNumber(json, 'goodsWeightKg'),
    );
  }

  final String? goodsName;
  final double goodsWeightKg;
}

class WeighStationSummaryGroup {
  const WeighStationSummaryGroup({
    required this.keyName,
    required this.label,
    required this.goodsWeightKg,
    required this.convertedQuantities,
    this.materialValueVnd,
  });

  factory WeighStationSummaryGroup.fromJson(Object? value) {
    final json = requireJsonObject(value, 'nhóm tổng hợp cân');
    return WeighStationSummaryGroup(
      keyName: requireString(json, 'key'),
      label: requireString(json, 'label'),
      goodsWeightKg: _requiredNumber(json, 'goodsWeightKg'),
      convertedQuantities: _objectList(
        json,
        'convertedQuantities',
        WeighStationConvertedQuantity.fromJson,
      ),
      materialValueVnd: _optionalNumber(json, 'materialValueVnd'),
    );
  }

  final String keyName;
  final String label;
  final double goodsWeightKg;
  final List<WeighStationConvertedQuantity> convertedQuantities;
  final double? materialValueVnd;
}

class WeighStationSummary {
  const WeighStationSummary({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.totalGoodsWeightKg,
    required this.totalConvertedQuantities,
    required this.groups,
    required this.canViewMaterialValue,
    this.topGoods,
    this.totalMaterialValueVnd,
  });

  factory WeighStationSummary.fromJson(Object? value) {
    final json = requireJsonObject(value, 'tổng hợp cân ô tô');
    final topGoods = json['topGoods'];
    return WeighStationSummary(
      items: _objectList(json, 'items', WeighStationSummaryItem.fromJson),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
      totalGoodsWeightKg: _requiredNumber(json, 'totalGoodsWeightKg'),
      totalConvertedQuantities: _objectList(
        json,
        'totalConvertedQuantities',
        WeighStationConvertedQuantity.fromJson,
      ),
      topGoods: topGoods == null
          ? null
          : WeighStationTopGoods.fromJson(topGoods),
      groups: _optionalObjectList(
        json,
        'groups',
        WeighStationSummaryGroup.fromJson,
      ),
      totalMaterialValueVnd: _optionalNumber(json, 'totalMaterialValueVnd'),
      canViewMaterialValue: requireBool(json, 'canViewMaterialValue'),
    );
  }

  final List<WeighStationSummaryItem> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final double totalGoodsWeightKg;
  final List<WeighStationConvertedQuantity> totalConvertedQuantities;
  final WeighStationTopGoods? topGoods;
  final List<WeighStationSummaryGroup> groups;
  final double? totalMaterialValueVnd;
  final bool canViewMaterialValue;
}

List<T> _objectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Object?) parser,
) => requireJsonList(json[key], key).map(parser).toList(growable: false);

List<T> _optionalObjectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Object?) parser,
) {
  final value = json[key];
  if (value == null) return const [];
  return requireJsonList(value, key).map(parser).toList(growable: false);
}

double _requiredNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key phải là số.');
}

double? _optionalNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key phải là số hoặc null.');
}

String? _optionalTrimmedString(Map<String, dynamic> json, String key) {
  final value = optionalString(json, key)?.trim();
  return value == null || value.isEmpty ? null : value;
}
