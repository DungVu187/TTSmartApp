import '../../../../core/network/json_helpers.dart';
import '../../../../core/utils/vietnam_time.dart';

enum MaterialGroupFilter {
  all('all', 'Tất cả'),
  sand('sand', 'Cát'),
  stone('stone', 'Đá'),
  cement('cement', 'Xi măng'),
  water('water', 'Nước'),
  additive('additive', 'Phụ gia');

  const MaterialGroupFilter(this.code, this.label);

  final String code;
  final String label;
}

enum MaterialViewMode {
  all('all', 'Tất cả'),
  importData('import', 'Nhập'),
  exportData('export', 'Xuất'),
  inventory('inventory', 'Tồn kho'),
  stocktake('stocktake', 'Kiểm kê');

  const MaterialViewMode(this.code, this.label);

  final String code;
  final String label;
}

enum MaterialValueMode {
  quantity('quantity', 'Khối lượng'),
  value('value', 'Giá trị');

  const MaterialValueMode(this.code, this.label);

  final String code;
  final String label;
}

class MaterialReportStation {
  const MaterialReportStation({
    required this.id,
    required this.companyId,
    required this.name,
    required this.companyName,
    required this.typeTram,
  });

  factory MaterialReportStation.fromJson(Object? value) {
    final json = requireJsonObject(value, 'trạm báo cáo vật liệu');
    return MaterialReportStation(
      id: requireInt(json, 'id'),
      companyId: optionalInt(json, 'companyId'),
      name: optionalString(json, 'name'),
      companyName: optionalString(json, 'companyName'),
      typeTram: optionalInt(json, 'typeTram'),
    );
  }

  final int id;
  final int? companyId;
  final String? name;
  final String? companyName;
  final int? typeTram;

  String get displayName {
    final value = name?.trim();
    return value == null || value.isEmpty ? 'Trạm #$id' : value;
  }
}

class MaterialReportQuery {
  const MaterialReportQuery({
    required this.branchId,
    required this.from,
    required this.to,
    required this.materialGroup,
    required this.viewMode,
    required this.valueMode,
    required this.pageNumber,
    this.companyId,
  });

  final int branchId;
  final int? companyId;
  final DateTime from;
  final DateTime to;
  final MaterialGroupFilter materialGroup;
  final MaterialViewMode viewMode;
  final MaterialValueMode valueMode;
  final int pageNumber;

  Map<String, Object?> toQueryParameters() => <String, Object?>{
    'companyId': companyId,
    'branchId': branchId,
    'from': formatVietnamIsoOffset(from),
    'to': formatVietnamIsoOffset(to),
    'materialGroup': materialGroup.code,
    'viewMode': viewMode.code,
    'valueMode': valueMode.code,
    'pageNumber': pageNumber,
    'pageSize': 10,
  };
}

class MaterialReport {
  const MaterialReport({
    required this.stationId,
    required this.stationName,
    required this.from,
    required this.to,
    required this.inventoryAsOf,
    required this.groups,
    required this.chartItems,
    required this.transactions,
    required this.totalCount,
    required this.totalPages,
    required this.pageNumber,
    required this.pageSize,
    required this.fromRowNumber,
    required this.toRowNumber,
    required this.totals,
    required this.warnings,
  });

  factory MaterialReport.fromJson(Object? value) {
    final json = requireJsonObject(value, 'báo cáo vật liệu');
    return MaterialReport(
      stationId: requireInt(json, 'stationId'),
      stationName: optionalString(json, 'stationName'),
      from: requireUtcDateTime(json, 'from'),
      to: requireUtcDateTime(json, 'to'),
      inventoryAsOf: requireUtcDateTime(json, 'inventoryAsOf'),
      groups: requireJsonList(
        json['groups'],
        'groups',
      ).map(MaterialGroupSummary.fromJson).toList(growable: false),
      chartItems: requireJsonList(
        json['chartItems'],
        'chartItems',
      ).map(MaterialChartItem.fromJson).toList(growable: false),
      transactions: requireJsonList(
        json['transactions'],
        'transactions',
      ).map(MaterialTransaction.fromJson).toList(growable: false),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      fromRowNumber: requireInt(json, 'fromRowNumber'),
      toRowNumber: requireInt(json, 'toRowNumber'),
      totals: MaterialReportTotals.fromJson(json['totals']),
      warnings: requireJsonList(json['warnings'], 'warnings')
          .map((item) {
            if (item is! String) {
              throw const FormatException('warnings phải chứa chuỗi.');
            }
            return item;
          })
          .toList(growable: false),
    );
  }

