// Material report sample data copied from Figma C05–C07.
import 'package:ttsmart_mobile/features/material_reporting/data/models/material_report_models.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';

MaterialChartItem _chart(
  int code,
  String name,
  String group,
  double imported,
  double exported,
  double inventory,
) => MaterialChartItem(
  materialCode: code,
  name: name,
  groupCode: group,
  importQuantityKg: imported,
  exportQuantityKg: exported,
  inventoryQuantityKg: inventory,
  importValueVnd: imported * 3000,
  exportValueVnd: exported * 3000,
  inventoryValueVnd: inventory * 3000,
);

MaterialSummaryItem _summary(
  MaterialChartItem item, {
  bool missingPrice = false,
}) => MaterialSummaryItem(
  materialCode: item.materialCode,
  name: item.name,
  groupCode: item.groupCode,
  importQuantityKg: item.importQuantityKg,
  exportQuantityKg: item.exportQuantityKg,
  inventoryQuantityKg: item.inventoryQuantityKg,
  importValueVnd: item.importValueVnd,
  exportValueVnd: item.exportValueVnd,
  inventoryValueVnd: item.inventoryValueVnd,
  hasMissingImportPrice: missingPrice,
);

MaterialTransaction _transaction(
  int row,
  String id,
  DateTime occurredUtc,
  String type,
  String content, {
  double imported = 0,
  double exported = 0,
  double? value,
  String? note,
  List<MaterialTransactionDetail> details = const [],
}) => MaterialTransaction(
  rowNumber: row,
  id: id,
  occurredAt: occurredUtc,
  periodFrom: null,
  periodTo: null,
  type: type,
  content: content,
  importQuantityKg: imported,
  exportQuantityKg: exported,
  valueVnd: value,
  note: note,
  details: details,
);

final _chartItems = <MaterialChartItem>[
  _chart(1, 'Đá 1×2', 'stone', 1300000, 1236500, 512800),
  _chart(2, 'Cát vàng', 'sand', 860000, 812400, 356200),
  _chart(3, 'Xi măng PCB40', 'cement', 420000, 386900, 98400),
  _chart(4, 'Phụ gia Sika', 'additive', 5600, 4220, 1380),
];

class VisualMaterialRepository implements MaterialReportRepository {
  @override
  Future<List<MaterialReportStation>> getStations({int? companyId}) async =>
      const [
        MaterialReportStation(
          id: 10,
          companyId: 3,
          name: 'Trạm Hà Nam',
          companyName: 'Công ty CP Bê tông TTSmart',
          typeTram: 1,
        ),
      ];

  @override
  Future<MaterialReport> getReport(MaterialReportQuery query) async =>
      MaterialReport(
        stationId: 10,
        stationName: 'Trạm Hà Nam',
        from: DateTime.utc(2026, 8, 31, 17),
        to: DateTime.utc(2026, 9, 21, 10, 30),
        inventoryAsOf: DateTime.utc(2026, 9, 21, 10, 30),
        groups: [
          MaterialGroupSummary(
            code: 'stone',
            name: 'Đá',
            materials: [_summary(_chartItems[0])],
          ),
          MaterialGroupSummary(
            code: 'sand',
            name: 'Cát',
            materials: [_summary(_chartItems[1])],
          ),
          MaterialGroupSummary(
            code: 'cement',
            name: 'Xi măng',
            materials: [_summary(_chartItems[2])],
          ),
          MaterialGroupSummary(
            code: 'additive',
            name: 'Phụ gia',
            materials: [_summary(_chartItems[3], missingPrice: true)],
          ),
        ],
        chartItems: _chartItems,
        transactions: [
          _transaction(
            1,
            'PN-000123',
            DateTime.utc(2026, 9, 21, 1, 15),
            'import',
            'Nhập cát vàng – NCC Minh Phát',
            imported: 12400,
            value: 45632000,
            note: 'Xe 29C-567.89 giao 2 chuyến trong ngày.',
            details: const [
              MaterialTransactionDetail(
                materialCode: 2,
                name: 'Cát vàng',
                quantityKg: 12400,
                valueVnd: 45632000,
                unitPriceVndPerKg: 3680,
                conversionVolume: 8.6,
                conversionUnit: 'm³',
                conversionCoefficientKgPerUnit: 1442,
              ),
            ],
          ),
          _transaction(
            2,
            'PX-004521',
            DateTime.utc(2026, 9, 21, 1, 32),
            'export',
            'Xuất trộn mẻ #4521',
            exported: 718,
            value: 2642240,
          ),
          _transaction(
            3,
            'PN-000122',
            DateTime.utc(2026, 9, 20, 8, 10),
            'import',
            'Nhập xi măng PCB40 – Vicem Bút Sơn',
            imported: 30000,
            value: 46500000,
          ),
          _transaction(
            4,
            'TH-0920',
            DateTime.utc(2026, 9, 20, 16, 59),
            'summary-export',
            'Tổng hợp xuất trộn ngày 20/09',
            exported: 38460,
          ),
          _transaction(
            5,
            'PX-004498',
            DateTime.utc(2026, 9, 20, 9, 5),
            'export',
            'Xuất trộn mẻ #4498',
            exported: 1083,
            value: 341145,
          ),
          _transaction(
            6,
            'PN-000121',
            DateTime.utc(2026, 9, 20, 2, 40),
            'import',
            'Nhập đá 1×2 – Mỏ Kiện Khê',
            imported: 48200,
            value: 13978000,
          ),
        ],
        totalCount: 148,
        totalPages: 1,
        pageNumber: 1,
        pageSize: 20,
        fromRowNumber: 1,
        toRowNumber: 6,
        totals: const MaterialReportTotals(
          importQuantityKg: 2585600,
          exportQuantityKg: 2440020,
          inventoryQuantityKg: 968780,
          importValueVnd: 7756800000,
          exportValueVnd: 7320060000,
          inventoryValueVnd: 2906340000,
        ),
        warnings: const ['Phụ gia Sika chưa có đơn giá nhập trong kỳ.'],
      );
}
