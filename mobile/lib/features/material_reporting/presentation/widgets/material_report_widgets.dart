import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../data/models/material_report_models.dart';
import 'material_units.dart';

/// Group names in the web order (Cát, Đá, Xi, Nước, Phụ gia).
const Map<String, String> kMaterialGroupNames = <String, String>{
  'sand': 'Cát',
  'stone': 'Đá',
  'cement': 'Xi măng',
  'water': 'Nước',
  'additive': 'Phụ gia',
};

String materialGroupName(String code) => kMaterialGroupNames[code] ?? 'Khác';

/// Amber notice with a title and a sentence (the stock explanation).
class MaterialNotice extends StatelessWidget {
  const MaterialNotice({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: p.warningBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.triangleAlert, size: 18, color: p.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: p.warning,
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Cả 10 vật liệu đang âm kho": most stations do not enter their import
/// vouchers, so the stock is minus what was used. Said once, in words,
/// instead of every row turning red. Null when nothing is negative.
MaterialNotice? negativeStockNotice(
  List<MaterialSummaryItem> materials, {
  required bool valueMode,
}) {
  final negative = materials.where((item) => item.inventoryQuantityKg < 0);
  final count = negative.length;
  if (count == 0) return null;
  final title = count == materials.length
      ? 'Cả $count vật liệu đang âm kho'
      : '$count/${materials.length} vật liệu đang âm kho';
  return MaterialNotice(
    title: title,
    message: valueMode
        ? 'Xuất nhiều hơn nhập đã ghi nên không còn lô để tính giá trị tồn '
              '(0 đ). Thường do trạm chưa nhập đủ phiếu nhập kho.'
        : 'Xuất nhiều hơn nhập đã ghi, thường do trạm chưa nhập đủ phiếu '
              'nhập kho.',
  );
}

/// API warnings worth showing in the current mode: the ones about prices
/// only matter when values are shown.
List<String> materialWarningsFor(
  List<String> warnings, {
  required bool valueMode,
}) => valueMode
    ? warnings
    : warnings
          .where((warning) => !warning.toLowerCase().contains('giá'))
          .toList(growable: false);

/// Small pill with the stock state in words.
class MaterialPill extends StatelessWidget {
  const MaterialPill({super.key, required this.label, required this.tone});

  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.palette.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

MaterialPill materialStatePill(double inventoryKg) {
  final state = materialStockState(inventoryKg);
  return MaterialPill(
    label: state.label,
    tone: switch (state) {
      MaterialStockState.negative => AppTone.danger,
      MaterialStockState.empty => AppTone.neutral,
      MaterialStockState.inStock => AppTone.success,
    },
  );
}

/// Figma C05: one material group, its display unit and a row per material.
class MaterialStockGroup extends StatelessWidget {
  const MaterialStockGroup({
    super.key,
    required this.group,
    required this.unit,
    required this.valueMode,
    required this.onUnitTap,
    required this.onMaterialTap,
  });

  final MaterialGroupSummary group;
  final MaterialUnit unit;
  final bool valueMode;
  final VoidCallback onUnitTap;
  final ValueChanged<MaterialSummaryItem> onMaterialTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GroupLabel(
            materialGroupName(group.code),
            trailing: Semantics(
              button: true,
              label:
                  'Đơn vị nhóm ${materialGroupName(group.code)}: '
                  '${unit.label}. Đổi đơn vị',
              excludeSemantics: true,
              child: TapArea(
                key: ValueKey<String>('material-unit-${group.code}'),
                onTap: onUnitTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Đơn vị: ${unit.label}',
                        style: TextStyle(
                          color: p.onPrimaryContainer,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronDown,
                        size: 14,
                        color: p.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        InsetCard(
          children: [
            for (final item in group.materials)
              _MaterialStockRow(
                key: ValueKey<String>('material-row-${item.materialCode}'),
                item: item,
                unit: unit,
                valueMode: valueMode,
                onTap: () => onMaterialTap(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _MaterialStockRow extends StatelessWidget {
  const _MaterialStockRow({
    super.key,
    required this.item,
    required this.unit,
    required this.valueMode,
    required this.onTap,
  });

  final MaterialSummaryItem item;
  final MaterialUnit unit;
  final bool valueMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stock = formatMaterialQuantity(item.inventoryQuantityKg, unit, item);
    final main = valueMode ? formatVnd(item.inventoryValueVnd) : stock;
    final detail = valueMode
        ? 'Tồn $stock'
        : 'Nhập ${formatMaterialQuantity(item.importQuantityKg, unit, item, withUnit: false)}'
              ' · Xuất ${formatMaterialQuantity(item.exportQuantityKg, unit, item)}';
    final state = materialStockState(item.inventoryQuantityKg);
    return Semantics(
      button: true,
      label:
          '${item.name}, ${valueMode ? 'giá trị tồn $main, ' : ''}tồn $stock, '
          '${state.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text1,
                        fontSize: 16,
                        height: 21 / 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right-aligned whatever its length; the name wraps first.
                  Text(
                    main,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight, size: 16, color: p.text3),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  materialStatePill(item.inventoryQuantityKg),
                  if (valueMode && item.hasMissingImportPrice)
                    const MaterialPill(
                      label: 'Thiếu đơn giá',
                      tone: AppTone.warning,
                    ),
                  Text(
                    detail,
                    style: TextStyle(
                      color: p.text2,
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma C06: import, export and stock of every material on one scale,
/// largest first (the web chart order), with the value on each bar.
class MaterialChartList extends StatelessWidget {
  const MaterialChartList({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<MaterialSummaryItem> items;
  final ValueChanged<MaterialSummaryItem> onTap;

  static double _largest(MaterialSummaryItem item) => [
    item.importQuantityKg.abs(),
    item.exportQuantityKg.abs(),
    item.inventoryQuantityKg.abs(),
  ].reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]
      ..sort((a, b) => _largest(b).compareTo(_largest(a)));
    final max = sorted.isEmpty ? 0.0 : _largest(sorted.first);
    return InsetCard(
      children: [
        for (final item in sorted)
          _MaterialChartRow(item: item, max: max, onTap: () => onTap(item)),
      ],
    );
  }
}

class _MaterialChartRow extends StatelessWidget {
  const _MaterialChartRow({
    required this.item,
    required this.max,
    required this.onTap,
  });

  final MaterialSummaryItem item;
  final double max;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stock = item.inventoryQuantityKg;
    final lines = [
      ('Nhập', item.importQuantityKg, p.primary),
      ('Xuất', item.exportQuantityKg, p.warning),
      ('Tồn', stock, stock < 0 ? p.danger : p.success),
    ];
    return Semantics(
      button: true,
      label:
          '${item.name}: nhập ${formatMaterialQuantity(item.importQuantityKg, MaterialUnit.kg, item)}, '
          'xuất ${formatMaterialQuantity(item.exportQuantityKg, MaterialUnit.kg, item)}, '
          'tồn ${formatMaterialQuantity(stock, MaterialUnit.kg, item)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text1,
                        fontSize: 16,
                        height: 21 / 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 16, color: p.text3),
                ],
              ),
              for (final (label, value, color) in lines) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    // Grows with the phone's font size ("Nhập" split at 1.3×).
                    SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(36),
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: p.text2,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final ratio = max <= 0 ? 0.0 : value.abs() / max;
                          final width = value == 0
                              ? 0.0
                              : (constraints.maxWidth * ratio).clamp(
                                  3.0,
                                  constraints.maxWidth,
                                );
                          return Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: p.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: width,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 108,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${value == 0 ? '0' : formatCompactNumber(value)} kg',
                          style: TextStyle(
                            color: value < 0 ? p.danger : p.text1,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Legend of the chart, in words next to each colour.
class MaterialChartLegend extends StatelessWidget {
  const MaterialChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final (label, color) in [
          ('Nhập', p.primary),
          ('Xuất', p.warning),
          ('Tồn dương', p.success),
          ('Tồn âm', p.danger),
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: p.text2,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Label on the left, value on the right; opens a picker ("Nhóm vật liệu").
class MaterialInlineSelect extends StatelessWidget {
  const MaterialInlineSelect({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.inputBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: p.text2,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text1,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.chevronDown, size: 16, color: p.text2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma C07: "Xuất tổng trong kỳ", pinned above the vouchers.
class MaterialSummaryExportCard extends StatelessWidget {
  const MaterialSummaryExportCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final MaterialTransaction summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final details = summary.details.where((item) => item.quantityKg != 0);
    final count = details.length;
    final hasExport = count > 0;
    return Semantics(
      button: hasExport,
      label:
          'Xuất tổng trong kỳ ${formatSignedNumber(summary.exportQuantityKg)} kg, '
          'giá trị ${formatVnd(summary.valueVnd ?? 0)}',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: hasExport ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Xuất tổng trong kỳ',
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hasExport)
                      Icon(LucideIcons.chevronRight, size: 16, color: p.text3),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${formatSignedNumber(summary.exportQuantityKg)} kg',
                          style: TextStyle(
                            color: p.text1,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatVnd(summary.valueVnd ?? 0),
                      style: TextStyle(
                        color: p.text2,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasExport
                      ? 'Mẻ trộn và phiếu xuất · $count vật liệu'
                      : 'Không có mẻ trộn hay phiếu xuất nào trong kỳ',
                  style: TextStyle(
                    color: p.text2,
                    fontSize: 13,
                    height: 18 / 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// No-break spaces keep "Nhập kho" together when a row wraps.
String materialVoucherTypeName(MaterialTransaction voucher) => voucher.isSummary
    ? 'Xuất tổng'
    : voucher.isImport
    ? 'Nhập kho'
    : voucher.isStocktake
    ? 'Kiểm kê'
    : 'Xuất kho';

/// "+120.000 kg" for an import, "−8.500 kg" for an export or stocktake.
String materialVoucherQuantity(MaterialTransaction voucher) {
  final quantity = voucher.isImport
      ? voucher.importQuantityKg
      : voucher.exportQuantityKg;
  final text = formatSignedNumber(quantity.abs());
  if (quantity == 0) return '0 kg';
  return voucher.isImport ? '+$text kg' : '−$text kg';
}

/// Value of the voucher; an import without a price says so instead of 0 đ.
String materialVoucherValue(MaterialTransaction voucher) {
  final value = voucher.valueVnd;
  if (voucher.isImport && (value == null || value == 0)) return 'Chưa có giá';
  if (value == null) return '—';
  return formatVnd(value);
}

/// One voucher of the list (Figma C07).
class MaterialVoucherRow extends StatelessWidget {
  const MaterialVoucherRow({
    super.key,
    required this.voucher,
    required this.onTap,
  });

  final MaterialTransaction voucher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, tone) = voucher.isImport
        ? (LucideIcons.arrowDownLeft, AppTone.success)
        : voucher.isStocktake
        ? (LucideIcons.sigma, AppTone.violet)
        : (LucideIcons.arrowUpRight, AppTone.warning);
    final occurredAt = voucher.occurredAt;
    final type = materialVoucherTypeName(voucher);
    final quantity = materialVoucherQuantity(voucher);
    return NavRow(
      leading: IconTile(icon: icon, tone: tone),
      title: voucher.content,
      titleMaxLines: 2,
      subtitle: occurredAt == null
          ? type
          : '${formatShortVietnamDateTime(occurredAt)} · $type',
      subtitleMaxLines: 2,
      showChevron: false,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            quantity,
            style: TextStyle(
              color: voucher.isImport ? p.success : p.text1,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            materialVoucherValue(voucher),
            style: TextStyle(
              color: p.text2,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Shown while the report is computed: it adds up the whole mixing history
/// and can take a few seconds, so say so (a lone spinner looks stuck).
class MaterialLoadingCard extends StatelessWidget {
  const MaterialLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang tính tồn kho…',
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Cần cộng toàn bộ lịch sử trộn của trạm nên có thể '
                        'mất vài giây.',
                        style: TextStyle(
                          color: p.text2,
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final rows in const [3, 2]) ...[
          _SkeletonBar(width: 60, height: 12, color: p.surfaceMuted),
          const SizedBox(height: 10),
          InsetCard(
            children: [
              for (var index = 0; index < rows; index++)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _SkeletonBar(
                            width: 90,
                            height: 14,
                            color: p.surfaceMuted,
                          ),
                          const Spacer(),
                          _SkeletonBar(
                            width: 120,
                            height: 14,
                            color: p.surfaceMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SkeletonBar(
                        width: 200,
                        height: 10,
                        color: p.surfaceMuted,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

/// A row of the detail sheets: label (and a hint) on the left, value right.
class _SheetValueRow extends StatelessWidget {
  const _SheetValueRow({
    required this.label,
    required this.value,
    this.note,
    this.muted = false,
  });

  final String label;
  final String value;
  final String? note;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: p.text2,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    style: TextStyle(
                      color: p.text3,
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right edge whatever its length; long values wrap within it.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: muted ? p.text3 : p.text1,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma C05c: the web "Chi tiết" of a material, plus its export in the
/// period and its FIFO value.
Future<void> showMaterialDetails(
  BuildContext context, {
  required MaterialSummaryItem item,
  required MaterialUnit unit,
  required DateTime inventoryAsOf,
  required String periodLabel,
  required double? periodExportKg,
}) => showAppSheet<void>(
  context: context,
  title: item.name,
  builder: (context) {
    final p = context.palette;
    final stock = item.inventoryQuantityKg;
    final state = materialStockState(stock);
    final (fg, bg) = p.tone(switch (state) {
      MaterialStockState.negative => AppTone.danger,
      MaterialStockState.empty => AppTone.neutral,
      MaterialStockState.inStock => AppTone.success,
    });
    final perCubicMeter = item.kilogramsPerCubicMeter;
    final perLiter = item.kilogramsPerLiter;
    final conversion = perCubicMeter != null && perCubicMeter > 0
        ? ('Quy đổi m³', '1 m³ = ${formatSignedNumber(perCubicMeter)} kg')
        : perLiter != null && perLiter > 0
        ? (
            'Quy đổi lít',
            '1 lít = ${formatSignedNumber(perLiter, decimals: 2)} kg',
          )
        : ('Quy đổi', kNoConversionFactor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [
            'Nhóm ${materialGroupName(item.groupCode)}',
            if (item.slotNumber != null) 'cửa số ${item.slotNumber}',
          ].join(' · '),
          style: TextStyle(
            color: p.text2,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tồn kho',
                style: TextStyle(
                  color: p.text2,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    formatMaterialQuantity(stock, unit, item),
                    style: TextStyle(
                      color: state == MaterialStockState.negative
                          ? fg
                          : p.text1,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      state.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InsetCard(
          children: [
            _SheetValueRow(
              label: 'Tổng nhập',
              value: formatMaterialQuantity(item.importQuantityKg, unit, item),
            ),
            _SheetValueRow(
              label: 'Tổng xuất',
              value: formatMaterialQuantity(item.exportQuantityKg, unit, item),
            ),
            _SheetValueRow(
              label: 'Xuất trong kỳ',
              note: periodLabel,
              value: periodExportKg == null
                  ? '—'
                  : formatMaterialQuantity(periodExportKg, unit, item),
            ),
            _SheetValueRow(
              label: 'Giá trị tồn',
              note: 'Tính theo FIFO từ đơn giá nhập',
              value: formatVnd(item.inventoryValueVnd),
            ),
            _SheetValueRow(
              label: conversion.$1,
              note: conversion.$2 == kNoConversionFactor
                  ? 'Lấy từ phiếu nhập có khối lượng quy đổi'
                  : null,
              value: conversion.$2,
              muted: conversion.$2 == kNoConversionFactor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(LucideIcons.info, size: 15, color: p.text2),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Nhập, xuất và tồn lũy kế đến '
                '${formatVietnamDateTime(inventoryAsOf)}',
                style: TextStyle(
                  color: p.text2,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  },
);

/// Figma C07b: a voucher (or the "Xuất tổng" row) and one card per material.
Future<void> showMaterialTransactionDetails(
  BuildContext context,
  MaterialTransaction transaction,
) => showAppSheet<void>(
  context: context,
  title: transaction.isSummary ? 'Xuất tổng trong kỳ' : transaction.content,
  builder: (context) {
    final p = context.palette;
    final note = transaction.note?.trim();
    final occurredAt = transaction.occurredAt;
    final from = transaction.periodFrom, to = transaction.periodTo;
    final when = occurredAt != null
        ? formatVietnamDateTime(occurredAt)
        : from != null && to != null
        ? '${formatVietnamDateTime(from)} – ${formatVietnamDateTime(to)}'
        : null;
    final tone = transaction.isImport
        ? AppTone.success
        : transaction.isStocktake
        ? AppTone.violet
        : AppTone.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (when != null)
          Text(
            when,
            style: TextStyle(
              color: p.text2,
              fontSize: 14,
              height: 19 / 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MaterialPill(
              label: materialVoucherTypeName(transaction),
              tone: tone,
            ),
            Text(
              '${materialVoucherQuantity(transaction)} · '
              '${materialVoucherValue(transaction)}',
              style: TextStyle(
                color: p.text1,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Ghi chú: $note',
            style: TextStyle(
              color: p.text2,
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const GroupLabel('Chi tiết vật liệu'),
        const SizedBox(height: 8),
        if (transaction.details.isEmpty)
          Text(
            'Phiếu này không có dòng chi tiết.',
            style: TextStyle(color: p.text2, fontSize: 14),
          )
        else
          for (final detail in transaction.details) ...[
            InsetCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Text(
                    detail.name,
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SheetValueRow(
                  label: 'Khối lượng',
                  value: '${formatSignedNumber(detail.quantityKg)} kg',
                ),
                if (!transaction.isSummary)
                  _SheetValueRow(
                    label: 'Đơn giá',
                    value:
                        detail.unitPriceVndPerKg == null ||
                            detail.unitPriceVndPerKg == 0
                        ? 'Chưa có giá'
                        : '${formatSignedNumber(detail.unitPriceVndPerKg!, decimals: detail.unitPriceVndPerKg! % 1 == 0 ? 0 : 2)} đ/kg',
                    muted:
                        detail.unitPriceVndPerKg == null ||
                        detail.unitPriceVndPerKg == 0,
                  ),
                _SheetValueRow(
                  label: transaction.isImport ? 'Thành tiền' : 'Giá trị FIFO',
                  value: detail.valueVnd == null
                      ? '—'
                      : formatVnd(detail.valueVnd!),
                ),
                if (detail.conversionVolume != null &&
                    detail.conversionVolume! > 0)
                  _SheetValueRow(
                    label: 'Quy đổi',
                    note: detail.conversionCoefficientKgPerUnit == null
                        ? null
                        : '1 ${detail.conversionUnit ?? 'đơn vị'} = '
                              '${formatSignedNumber(detail.conversionCoefficientKgPerUnit!)} kg',
                    value:
                        '${formatSignedNumber(detail.conversionVolume!, decimals: detail.conversionVolume! % 1 == 0 ? 0 : 2)} '
                                '${detail.conversionUnit ?? ''}'
                            .trim(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  },
);

String formatVietnamDateTime(DateTime utc) {
  final value = utcToVietnamTime(utc);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

/// "21/09 08:15" (Vietnam time) for list rows.
String formatShortVietnamDateTime(DateTime utc) {
  final value = utcToVietnamTime(utc);
  String two(int number) => number.toString().padLeft(2, '0');
  // No-break space: the date and time stay on one line.
  return '${two(value.day)}/${two(value.month)} '
      '${two(value.hour)}:${two(value.minute)}';
}
