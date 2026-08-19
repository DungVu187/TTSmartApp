import '../../../../core/network/json_helpers.dart';
import '../../../../core/utils/vietnam_time.dart';

enum ReportViewMode {
  detail,
  total;

  String get apiValue => switch (this) {
    ReportViewMode.detail => 'detail',
    ReportViewMode.total => 'total',
  };

  String get label => switch (this) {
    ReportViewMode.detail => 'Chi tiết',
    ReportViewMode.total => 'Tổng hợp',
  };

  static ReportViewMode fromApi(String value) => switch (value) {
    'detail' => ReportViewMode.detail,
    'total' => ReportViewMode.total,
    _ => throw FormatException('viewMode không hợp lệ.'),
  };
}

class OrderStatisticsStation {
  const OrderStatisticsStation({
    required this.id,
    required this.companyId,
    required this.name,
    required this.typeTram,
    required this.companyName,
    this.code,
  });

  factory OrderStatisticsStation.fromJson(Object? value) {
    final json = requireJsonObject(value, 'trạm thống kê');
    return OrderStatisticsStation(
      id: requireInt(json, 'id'),
      companyId: optionalInt(json, 'companyId'),
      name: optionalString(json, 'name'),
      typeTram: optionalInt(json, 'typeTram'),
      companyName: optionalString(json, 'companyName'),
      code: optionalString(json, 'code'),
    );
  }

  final int id;
  final int? companyId;
  final String? name;
  final int? typeTram;
  final String? companyName;
  final String? code;

  String get displayName => _stationDisplayName(name);
}

class OrderStatisticsFilterOptions {
  const OrderStatisticsFilterOptions({
    required this.vehiclePlates,
    required this.customerNames,
    required this.concreteGradeNames,
    required this.employeeNames,
  });

  factory OrderStatisticsFilterOptions.fromJson(Object? value) {
    final json = requireJsonObject(value, 'bộ lọc thống kê');
    return OrderStatisticsFilterOptions(
      vehiclePlates: _stringList(json, 'vehiclePlates'),
      customerNames: _stringList(json, 'customerNames'),
      concreteGradeNames: _stringList(json, 'concreteGradeNames'),
      employeeNames: _stringList(json, 'employeeNames'),
    );
  }

  static const empty = OrderStatisticsFilterOptions(
    vehiclePlates: <String>[],
    customerNames: <String>[],
    concreteGradeNames: <String>[],
    employeeNames: <String>[],
  );

  final List<String> vehiclePlates;
  final List<String> customerNames;
  final List<String> concreteGradeNames;
  final List<String> employeeNames;
}

class OrderStatisticsFilterQuery {
  const OrderStatisticsFilterQuery({
    required this.from,
    required this.to,
    required this.branchId,
    this.companyId,
  });

  final DateTime from;
  final DateTime to;
  final int? companyId;
  final int? branchId;

  Map<String, Object?> toQueryParameters() => <String, Object?>{
    'companyId': companyId,
    'branchId': branchId,
    'from': formatOrderStatisticsDateTime(from),
    'to': formatOrderStatisticsDateTime(to),
  };
}

class OrderStatisticsQuery {
  const OrderStatisticsQuery({
    required this.from,
    required this.to,
    required this.branchId,
    required this.viewMode,
    required this.pageNumber,
    this.companyId,
    this.vehiclePlate,
    this.customerName,
    this.concreteGradeName,
    this.employeeName,
  });

  final DateTime from;
  final DateTime to;
  final int? companyId;
  final int? branchId;
  final String? vehiclePlate;
  final String? customerName;
  final String? concreteGradeName;
  final String? employeeName;
  final ReportViewMode viewMode;
  final int pageNumber;

  Map<String, Object?> toQueryParameters() => <String, Object?>{
    'companyId': companyId,
    'branchId': branchId,
    'from': formatOrderStatisticsDateTime(from),
    'to': formatOrderStatisticsDateTime(to),
    'vehiclePlate': _normalized(vehiclePlate),
    'customerName': _normalized(customerName),
    'concreteGradeName': _normalized(concreteGradeName),
    'employeeName': _normalized(employeeName),
    'viewMode': viewMode.apiValue,
    'pageNumber': pageNumber,
    'pageSize': pageSize,
  };

