import '../../data/models/material_report_models.dart';

/// Units a material group can be shown in, as on the web "Tổng tồn các cửa
/// vật liệu": the numbers stay in kg and are converted for display only.
enum MaterialUnit {
  kg('kg', 'Ki-lô-gam, như số liệu gốc'),
  ton('tấn', '1 tấn = 1.000 kg'),
  cubicMeter('m³', 'Theo hệ số quy đổi trên phiếu nhập'),
  liter('lít', 'Theo hệ số quy đổi trên phiếu nhập');

  const MaterialUnit(this.label, this.description);

  final String label;
  final String description;
}

/// Web order: Cát/Đá kg · tấn · m³, Xi kg · tấn, Nước/Phụ gia lít · kg · m³.
List<MaterialUnit> materialUnitsFor(String groupCode) => switch (groupCode) {
  'sand' ||
  'stone' => const [MaterialUnit.kg, MaterialUnit.ton, MaterialUnit.cubicMeter],
  'cement' => const [MaterialUnit.kg, MaterialUnit.ton],
  _ => const [MaterialUnit.liter, MaterialUnit.kg, MaterialUnit.cubicMeter],
};

/// What "Chưa có hệ số" replaces when m³ / lít has no conversion factor.
const String kNoConversionFactor = 'Chưa có hệ số';

/// [kg] in [unit], or null when the material has no factor for it.
double? convertMaterialKg(
  double kg,
  MaterialUnit unit,
  MaterialSummaryItem? item,
) {
  switch (unit) {
    case MaterialUnit.kg:
      return kg;
    case MaterialUnit.ton:
      return kg / 1000;
    case MaterialUnit.cubicMeter:
      if (kg == 0) return 0;
      final factor = item?.kilogramsPerCubicMeter;
      return factor == null || factor <= 0 ? null : kg / factor;
    case MaterialUnit.liter:
      if (kg == 0) return 0;
      final factor = item?.kilogramsPerLiter;
      return factor == null || factor <= 0 ? null : kg / factor;
  }
}

/// "−219.852.366 kg", "−219.852,37 tấn" (tấn and m³ keep two decimals, kg
/// and lít are whole numbers, like the web), or "Chưa có hệ số".
String formatMaterialQuantity(
  double kg,
  MaterialUnit unit,
  MaterialSummaryItem? item, {
  bool withUnit = true,
}) {
  final value = convertMaterialKg(kg, unit, item);
  if (value == null) return kNoConversionFactor;
  // "0 tấn", not "0,00 tấn".
  final text = value.abs() < 0.005
      ? '0'
      : switch (unit) {
          MaterialUnit.ton ||
          MaterialUnit.cubicMeter => formatSignedNumber(value, decimals: 2),
          _ => formatSignedNumber(value.roundToDouble()),
        };
  return withUnit ? '$text ${unit.label}' : text;
}

/// Grouped with "." and a comma for decimals; a real minus sign so a
/// negative stock is not read as a dash.
String formatSignedNumber(double value, {int decimals = 0}) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  final fraction = parts.length == 2 ? ',${parts.last}' : '';
  final isZero = double.parse(fixed) == 0;
  return '${value < 0 && !isZero ? '−' : ''}$buffer$fraction';
}

/// "219,9 triệu", "28,7 nghìn", "12" for chart labels.
String formatCompactNumber(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '−' : '';
  // Always one decimal, so "113,1 triệu" next to "113,0 triệu" reads as
  // the same scale.
  String short(double number) => number.toStringAsFixed(1).replaceAll('.', ',');

  if (abs >= 1e9) return '$sign${short(abs / 1e9)} tỷ';
  if (abs >= 1e6) return '$sign${short(abs / 1e6)} triệu';
  if (abs >= 1e3) return '$sign${short(abs / 1e3)} nghìn';
  return '$sign${abs.round()}';
}

/// "1.234.500 đ".
String formatVnd(double value) =>
    '${formatSignedNumber(value.roundToDouble())} đ';

/// Stock state in words (not only a colour).
enum MaterialStockState {
  negative('Âm kho'),
  empty('Hết hàng'),
  inStock('Còn hàng');

  const MaterialStockState(this.label);

  final String label;
}

MaterialStockState materialStockState(double inventoryKg) => inventoryKg < 0
    ? MaterialStockState.negative
    : inventoryKg == 0
    ? MaterialStockState.empty
    : MaterialStockState.inStock;
