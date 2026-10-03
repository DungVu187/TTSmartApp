import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/material_reporting/data/models/material_report_models.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/widgets/material_report_widgets.dart';
import 'package:ttsmart_mobile/features/material_reporting/presentation/widgets/material_units.dart';

MaterialSummaryItem _item({
  double stock = -219852366,
  double? perCubicMeter,
  double? perLiter,
}) => MaterialSummaryItem(
  materialCode: 3,
  name: 'Đá 1',
  groupCode: 'stone',
  importQuantityKg: 0,
  exportQuantityKg: -stock,
  inventoryQuantityKg: stock,
  importValueVnd: 0,
  exportValueVnd: 0,
  inventoryValueVnd: 0,
  hasMissingImportPrice: false,
  kilogramsPerCubicMeter: perCubicMeter,
  kilogramsPerLiter: perLiter,
);

void main() {
  test('units per group follow the web', () {
    expect(materialUnitsFor('sand'), [
      MaterialUnit.kg,
      MaterialUnit.ton,
      MaterialUnit.cubicMeter,
    ]);
    expect(materialUnitsFor('cement'), [MaterialUnit.kg, MaterialUnit.ton]);
    expect(materialUnitsFor('water').first, MaterialUnit.liter);
    expect(materialUnitsFor('additive'), contains(MaterialUnit.kg));
  });

  test('quantities: kg whole, tấn and m³ with two decimals, real minus', () {
    final item = _item(perCubicMeter: 1500);
    expect(
      formatMaterialQuantity(-219852366, MaterialUnit.kg, item),
      '−219.852.366 kg',
    );
    expect(
      formatMaterialQuantity(-219852366, MaterialUnit.ton, item),
      '−219.852,37 tấn',
    );
    expect(
      formatMaterialQuantity(-219852366, MaterialUnit.cubicMeter, item),
      '−146.568,24 m³',
    );
    expect(formatMaterialQuantity(0.4, MaterialUnit.kg, item), '0 kg');
  });

  test('m³ and lít without a factor say so, zero stays zero', () {
    final item = _item();
    expect(
      formatMaterialQuantity(-5, MaterialUnit.cubicMeter, item),
      kNoConversionFactor,
    );
    expect(
      formatMaterialQuantity(-5, MaterialUnit.liter, item),
      kNoConversionFactor,
    );
    expect(formatMaterialQuantity(0, MaterialUnit.liter, item), '0 lít');
  });

  test('compact chart labels', () {
    expect(formatCompactNumber(219852366), '219,9 triệu');
    expect(formatCompactNumber(-113021874), '−113,0 triệu');
    expect(formatCompactNumber(28708), '28,7 nghìn');
    expect(formatCompactNumber(12), '12');
    expect(formatVnd(45600000), '45.600.000 đ');
  });

  test('negative stock is explained once, with the count', () {
    final all = [_item(), _item(stock: -1)];
    expect(
      negativeStockNotice(all, valueMode: false)?.title,
      'Cả 2 vật liệu đang âm kho',
    );
    final some = [_item(), _item(stock: 10)];
    expect(
      negativeStockNotice(some, valueMode: true)?.title,
      '1/2 vật liệu đang âm kho',
    );
    expect(
      negativeStockNotice(some, valueMode: true)?.message,
      contains('0 đ'),
    );
    expect(negativeStockNotice([_item(stock: 10)], valueMode: false), isNull);
  });
}