  static const int pageSize = 10;
}

class OrderStatisticsMaterial {
  const OrderStatisticsMaterial({
    required this.materialSlotId,
    required this.slotNumber,
    required this.materialName,
    required this.category,
    required this.designQuantity,
    required this.tQuantity,
    required this.actualQuantity,
    required this.variance,
    this.categoryCode = '',
    this.typePosition = 0,
    this.columnKey = '',
  });

  factory OrderStatisticsMaterial.fromJson(Object? value) {
    final json = requireJsonObject(value, 'vật liệu mẻ trộn');
    return OrderStatisticsMaterial(
      materialSlotId: optionalInt(json, 'materialSlotId'),
      slotNumber: requireInt(json, 'slotNumber'),
      materialName: optionalString(json, 'materialName'),
      category: optionalString(json, 'category'),
      categoryCode: _stringOrEmpty(json, 'categoryCode'),
      typePosition: _intOrZero(json, 'typePosition'),
      columnKey: _stringOrEmpty(json, 'columnKey'),
      designQuantity: _numberOrZero(json, 'designQuantity'),
      tQuantity: _numberOrZero(json, 'tQuantity'),
      actualQuantity: _numberOrZero(json, 'actualQuantity'),
      variance: _numberOrZero(json, 'variance'),
    );
  }

  final int? materialSlotId;
  final int slotNumber;
  final String? materialName;
  final String? category;
  final String categoryCode;
  final int typePosition;
  final String columnKey;
  final double designQuantity;
  final double tQuantity;
  final double actualQuantity;
  final double variance;
}

class OrderStatisticsMaterialColumn {
  const OrderStatisticsMaterialColumn({
    required this.materialSlotId,
    required this.slotNumber,
    required this.materialName,
    required this.category,
    required this.designLabel,
    required this.tLabel,
    required this.actualLabel,
    required this.varianceLabel,
    required this.unit,
    this.categoryCode = '',
    this.typePosition = 0,
    this.columnKey = '',
  });

  factory OrderStatisticsMaterialColumn.fromJson(Object? value) {
    final json = requireJsonObject(value, 'cột vật liệu');
    return OrderStatisticsMaterialColumn(
      materialSlotId: optionalInt(json, 'materialSlotId'),
      slotNumber: requireInt(json, 'slotNumber'),
      materialName: optionalString(json, 'materialName'),
      category: optionalString(json, 'category'),
      categoryCode: _stringOrEmpty(json, 'categoryCode'),
      typePosition: _intOrZero(json, 'typePosition'),
      columnKey: _stringOrEmpty(json, 'columnKey'),
      designLabel: requireString(json, 'designLabel'),
      tLabel: requireString(json, 'tLabel'),
      actualLabel: requireString(json, 'actualLabel'),
      varianceLabel: requireString(json, 'varianceLabel'),
      unit: optionalString(json, 'unit'),
    );
  }

  final int? materialSlotId;
  final int slotNumber;
  final String? materialName;
  final String? category;
  final String categoryCode;
  final int typePosition;
  final String columnKey;
  final String designLabel;
  final String tLabel;
  final String actualLabel;
  final String varianceLabel;
  final String? unit;
}

class OrderStatisticsMaterialLayout {
  const OrderStatisticsMaterialLayout({
    required this.layoutKey,
    required this.columns,
  });

  factory OrderStatisticsMaterialLayout.fromJson(Object? value) {
    final json = requireJsonObject(value, 'layout vật liệu');
    return OrderStatisticsMaterialLayout(
      layoutKey: requireString(json, 'layoutKey'),
      columns: _objectList(
        json,
        'columns',
        OrderStatisticsMaterialColumn.fromJson,
      ),
    );
  }

  final String layoutKey;
  final List<OrderStatisticsMaterialColumn> columns;
}

