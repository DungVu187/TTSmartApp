// Statistics sample data copied from Figma C01–C03.
import 'dart:typed_data';

import 'package:ttsmart_mobile/features/reports/data/models/report_models.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';

OrderStatisticsMaterial _material(
  int slot,
  String name,
  String code,
  double design,
  double t,
  double actual,
) => OrderStatisticsMaterial(
  materialSlotId: slot,
  slotNumber: slot,
  materialName: name,
  category: code,
  categoryCode: code,
  designQuantity: design,
  tQuantity: t,
  actualQuantity: actual,
  variance: actual + t - design,
);

OrderStatisticsItem _batch(
  int row,
  DateTime startedUtc,
  String customer,
  String grade,
  String plate,
  String location,
  double mixed,
  double requested,
) => OrderStatisticsItem(
  rowNumber: row,
  stationId: 10,
  stationName: 'Trạm Hà Nam',
  mixingDate: DateTime(startedUtc.year, startedUtc.month, startedUtc.day),
  startedAt: startedUtc,
  finishedAt: startedUtc.add(const Duration(minutes: 17)),
  customerName: customer,
  projectName: row == 1 ? 'Khu đô thị Phủ Lý' : location,
  workItemName: row == 1 ? 'Sàn tầng 3 – Block B' : null,
  locationName: location,
  vehiclePlate: plate,
  driverName: 'Nguyễn Văn Bình',
  concreteGradeName: grade,
  slump: '12±2',
  salesEmployeeName: 'Phạm Thu Trang',
  employeeName: 'Nguyễn Văn A',
  requestedVolume: requested,
  mixedVolume: mixed,
  materials: row == 1
      ? [
          _material(1, 'Cát vàng', 'CAT', 720, 4, 718),
          _material(2, 'Đá 1×2', 'DA', 1080, 0, 1083),
          _material(3, 'Xi măng PCB40', 'XIMANG', 385, 0, 386),
          _material(4, 'Nước', 'NUOC', 185, -4, 190),
          _material(5, 'Phụ gia Sika', 'PHUGIA', 3.85, 0, 3.86),
        ]
      : const <OrderStatisticsMaterial>[],
);

final visualStatisticsItems = <OrderStatisticsItem>[
  _batch(
    1,
    DateTime.utc(2026, 9, 21, 1, 15),
    'Công ty CP Xây dựng Hòa Bình',
    'M300',
    '29C-123.45',
    'KĐT Phủ Lý',
    8,
    8,
  ),
  _batch(
    2,
    DateTime.utc(2026, 9, 21, 0, 52),
    'Cty TNHH Thương mại Minh Phát',
    'M250',
    '29C-456.12',
    'Cầu Sông Đáy',
    7.5,
    8,
  ),
  _batch(
    3,
    DateTime.utc(2026, 9, 21, 0, 30),
    'Công ty CP Xây dựng Hòa Bình',
    'M300',
    '90C-221.08',
    'KĐT Phủ Lý',
    8,
    8,
  ),
  _batch(
    4,
    DateTime.utc(2026, 9, 20, 9, 5),
    'Công ty TNHH Sông Đáy',
    'M200',
    '29C-777.35',
    'Nhà xưởng B2',
    6,
    6,
  ),
  _batch(
    5,
    DateTime.utc(2026, 9, 20, 8, 40),
    'Công ty CP Phủ Lý Xanh',
    'M350',
    '90C-110.45',
    'Cầu vượt QL21',
    9,
    9,
  ),
  _batch(
    6,
    DateTime.utc(2026, 9, 20, 7, 12),
    'Cty TNHH Thương mại Minh Phát',
    'M250',
    '29C-456.12',
    'Cầu Sông Đáy',
    8,
    8,
  ),
  _batch(
    7,
    DateTime.utc(2026, 9, 20, 6, 30),
    'Công ty CP Xây dựng Hòa Bình',
    'M300',
    '29C-123.45',
    'KĐT Phủ Lý',
    8,
    8,
  ),
];

OrderStatisticsMaterialSummaryCell _cell(
  String code,
  int position,
  int slot,
  String name,
  double quantity, {
  String unit = 'KG',
}) => OrderStatisticsMaterialSummaryCell(
  categoryCode: code,
  typePosition: position,
  materialSlotId: slot,
  slotNumber: slot,
  materialName: name,
  category: code,
  columnKey: '$code$position',
  unit: unit,
  actualQuantity: quantity,
);

final visualStatisticsSummary = <OrderStatisticsMaterialSummaryRow>[
  OrderStatisticsMaterialSummaryRow(
    rowNumber: 1,
    cells: [
      _cell('CAT', 1, 1, 'Cát vàng', 812400),
      _cell('DA', 1, 2, 'Đá 1×2', 1236500),
      _cell('DA', 2, 3, 'Đá 0,5×1', 196800),
      _cell('XIMANG', 1, 1, 'Xi măng PCB40', 386900),
      _cell('NUOC', 1, 1, 'Nước', 209300, unit: 'LÍT'),
      _cell('PHUGIA', 1, 1, 'Phụ gia Sika', 4220),
    ],
  ),
];

class VisualReportsRepository implements ReportsRepository {
  @override
  Future<List<OrderStatisticsStation>> getStations({int? companyId}) async =>
      const [
        OrderStatisticsStation(
          id: 10,
          companyId: 3,
          name: 'Trạm Hà Nam',
          typeTram: 1,
          companyName: 'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam',
        ),
      ];

  @override
  Future<OrderStatisticsFilterOptions> getFilterOptions(
    OrderStatisticsFilterQuery query,
  ) async => const OrderStatisticsFilterOptions(
    vehiclePlates: ['29C-123.45', '29C-456.12', '90C-221.08'],
    customerNames: [
      'Công ty CP Xây dựng Hòa Bình',
      'Cty TNHH Thương mại Minh Phát',
    ],
    concreteGradeNames: ['M200', 'M250', 'M300', 'M350'],
    employeeNames: ['Nguyễn Văn A', 'Phạm Thu Trang'],
  );

  @override
  Future<OrderStatisticsPage> search(OrderStatisticsQuery query) async =>
      OrderStatisticsPage(
        items: visualStatisticsItems,
        totalCount: 86,
        totalPages: 1,
        pageNumber: 1,
        pageSize: 20,
        fromRowNumber: 1,
        toRowNumber: 7,
        totalMaterialQuantity: 2846120,
        totalConcreteVolume: 1198.5,
        materialSummaryRows: visualStatisticsSummary,
      );

  @override
  Future<OrderStatisticsExportFile> export(
    OrderStatisticsExportQuery query,
  ) async => OrderStatisticsExportFile(bytes: Uint8List(0));
}