  final int stationId;
  final String? stationName;
  final DateTime from;
  final DateTime to;
  final DateTime inventoryAsOf;
  final List<MaterialGroupSummary> groups;
  final List<MaterialChartItem> chartItems;
  final List<MaterialTransaction> transactions;
  final int totalCount;
  final int totalPages;
  final int pageNumber;
  final int pageSize;
  final int fromRowNumber;
  final int toRowNumber;
  final MaterialReportTotals totals;
  final List<String> warnings;
}

class MaterialGroupSummary {
  const MaterialGroupSummary({
    required this.code,
    required this.name,
    required this.materials,
  });

  factory MaterialGroupSummary.fromJson(Object? value) {
    final json = requireJsonObject(value, 'nhóm vật liệu');
    return MaterialGroupSummary(
      code: requireString(json, 'code'),
      name: requireString(json, 'name'),
      materials: requireJsonList(
        json['materials'],
        'materials',
      ).map(MaterialSummaryItem.fromJson).toList(growable: false),
    );
  }

  final String code;
  final String name;
  final List<MaterialSummaryItem> materials;
}

class MaterialSummaryItem {
  const MaterialSummaryItem({
    required this.materialCode,
    required this.name,
    required this.groupCode,
    required this.importQuantityKg,
    required this.exportQuantityKg,
    required this.inventoryQuantityKg,
    required this.importValueVnd,
    required this.exportValueVnd,
    required this.inventoryValueVnd,
    required this.hasMissingImportPrice,
  });

  factory MaterialSummaryItem.fromJson(Object? value) {
    final json = requireJsonObject(value, 'vật liệu tổng hợp');
    return MaterialSummaryItem(
      materialCode: requireInt(json, 'materialCode'),
      name: requireString(json, 'name'),
      groupCode: requireString(json, 'groupCode'),
      importQuantityKg: _requireDouble(json, 'importQuantityKg'),
      exportQuantityKg: _requireDouble(json, 'exportQuantityKg'),
      inventoryQuantityKg: _requireDouble(json, 'inventoryQuantityKg'),
      importValueVnd: _requireDouble(json, 'importValueVnd'),
      exportValueVnd: _requireDouble(json, 'exportValueVnd'),
      inventoryValueVnd: _requireDouble(json, 'inventoryValueVnd'),
      hasMissingImportPrice: requireBool(json, 'hasMissingImportPrice'),
    );
  }

  final int materialCode;
  final String name;
  final String groupCode;
  final double importQuantityKg;
  final double exportQuantityKg;
  final double inventoryQuantityKg;
  final double importValueVnd;
  final double exportValueVnd;
  final double inventoryValueVnd;
  final bool hasMissingImportPrice;
}

class MaterialChartItem {
  const MaterialChartItem({
    required this.materialCode,
    required this.name,
    required this.groupCode,
    required this.importQuantityKg,
    required this.exportQuantityKg,
    required this.inventoryQuantityKg,
    required this.importValueVnd,
    required this.exportValueVnd,
    required this.inventoryValueVnd,
  });

  factory MaterialChartItem.fromJson(Object? value) {
    final json = requireJsonObject(value, 'dòng biểu đồ vật liệu');
    return MaterialChartItem(
      materialCode: requireInt(json, 'materialCode'),
      name: requireString(json, 'name'),
      groupCode: requireString(json, 'groupCode'),
      importQuantityKg: _requireDouble(json, 'importQuantityKg'),
      exportQuantityKg: _requireDouble(json, 'exportQuantityKg'),
      inventoryQuantityKg: _requireDouble(json, 'inventoryQuantityKg'),
      importValueVnd: _requireDouble(json, 'importValueVnd'),
      exportValueVnd: _requireDouble(json, 'exportValueVnd'),
      inventoryValueVnd: _requireDouble(json, 'inventoryValueVnd'),
    );
  }

  final int materialCode;
  final String name;
  final String groupCode;
  final double importQuantityKg;
  final double exportQuantityKg;
  final double inventoryQuantityKg;
  final double importValueVnd;
  final double exportValueVnd;
  final double inventoryValueVnd;
}