class OrderStatisticsMaterialSummaryCell {
  const OrderStatisticsMaterialSummaryCell({
    required this.categoryCode,
    required this.typePosition,
    required this.materialSlotId,
    required this.slotNumber,
    required this.materialName,
    required this.category,
    required this.columnKey,
    this.unit,
    required this.actualQuantity,
  });

  factory OrderStatisticsMaterialSummaryCell.fromJson(Object? value) {
    final json = requireJsonObject(value, 'ô tổng vật liệu');
    return OrderStatisticsMaterialSummaryCell(
      categoryCode: requireString(json, 'categoryCode'),
      typePosition: requireInt(json, 'typePosition'),
      materialSlotId: optionalInt(json, 'materialSlotId'),
      slotNumber: optionalInt(json, 'slotNumber'),
      materialName: optionalString(json, 'materialName'),
      category: optionalString(json, 'category'),
      columnKey: optionalString(json, 'columnKey'),
      unit: optionalString(json, 'unit'),
      actualQuantity: _numberOrZero(json, 'actualQuantity'),
    );
  }

  final String categoryCode;
  final int typePosition;
  final int? materialSlotId;
  final int? slotNumber;
  final String? materialName;
  final String? category;
  final String? columnKey;
  final String? unit;
  final double actualQuantity;
}

class OrderStatisticsMaterialSummaryRow {
  const OrderStatisticsMaterialSummaryRow({
    required this.rowNumber,
    required this.cells,
  });

  factory OrderStatisticsMaterialSummaryRow.fromJson(Object? value) {
    final json = requireJsonObject(value, 'dòng tổng vật liệu động');
    return OrderStatisticsMaterialSummaryRow(
      rowNumber: requireInt(json, 'rowNumber'),
      cells: _objectList(
        json,
        'cells',
        OrderStatisticsMaterialSummaryCell.fromJson,
      ),
    );
  }

  final int rowNumber;
  final List<OrderStatisticsMaterialSummaryCell> cells;
}

class OrderStatisticsItem {
  const OrderStatisticsItem({
    required this.rowNumber,
    required this.stationId,
    required this.stationName,
    required this.mixingDate,
    required this.startedAt,
    required this.finishedAt,
    required this.customerName,
    required this.projectName,
    required this.workItemName,
    required this.locationName,
    required this.vehiclePlate,
    required this.driverName,
    required this.concreteGradeName,
    required this.slump,
    required this.salesEmployeeName,
    required this.employeeName,
    required this.requestedVolume,
    required this.mixedVolume,
    required this.materials,
    this.layoutKey = '',
    this.stationCode,
  });

  factory OrderStatisticsItem.fromJson(Object? value) {
    final json = requireJsonObject(value, 'dòng thống kê');
    return OrderStatisticsItem(
      rowNumber: requireInt(json, 'rowNumber'),
      stationId: requireInt(json, 'stationId'),
      stationCode: optionalString(json, 'stationCode'),
      stationName: optionalString(json, 'stationName'),
      mixingDate: _dateOnly(json, 'mixingDate'),
      startedAt: optionalUtcDateTime(json, 'startedAt'),
      finishedAt: optionalUtcDateTime(json, 'finishedAt'),
      customerName: optionalString(json, 'customerName'),
      projectName: optionalString(json, 'projectName'),
      workItemName: optionalString(json, 'workItemName'),
      locationName: optionalString(json, 'locationName'),
      vehiclePlate: optionalString(json, 'vehiclePlate'),
      driverName: optionalString(json, 'driverName'),
      concreteGradeName: optionalString(json, 'concreteGradeName'),
      slump: optionalString(json, 'slump'),
      salesEmployeeName: optionalString(json, 'salesEmployeeName'),
      employeeName: optionalString(json, 'employeeName'),
      layoutKey: _stringOrEmpty(json, 'layoutKey'),
      requestedVolume: _number(json, 'requestedVolume'),
      mixedVolume: _number(json, 'mixedVolume'),
      materials: _objectList(
        json,
        'materials',
        OrderStatisticsMaterial.fromJson,
      ),
    );
  }

