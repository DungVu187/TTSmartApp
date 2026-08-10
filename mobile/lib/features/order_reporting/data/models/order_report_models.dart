import '../../../../core/network/json_helpers.dart';
import '../../../../core/utils/vietnam_time.dart';

class OrderReportStation {
  const OrderReportStation({
    required this.id,
    required this.companyId,
    required this.name,
    required this.typeTram,
    this.companyName,
  });

  factory OrderReportStation.fromJson(Object? value) {
    final json = requireJsonObject(value, 'trạm báo cáo đơn hàng');
    return OrderReportStation(
      id: requireInt(json, 'id'),
      companyId: optionalInt(json, 'companyId'),
      name: optionalString(json, 'name'),
      typeTram: optionalInt(json, 'typeTram'),
      companyName: optionalString(json, 'companyName'),
    );
  }

  final int id;
  final int? companyId;
  final String? name;
  final int? typeTram;
  final String? companyName;

  String get displayName {
    final normalized = name?.trim();
    return normalized == null || normalized.isEmpty ? 'Trạm #$id' : normalized;
  }

  String get scopedDisplayName {
    final company = companyName?.trim();
    return company == null || company.isEmpty
        ? displayName
        : '$company • $displayName';
  }
}

class OrderReportEmployee {
  const OrderReportEmployee({required this.name});

  factory OrderReportEmployee.fromJson(Object? value) {
    final json = requireJsonObject(value, 'nhân viên báo cáo đơn hàng');
    final name = requireString(json, 'name').trim();
    if (name.isEmpty) {
      throw const FormatException('name nhân viên không được để trống.');
    }
    return OrderReportEmployee(name: name);
  }

  final String name;
}

class OrderReportItem {
  const OrderReportItem({
    required this.orderId,
    required this.branchId,
    required this.stationName,
    required this.customerName,
    required this.projectName,
    required this.concreteGradeName,
    required this.orderedVolume,
    required this.producedVolume,
    required this.orderedAtUtc,
    required this.employeeName,
    this.companyId,
    this.companyName,
  });

  factory OrderReportItem.fromJson(Object? value) {
    final json = requireJsonObject(value, 'dòng báo cáo đơn hàng');
    return OrderReportItem(
      orderId: requireInt(json, 'orderId'),
      branchId: requireInt(json, 'branchId'),
      stationName: optionalString(json, 'stationName'),
      customerName: optionalString(json, 'customerName'),
      projectName: optionalString(json, 'projectName'),
      concreteGradeName: optionalString(json, 'concreteGradeName'),
      orderedVolume: _optionalDouble(json, 'orderedVolume'),
      producedVolume: _optionalDouble(json, 'producedVolume'),
      orderedAtUtc: optionalUtcDateTime(json, 'orderedAtUtc'),
      employeeName: optionalString(json, 'employeeName'),
      companyId: optionalInt(json, 'companyId'),
      companyName: optionalString(json, 'companyName'),
    );
  }

  final int orderId;
  final int branchId;
  final String? stationName;
  final String? customerName;
  final String? projectName;
  final String? concreteGradeName;
  final double? orderedVolume;
  final double? producedVolume;
  final DateTime? orderedAtUtc;
  final String? employeeName;
  final int? companyId;
  final String? companyName;
}

class OrderReportStationSummary {
  const OrderReportStationSummary({
    required this.branchId,
    required this.companyId,
    required this.companyName,
    required this.stationName,
    required this.orderCount,
    required this.orderedVolume,
    required this.producedVolume,
  });

  factory OrderReportStationSummary.fromJson(Object? value) {
    final json = requireJsonObject(value, 'order report station summary');
    return OrderReportStationSummary(
      branchId: requireInt(json, 'branchId'),
      companyId: optionalInt(json, 'companyId'),
      companyName: optionalString(json, 'companyName'),
      stationName: optionalString(json, 'stationName'),
      orderCount: requireInt(json, 'orderCount'),
      orderedVolume: _requireDouble(json, 'orderedVolume'),
      producedVolume: _requireDouble(json, 'producedVolume'),
    );
  }

  final int branchId;
  final int? companyId;
  final String? companyName;
  final String? stationName;
  final int orderCount;
  final double orderedVolume;
  final double producedVolume;

