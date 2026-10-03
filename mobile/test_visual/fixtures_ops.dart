// Mix design + weigh station sample data copied from Figma C09–C14.
import 'dart:typed_data';

import 'package:ttsmart_mobile/core/files/export_file.dart';
import 'package:ttsmart_mobile/core/network/api_request_cancellation.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/models/mix_design_models.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_filter_models.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/models/weigh_station_result_models.dart';
import 'package:ttsmart_mobile/features/weigh_station_management/data/repositories/weigh_station_repository.dart';

// ---------------------------------------------------------------- mix design

const _mixColumns = <MixDesignMaterialColumn>[
  MixDesignMaterialColumn(
    materialSlotId: 1,
    slotNumber: 1,
    materialName: 'Cát vàng',
    category: 'Cát',
    categoryCode: 'CAT',
    typePosition: 1,
    columnKey: 'CAT1',
  ),
  MixDesignMaterialColumn(
    materialSlotId: 2,
    slotNumber: 2,
    materialName: 'Đá 1×2',
    category: 'Đá',
    categoryCode: 'DA',
    typePosition: 1,
    columnKey: 'DA1',
  ),
  MixDesignMaterialColumn(
    materialSlotId: 3,
    slotNumber: 1,
    materialName: 'Xi măng PCB40',
    category: 'Xi măng',
    categoryCode: 'XIMANG',
    typePosition: 1,
    columnKey: 'XIMANG1',
  ),
  MixDesignMaterialColumn(
    materialSlotId: 4,
    slotNumber: 1,
    materialName: 'Nước',
    category: 'Nước',
    categoryCode: 'NUOC',
    typePosition: 1,
    columnKey: 'NUOC1',
  ),
  MixDesignMaterialColumn(
    materialSlotId: 5,
    slotNumber: 1,
    materialName: 'Phụ gia Sika',
    category: 'Phụ gia',
    categoryCode: 'PHUGIA',
    typePosition: 1,
    columnKey: 'PHUGIA1',
  ),
];

MixDesignItem _mix(int stt, String grade, int strength, String slump) =>
    MixDesignItem(
      stt: stt,
      concreteGradeName: grade,
      strength: strength,
      maxAggregate: 20,
      slump: slump,
      sand1: 720,
      sand2: 0,
      stone1: 1080,
      stone2: 0,
      stone3: 0,
      cement1: 385,
      cement2: 0,
      cement3: 0,
      cement4: 0,
      water: 185,
      sika: 3.85,
      tulog: 0,
      sikaroad: 0,
      bifi: 0,
      materials: const [
        MixDesignMaterial(
          materialSlotId: 1,
          slotNumber: 1,
          columnKey: 'CAT1',
          quantity: 720,
        ),
        MixDesignMaterial(
          materialSlotId: 2,
          slotNumber: 2,
          columnKey: 'DA1',
          quantity: 1080,
        ),
        MixDesignMaterial(
          materialSlotId: 3,
          slotNumber: 1,
          columnKey: 'XIMANG1',
          quantity: 385,
        ),
        MixDesignMaterial(
          materialSlotId: 4,
          slotNumber: 1,
          columnKey: 'NUOC1',
          quantity: 185,
        ),
        MixDesignMaterial(
          materialSlotId: 5,
          slotNumber: 1,
          columnKey: 'PHUGIA1',
          quantity: 3.85,
        ),
      ],
    );

class VisualMixDesignRepository implements MixDesignRepository {
  @override
  Future<List<MixDesignStation>> getStations({int? companyId}) async => const [
    MixDesignStation(id: 10, name: 'Trạm Hà Nam'),
  ];

  @override
  Future<MixDesignPage> getMixDesigns(
    MixDesignQuery query, {
    ApiRequestCancellation? cancellation,
  }) async => MixDesignPage(
    items: [
      _mix(1, 'M150', 150, '10±2'),
      _mix(2, 'M200', 200, '12±2'),
      _mix(3, 'M250', 250, '12±2'),
      _mix(4, 'M300', 300, '12±2'),
      _mix(5, 'M300 R7', 300, '14±2'),
      _mix(6, 'M350', 350, '14±2'),
      _mix(7, 'M400', 400, '16±2'),
    ],
    pageNumber: 1,
    pageSize: 20,
    totalCount: 32,
    totalPages: 1,
    materialColumns: _mixColumns,
  );
}

// ------------------------------------------------------------- weigh station

WeighStationItem _ticket(
  int stt,
  int number,
  String plate,
  String goods,
  DateTime weighedInUtc, {
  double? inbound,
  double? outbound,
  String type = 'Nhập hàng',
  bool out = true,
}) => WeighStationItem(
  stt: stt,
  id: 'T$number',
  ticketNumber: number,
  ticketCode: 'PC-240921-00$stt',
  weighingAt: weighedInUtc,
  vehiclePlate: plate,
  driverName: 'Đỗ Văn Thắng',
  sealNumber: 'NC-5581$stt',
  inboundWeightKg: inbound,
  outboundWeightKg: out ? outbound : null,
  goodsWeightKg: out && inbound != null && outbound != null
      ? (inbound - outbound).abs()
      : null,
  hasConversionConfiguration: true,
  convertedQuantity: out && inbound != null && outbound != null
      ? (inbound - outbound).abs() / 1500
      : null,
  convertedUnit: 'm³',
  materialValueVnd: out ? 9222000 : null,
  unitName: 'Mỏ đá Kiện Khê',
  goodsName: goods,
  weighingType: type,
  firstOperatorName: 'Trần Văn Hùng',
  secondOperatorName: out ? 'Lê Thị Hoa' : null,
  weighedInAt: weighedInUtc,
  weighedOutAt: out ? weighedInUtc.add(const Duration(minutes: 17)) : null,
);