  final int rowNumber;
  final int stationId;
  final String? stationCode;
  final String? stationName;
  final DateTime? mixingDate;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? customerName;
  final String? projectName;
  final String? workItemName;
  final String? locationName;
  final String? vehiclePlate;
  final String? driverName;
  final String? concreteGradeName;
  final String? slump;
  final String? salesEmployeeName;
  final String? employeeName;
  final String layoutKey;
  final double requestedVolume;
  final double mixedVolume;
  final List<OrderStatisticsMaterial> materials;

  String get stationDisplayName => _stationDisplayName(stationName);
}

class OrderStatisticsPage {
  const OrderStatisticsPage({
    required this.items,
    required this.totalCount,
    required this.totalPages,
    required this.pageNumber,
    required this.pageSize,
    required this.fromRowNumber,
    required this.toRowNumber,
    required this.totalMaterialQuantity,
    required this.totalConcreteVolume,
    this.layouts = const <OrderStatisticsMaterialLayout>[],
    this.materialSummaryRows = const <OrderStatisticsMaterialSummaryRow>[],
  });

  factory OrderStatisticsPage.fromJson(Object? value) {
    final json = requireJsonObject(value, 'kết quả thống kê');
    return OrderStatisticsPage(
      items: _objectList(json, 'items', OrderStatisticsItem.fromJson),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      fromRowNumber: requireInt(json, 'fromRowNumber'),
      toRowNumber: requireInt(json, 'toRowNumber'),
      totalMaterialQuantity: _number(json, 'totalMaterialQuantity'),
      totalConcreteVolume: _number(json, 'totalConcreteVolume'),
      layouts: _optionalObjectList(
        json,
        'layouts',
        OrderStatisticsMaterialLayout.fromJson,
      ),
      materialSummaryRows: _optionalObjectList(
        json,
        'materialSummaryRows',
        OrderStatisticsMaterialSummaryRow.fromJson,
      ),
    );
  }

  factory OrderStatisticsPage.empty({
    required ReportViewMode viewMode,
    int pageNumber = 1,
  }) => OrderStatisticsPage(
    items: const <OrderStatisticsItem>[],
    totalCount: 0,
    totalPages: 0,
    pageNumber: pageNumber,
    pageSize: OrderStatisticsQuery.pageSize,
    fromRowNumber: 0,
    toRowNumber: 0,
    totalMaterialQuantity: 0,
    totalConcreteVolume: 0,
  );

  final List<OrderStatisticsItem> items;
  final int totalCount;
  final int totalPages;
  final int pageNumber;
  final int pageSize;
  final int fromRowNumber;
  final int toRowNumber;
  final double totalMaterialQuantity;
  final double totalConcreteVolume;
  final List<OrderStatisticsMaterialLayout> layouts;
  final List<OrderStatisticsMaterialSummaryRow> materialSummaryRows;
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final values = requireJsonList(json[key], key);
  return values
      .map((value) {
        if (value is String) return value;
        throw FormatException('$key phải là danh sách chuỗi.');
      })
      .toList(growable: false);
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
  if (json[key] == null) return List<T>.empty(growable: false);
  return _objectList(json, key, parser);
}

DateTime? _dateOnly(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('$key phải là ngày yyyy-MM-dd hoặc null.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key không hợp lệ.');
  return parsed;
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key phải là số.');
}

double _numberOrZero(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return 0;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key phải là số hoặc null.');
}

String _stringOrEmpty(Map<String, dynamic> json, String key) =>
    optionalString(json, key) ?? '';

int _intOrZero(Map<String, dynamic> json, String key) =>
    optionalInt(json, key) ?? 0;

String? _normalized(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String formatOrderStatisticsDateTime(DateTime value) {
  return formatVietnamIsoOffset(value);
}

String _stationDisplayName(String? name) {
  final normalizedName = name?.trim();
  return normalizedName == null || normalizedName.isEmpty
      ? 'Chưa xác định'
      : normalizedName;
}