  String get displayName {
    final station = stationName?.trim();
    return station == null || station.isEmpty ? 'Trạm #$branchId' : station;
  }
}

class OrderReportUnavailableStation {
  const OrderReportUnavailableStation({
    required this.branchId,
    required this.companyId,
    required this.companyName,
    required this.stationName,
  });

  factory OrderReportUnavailableStation.fromJson(Object? value) {
    final json = requireJsonObject(value, 'trạm chưa thể tải báo cáo');
    return OrderReportUnavailableStation(
      branchId: requireInt(json, 'branchId'),
      companyId: optionalInt(json, 'companyId'),
      companyName: optionalString(json, 'companyName'),
      stationName: optionalString(json, 'stationName'),
    );
  }

  final int branchId;
  final int? companyId;
  final String? companyName;
  final String? stationName;

  String get displayName {
    final station = stationName?.trim();
    return station == null || station.isEmpty ? 'Trạm #$branchId' : station;
  }

  String get scopedDisplayName {
    final company = companyName?.trim();
    return company == null || company.isEmpty
        ? displayName
        : '$company • $displayName';
  }
}

class OrderReportPage {
  const OrderReportPage({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.totalOrderedVolume,
    required this.totalProducedVolume,
    this.stationSummaries = const <OrderReportStationSummary>[],
    this.isPartial = false,
    this.successfulStationCount = 0,
    this.unavailableStationCount = 0,
    this.unavailableStations = const <OrderReportUnavailableStation>[],
  });

  factory OrderReportPage.fromJson(Object? value) {
    final json = requireJsonObject(value, 'response báo cáo đơn hàng');
    return OrderReportPage(
      items: requireJsonList(
        json['items'],
        'items',
      ).map(OrderReportItem.fromJson).toList(growable: false),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
      totalOrderedVolume: _requireDouble(json, 'totalOrderedVolume'),
      totalProducedVolume: _requireDouble(json, 'totalProducedVolume'),
      stationSummaries: requireJsonList(
        json['stationSummaries'],
        'stationSummaries',
      ).map(OrderReportStationSummary.fromJson).toList(growable: false),
      isPartial: requireBool(json, 'isPartial'),
      successfulStationCount: requireInt(json, 'successfulStationCount'),
      unavailableStationCount: requireInt(json, 'unavailableStationCount'),
      unavailableStations: requireJsonList(
        json['unavailableStations'],
        'unavailableStations',
      ).map(OrderReportUnavailableStation.fromJson).toList(growable: false),
    );
  }

  final List<OrderReportItem> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final double totalOrderedVolume;
  final double totalProducedVolume;
  final List<OrderReportStationSummary> stationSummaries;
  final bool isPartial;
  final int successfulStationCount;
  final int unavailableStationCount;
  final List<OrderReportUnavailableStation> unavailableStations;
}

class OrderReportQuery {
  const OrderReportQuery({
    this.branchId,
    this.companyId,
    required this.fromDate,
    required this.toDate,
    this.employeeName,
    this.pageNumber = 1,
    this.pageSize = 10,
  });

  final int? branchId;
  final int? companyId;
  final DateTime fromDate;
  final DateTime toDate;
  final String? employeeName;
  final int pageNumber;
  final int pageSize;

  OrderReportQuery withPageNumber(int value) => OrderReportQuery(
    branchId: branchId,
    companyId: companyId,
    fromDate: fromDate,
    toDate: toDate,
    employeeName: employeeName,
    pageNumber: value,
    pageSize: pageSize,
  );

  Map<String, Object?> toQueryParameters() => <String, Object?>{
    if (branchId != null) 'branchId': branchId,
    if (companyId != null) 'companyId': companyId,
    'from': formatVietnamDateTimeOffset(fromDate),
    'to': formatVietnamDateTimeOffset(toDate),
    'employeeName': _normalizedEmployeeName,
    'pageNumber': pageNumber,
    'pageSize': pageSize,
  };

  String? get _normalizedEmployeeName {
    final normalized = employeeName?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

String formatVietnamDateTimeOffset(DateTime value) {
  return formatVietnamIsoOffset(value);
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key phải là số.');
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key phải là số hoặc null.');
}