final _tickets = <WeighStationItem>[
  _ticket(
    1,
    10232,
    '29C-567.89',
    'Cát vàng',
    DateTime.utc(2026, 9, 21, 1, 15),
    inbound: 42300,
    out: false,
  ),
  _ticket(
    2,
    10231,
    '90C-221.08',
    'Đá 1×2',
    DateTime.utc(2026, 9, 21, 0, 41),
    inbound: 46520,
    outbound: 14720,
  ),
  _ticket(
    3,
    10230,
    '29H-118.62',
    'Xi măng PCB40',
    DateTime.utc(2026, 9, 21, 0, 13),
    inbound: 44000,
    outbound: 14000,
  ),
  _ticket(
    4,
    10229,
    '90C-110.45',
    'Cát vàng',
    DateTime.utc(2026, 9, 20, 9, 23),
    inbound: 38950,
    outbound: 15000,
  ),
  _ticket(
    5,
    10228,
    '29C-123.45',
    'Bê tông M300',
    DateTime.utc(2026, 9, 20, 7, 55),
    inbound: 13280,
    outbound: 32000,
    type: 'Xuất hàng',
  ),
  _ticket(
    6,
    10227,
    '90C-334.21',
    'Đá 1×2',
    DateTime.utc(2026, 9, 20, 6, 48),
    inbound: 46140,
    outbound: 14000,
  ),
  _ticket(
    7,
    10226,
    '29C-777.35',
    'Bê tông M250',
    DateTime.utc(2026, 9, 20, 6, 3),
    inbound: 14620,
    outbound: 31000,
    type: 'Xuất hàng',
  ),
];

WeighStationSummaryItem _goods(
  int stt,
  String name,
  double kg,
  double converted,
  String unit,
  double value,
  int tickets,
) => WeighStationSummaryItem(
  stt: stt,
  goodsName: name,
  goodsWeightKg: kg,
  convertedQuantities: [
    WeighStationConvertedQuantity(quantity: converted, unit: unit),
  ],
  ticketCount: tickets,
  materialValueVnd: value,
);

class VisualWeighStationRepository implements WeighStationRepository {
  @override
  Future<List<WeighStationStation>> getStations({
    int? companyId,
    ApiRequestCancellation? cancellation,
  }) async => const [WeighStationStation(id: 20, name: 'Trạm cân Phủ Lý')];

  @override
  Future<WeighStationFilterOptions> getFilterOptions(
    WeighStationFilterQuery query, {
    ApiRequestCancellation? cancellation,
  }) async => const WeighStationFilterOptions(
    vehiclePlates: ['29C-567.89', '90C-221.08'],
    goodsNames: ['Cát vàng', 'Đá 1×2'],
    operatorNames: ['Trần Văn Hùng', 'Lê Thị Hoa'],
    unitNames: ['Mỏ đá Kiện Khê'],
    weighingTypes: ['Nhập hàng', 'Xuất hàng'],
  );

  @override
  Future<WeighStationPage> searchDetail(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) async => WeighStationPage(
    items: _tickets,
    pageNumber: 1,
    pageSize: 20,
    totalCount: 248,
    totalPages: 1,
    canViewMaterialValue: true,
  );

  @override
  Future<WeighStationSummary> searchSummary(
    WeighStationSearchQuery query, {
    ApiRequestCancellation? cancellation,
  }) async => WeighStationSummary(
    items: [
      _goods(1, 'Đá 1×2', 486200, 324.1, 'm³', 141000000, 86),
      _goods(2, 'Cát vàng', 412800, 275.2, 'm³', 151900000, 74),
      _goods(3, 'Xi măng PCB40', 210000, 140, 'tấn', 325500000, 42),
      _goods(4, 'Bê tông M300', 98720, 41.1, 'm³', 1080000000, 28),
      _goods(5, 'Bê tông M250', 52480, 21.9, 'm³', 213700000, 14),
      _goods(6, 'Đá 0,5×1', 24400, 16.3, 'm³', 12700000, 4),
    ],
    pageNumber: 1,
    pageSize: 20,
    totalCount: 6,
    totalPages: 1,
    totalGoodsWeightKg: 1284600,
    totalConvertedQuantities: const [
      WeighStationConvertedQuantity(quantity: 856.4, unit: 'm³'),
    ],
    groups: const [],
    canViewMaterialValue: true,
    topGoods: const WeighStationTopGoods(
      goodsName: 'Đá 1×2',
      goodsWeightKg: 486200,
    ),
    totalMaterialValueVnd: 1924800000,
  );

  @override
  Future<ExportFile> exportDetail(WeighStationSearchQuery query) async =>
      ExportFile(
        bytes: Uint8List(0),
        fileName: 'phieu-can.xlsx',
        contentType: 'application/octet-stream',
      );

  @override
  Future<ExportFile> exportSummary(WeighStationSearchQuery query) =>
      exportDetail(query);
}
