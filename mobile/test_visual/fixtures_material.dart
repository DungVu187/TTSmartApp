// Material report with the data of a real station (web "Quản lý vật liệu"
// of Trạm trộn BT số 1.1, 25/09/2026): the station does not enter its
// import vouchers, so every door is below zero and there are no prices.
import 'dart:async';

import 'package:ttsmart_mobile/core/network/api_request_cancellation.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/models/material_report_models.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/repositories/material_report_repository.dart';

MaterialSummaryItem _material(
  int code,
  int slot,
  String name,
  String group,
  double imported,
  double exported, {
  bool missingPrice = false,
}) => MaterialSummaryItem(
  materialCode: code,
  name: name,
  groupCode: group,
  importQuantityKg: imported,
  exportQuantityKg: exported,
  inventoryQuantityKg: imported - exported,
  importValueVnd: 0,
  exportValueVnd: 0,
  inventoryValueVnd: 0,
  hasMissingImportPrice: missingPrice,
  slotNumber: slot,
  materialTypeId: switch (group) {
    'sand' => 1,
    'stone' => 2,
    'cement' => 3,
    'water' => 4,
    _ => 5,
  },
);

final _sand = [
  _material(1, 1, 'Cát 3.', 'sand', 0, 25280661),
  _material(2, 2, 'Cát 2.', 'sand', 0, 66690133),
  _material(3, 3, 'Cát 1.', 'sand', 28708, 113050582, missingPrice: true),
];
final _stone = [
  _material(4, 4, 'Đá 1', 'stone', 0, 219852366),
  _material(5, 5, 'Đá 2', 'stone', 0, 38823558),
];
final _cement = [
  _material(6, 6, 'Xi măng 1', 'cement', 0, 80386726),
  _material(7, 7, 'Xi măng 2', 'cement', 0, 4407478),
];
final _water = [_material(8, 8, 'Nước', 'water', 0, 36051578)];
final _additive = [
  _material(9, 9, 'Phụ gia 1', 'additive', 0, 622808),
  _material(10, 10, 'Phụ gia 2', 'additive', 0, 12087),
];

/// Export of the period per material ("Xuất tổng trong kỳ").
const _periodExport = <(int, String, double)>[
  (1, 'Cát 3.', 120600),
  (2, 'Cát 2.', 300100),
  (3, 'Cát 1.', 620300),
  (4, 'Đá 1', 1020500),
  (5, 'Đá 2', 180900),
  (6, 'Xi măng 1', 380200),
  (7, 'Xi măng 2', 20300),
  (8, 'Nước', 170400),
  (9, 'Phụ gia 1', 3000),
  (10, 'Phụ gia 2', 72),
];

MaterialTransaction _summary(DateTime from, DateTime to, {bool empty = false}) {
  final details = [
    if (!empty)
      for (final (code, name, kg) in _periodExport)
        MaterialTransactionDetail(
          materialCode: code,
          name: name,
          quantityKg: kg,
          valueVnd: 0,
          unitPriceVndPerKg: null,
          conversionVolume: null,
          conversionUnit: null,
          conversionCoefficientKgPerUnit: null,
        ),
  ];
  return MaterialTransaction(
    rowNumber: 2,
    id: 'summary-export',
    occurredAt: null,
    periodFrom: from,
    periodTo: to,
    type: 'summary-export',
    content: 'Xuất tổng trong kỳ',
    importQuantityKg: 0,
    exportQuantityKg: details.fold(0, (sum, item) => sum + item.quantityKg),
    valueVnd: 0,
    note: null,
    details: details,
  );
}

final _scaleImport = MaterialTransaction(
  rowNumber: 1,
  id: 'scale:1842',
  occurredAt: DateTime.utc(2026, 9, 21, 1, 15),
  periodFrom: null,
  periodTo: null,
  type: 'import',
  content: 'Nhập hàng từ trạm cân',
  importQuantityKg: 28708,
  exportQuantityKg: 0,
  valueVnd: 0,
  note: null,
  details: const [
    MaterialTransactionDetail(
      materialCode: 3,
      name: 'Cát 1.',
      quantityKg: 28708,
      valueVnd: 0,
      unitPriceVndPerKg: 0,
      conversionVolume: 19.8,
      conversionUnit: 'm³',
      conversionCoefficientKgPerUnit: 1450,
    ),
  ],
);

class VisualMaterialRepository implements MaterialReportRepository {
  VisualMaterialRepository({
    this.emptyPeriod = false,
    this.pending = false,
    this.preparingPercent,
  });

  /// The API still reads the station's history for the first time.
  final int? preparingPercent;

  /// 25/09 only: no mix finished and no voucher that day.
  final bool emptyPeriod;

  /// Never answers, to capture the loading state.
  final bool pending;

  @override
  Future<List<MaterialReportStation>> getStations({int? companyId}) async =>
      const [
        MaterialReportStation(
          id: 3227,
          companyId: 45,
          name: 'Trạm trộn BT số 1.1 - 90m3 Khoái Châu',
          companyName: 'Công ty TNHH Bê tông và Xây dựng Petro',
          typeTram: 1,
        ),
      ];

  @override
  Future<MaterialReport> getReport(
    MaterialReportQuery query, {
    ApiRequestCancellation? cancellation,
  }) async {
    if (pending) return Completer<MaterialReport>().future;
    final preparing = preparingPercent;
    if (preparing != null) {
      throw MaterialReportPreparing(progressPercent: preparing);
    }
    final from = emptyPeriod
        ? DateTime.utc(2026, 9, 24, 17)
        : DateTime.utc(2026, 8, 31, 17);
    final to = DateTime.utc(2026, 9, 25, 16, 59);
    final all =
        query.viewMode == MaterialViewMode.all &&
        query.materialGroup == MaterialGroupFilter.all;
    final vouchers = [
      if (!emptyPeriod &&
          (query.viewMode == MaterialViewMode.all ||
              query.viewMode == MaterialViewMode.importData))
        _scaleImport,
    ];
    return MaterialReport(
      stationId: 3227,
      stationName: 'Trạm trộn BT số 1.1 - 90m3 Khoái Châu',
      from: from,
      to: to,
      inventoryAsOf: to,
      groups: [
        MaterialGroupSummary(code: 'sand', name: 'Nhóm Cát', materials: _sand),
        MaterialGroupSummary(code: 'stone', name: 'Nhóm Đá', materials: _stone),
        MaterialGroupSummary(
          code: 'cement',
          name: 'Nhóm Xi',
          materials: _cement,
        ),
        MaterialGroupSummary(
          code: 'water',
          name: 'Nhóm Nước',
          materials: _water,
        ),
        MaterialGroupSummary(
          code: 'additive',
          name: 'Nhóm Phụ gia',
          materials: _additive,
        ),
      ],
      chartItems: const [],
      transactions: [
        ...vouchers,
        if (all) _summary(from, to, empty: emptyPeriod),
      ],
      totalCount: vouchers.length + (all ? 1 : 0),
      totalPages: 1,
      pageNumber: 1,
      pageSize: 10,
      fromRowNumber: 1,
      toRowNumber: vouchers.length,
      totals: const MaterialReportTotals(
        importQuantityKg: 28708,
        exportQuantityKg: 585179977,
        inventoryQuantityKg: -585151269,
        importValueVnd: 0,
        exportValueVnd: 0,
        inventoryValueVnd: 0,
      ),
      warnings: const [
        'Một số lô nhập chưa có đơn giá nên phần giá trị tương ứng được tính '
            'bằng 0.',
      ],
    );
  }
}