class MaterialTransaction {
  const MaterialTransaction({
    required this.rowNumber,
    required this.id,
    required this.occurredAt,
    required this.periodFrom,
    required this.periodTo,
    required this.type,
    required this.content,
    required this.importQuantityKg,
    required this.exportQuantityKg,
    required this.valueVnd,
    required this.note,
    required this.details,
  });

  factory MaterialTransaction.fromJson(Object? value) {
    final json = requireJsonObject(value, 'giao dịch vật liệu');
    return MaterialTransaction(
      rowNumber: requireInt(json, 'rowNumber'),
      id: requireString(json, 'id'),
      occurredAt: optionalUtcDateTime(json, 'occurredAt'),
      periodFrom: optionalUtcDateTime(json, 'periodFrom'),
      periodTo: optionalUtcDateTime(json, 'periodTo'),
      type: requireString(json, 'type'),
      content: requireString(json, 'content'),
      importQuantityKg: _requireDouble(json, 'importQuantityKg'),
      exportQuantityKg: _requireDouble(json, 'exportQuantityKg'),
      valueVnd: _optionalDouble(json, 'valueVnd'),
      note: optionalString(json, 'note'),
      details: requireJsonList(
        json['details'],
        'details',
      ).map(MaterialTransactionDetail.fromJson).toList(growable: false),
    );
  }

  final int rowNumber;
  final String id;
  final DateTime? occurredAt;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final String type;
  final String content;
  final double importQuantityKg;
  final double exportQuantityKg;
  final double? valueVnd;
  final String? note;
  final List<MaterialTransactionDetail> details;

  bool get isSummary => type == 'summary-export';
}

class MaterialTransactionDetail {
  const MaterialTransactionDetail({
    required this.materialCode,
    required this.name,
    required this.quantityKg,
    required this.valueVnd,
    required this.unitPriceVndPerKg,
    required this.conversionVolume,
    required this.conversionUnit,
    required this.conversionCoefficientKgPerUnit,
  });

  factory MaterialTransactionDetail.fromJson(Object? value) {
    final json = requireJsonObject(value, 'chi tiết giao dịch vật liệu');
    return MaterialTransactionDetail(
      materialCode: requireInt(json, 'materialCode'),
      name: requireString(json, 'name'),
      quantityKg: _requireDouble(json, 'quantityKg'),
      valueVnd: _optionalDouble(json, 'valueVnd'),
      unitPriceVndPerKg: _optionalDouble(json, 'unitPriceVndPerKg'),
      conversionVolume: _optionalDouble(json, 'conversionVolume'),
      conversionUnit: optionalString(json, 'conversionUnit'),
      conversionCoefficientKgPerUnit: _optionalDouble(
        json,
        'conversionCoefficientKgPerUnit',
      ),
    );
  }

  final int materialCode;
  final String name;
  final double quantityKg;
  final double? valueVnd;
  final double? unitPriceVndPerKg;
  final double? conversionVolume;
  final String? conversionUnit;
  final double? conversionCoefficientKgPerUnit;
}

class MaterialReportTotals {
  const MaterialReportTotals({
    required this.importQuantityKg,
    required this.exportQuantityKg,
    required this.inventoryQuantityKg,
    required this.importValueVnd,
    required this.exportValueVnd,
    required this.inventoryValueVnd,
  });

  factory MaterialReportTotals.fromJson(Object? value) {
    final json = requireJsonObject(value, 'tổng báo cáo vật liệu');
    return MaterialReportTotals(
      importQuantityKg: _requireDouble(json, 'importQuantityKg'),
      exportQuantityKg: _requireDouble(json, 'exportQuantityKg'),
      inventoryQuantityKg: _requireDouble(json, 'inventoryQuantityKg'),
      importValueVnd: _requireDouble(json, 'importValueVnd'),
      exportValueVnd: _requireDouble(json, 'exportValueVnd'),
      inventoryValueVnd: _requireDouble(json, 'inventoryValueVnd'),
    );
  }

  final double importQuantityKg;
  final double exportQuantityKg;
  final double inventoryQuantityKg;
  final double importValueVnd;
  final double exportValueVnd;
  final double inventoryValueVnd;
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
