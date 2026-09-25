import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../data/models/material_report_models.dart';

class MaterialTotalsGrid extends StatelessWidget {
  const MaterialTotalsGrid({
    super.key,
    required this.totals,
    required this.valueMode,
  });

  final MaterialReportTotals totals;
  final MaterialValueMode valueMode;

  @override
  Widget build(BuildContext context) {
    final items = valueMode == MaterialValueMode.quantity
        ? <({String label, double value, Color color, IconData icon})>[
            (
              label: 'Tổng nhập',
              value: totals.importQuantityKg,
              color: context.palette.success,
              icon: LucideIcons.arrowDownLeft,
            ),
            (
              label: 'Tổng xuất',
              value: totals.exportQuantityKg,
              color: context.palette.danger,
              icon: LucideIcons.arrowUpRight,
            ),
            (
              label: 'Tồn hiện tại',
              value: totals.inventoryQuantityKg,
              color: context.palette.primary,
              icon: LucideIcons.package,
            ),
          ]
        : <({String label, double value, Color color, IconData icon})>[
            (
              label: 'Giá trị nhập',
              value: totals.importValueVnd,
              color: context.palette.success,
              icon: LucideIcons.arrowDownLeft,
            ),
            (
              label: 'Giá trị xuất',
              value: totals.exportValueVnd,
              color: context.palette.danger,
              icon: LucideIcons.arrowUpRight,
            ),
            (
              label: 'Giá trị tồn',
              value: totals.inventoryValueVnd,
              color: context.palette.primary,
              icon: LucideIcons.wallet,
            ),
          ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 104,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            color: context.palette.text2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          valueMode == MaterialValueMode.quantity
                              ? formatWeight(item.value)
                              : formatCurrency(item.value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.value < 0
                                ? context.palette.danger
                                : item.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Figma C05 "So sánh theo vật liệu": one card, a row per material with
/// import / export bars and the running stock.
class MaterialComparisonList extends StatelessWidget {
  const MaterialComparisonList({
    super.key,
    required this.items,
    required this.valueMode,
  });

  final List<MaterialChartItem> items;
  final MaterialValueMode valueMode;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _InlineEmpty(
        message: 'Không có vật liệu trong nhóm đã chọn.',
      );
    }
    return InsetCard(
      children: [
        for (final item in items)
          _MaterialComparisonRow(item: item, valueMode: valueMode),
      ],
    );
  }
}

class _MaterialComparisonRow extends StatelessWidget {
  const _MaterialComparisonRow({required this.item, required this.valueMode});

  final MaterialChartItem item;
  final MaterialValueMode valueMode;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final byQuantity = valueMode == MaterialValueMode.quantity;
    final imported = byQuantity ? item.importQuantityKg : item.importValueVnd;
    final exported = byQuantity ? item.exportQuantityKg : item.exportValueVnd;
    final inventory = byQuantity
        ? item.inventoryQuantityKg
        : item.inventoryValueVnd;
    final scale = math.max(1.0, math.max(imported.abs(), exported.abs()));
    String display(double value) =>
        byQuantity ? formatWeight(value) : formatCurrency(value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
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
              Text(
                'Tồn ${display(inventory)}',
                style: TextStyle(
                  color: inventory < 0 ? p.danger : p.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ComparisonBar(
            label: 'Nhập',
            value: imported,
            maximum: scale,
            tone: AppTone.success,
            displayValue: display(imported),
          ),
          const SizedBox(height: 10),
          _ComparisonBar(
            label: 'Xuất',
            value: exported,
            maximum: scale,
            tone: AppTone.danger,
            displayValue: display(exported),
          ),
        ],
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.maximum,
    required this.tone,
    required this.displayValue,
  });

  final String label;
  final double value;
  final double maximum;
  final AppTone tone;
  final String displayValue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, bg) = p.tone(tone);
    final ratio = (value.abs() / maximum).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(36),
          child: Text(
            label,
            style: TextStyle(
              color: p.text2,
              fontSize: 13,
              height: 17 / 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: fg,
              backgroundColor: bg,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                height: 17 / 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MaterialTransactionCard extends StatelessWidget {
  const MaterialTransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final MaterialTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isImport = transaction.importQuantityKg > 0;
    final quantity = isImport
        ? transaction.importQuantityKg
        : transaction.exportQuantityKg;
    final color = transaction.isSummary
        ? context.palette.primary
        : isImport
        ? context.palette.success
        : context.palette.danger;
    return Material(
      color: transaction.isSummary
          ? context.palette.primary.withValues(alpha: 0.06)
          : context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.palette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  transaction.isSummary
                      ? LucideIcons.sigma
                      : isImport
                      ? LucideIcons.arrowDownLeft
                      : LucideIcons.arrowUpRight,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      transaction.occurredAt == null
                          ? transaction.id
                          : '${formatVietnamDateTime(transaction.occurredAt!)} • ${transaction.id}',
                      style: TextStyle(
                        color: context.palette.text2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 5,
                      children: [
                        Text(
                          '${isImport ? 'Nhập' : 'Xuất'} ${formatWeight(quantity)}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (transaction.valueVnd != null)
                          Text(
                            formatCurrency(transaction.valueVnd!),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  LucideIcons.chevronRight,
                  color: context.palette.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma C07: movement title, time · id, note and one card per material
/// (Khối lượng / Đơn giá / Thành tiền / Quy đổi).
Future<void> showMaterialTransactionDetails(
  BuildContext context,
  MaterialTransaction transaction,
) => showAppSheet<void>(
  context: context,
  title: transaction.content,
  builder: (context) {
    final p = context.palette;
    final note = transaction.note?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          transaction.occurredAt == null
              ? transaction.id
              : '${formatVietnamDateTime(transaction.occurredAt!)} · '
                    '${transaction.id}',
          style: TextStyle(
            color: p.text2,
            fontSize: 14,
            height: 19 / 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            note,
            style: TextStyle(
              color: p.text1,
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 20),
        const GroupLabel('Chi tiết vật liệu'),
        const SizedBox(height: 8),
        if (transaction.details.isEmpty)
          const _InlineEmpty(message: 'Phiếu này không có dòng chi tiết.')
        else
          for (final detail in transaction.details) ...[
            InsetCard(
              children: [
                // Name and the first pair share a row: no divider between.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 13, 4),
                      child: Text(
                        detail.name,
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 16,
                          height: 21 / 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PairFieldRow(
                      first: ('Khối lượng', formatWeight(detail.quantityKg)),
                      second: (
                        'Đơn giá',
                        detail.unitPriceVndPerKg == null
                            ? 'Chưa có giá'
                            : '${formatCurrency(detail.unitPriceVndPerKg!)}/kg',
                      ),
                    ),
                  ],
                ),
                PairFieldRow(
                  first: (
                    'Thành tiền',
                    detail.valueVnd == null
                        ? '—'
                        : formatCurrency(detail.valueVnd!),
                  ),
                  second: (
                    'Quy đổi',
                    detail.conversionVolume == null
                        ? '—'
                        : '${formatNumber(detail.conversionVolume!)} '
                                  '${detail.conversionUnit ?? ''}'
                              .trim(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  },
);

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.palette.border),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: context.palette.text2),
    ),
  );
}

String formatVietnamDateTime(DateTime utc) {
  final value = utcToVietnamTime(utc);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

String formatWeight(double value) => '${formatNumber(value)} kg';

String formatCurrency(double value) => '${formatNumber(value, decimals: 0)} đ';

String formatNumber(double value, {int decimals = 2}) {
  final effectiveDecimals = value == value.roundToDouble() ? 0 : decimals;
  final parts = value.abs().toStringAsFixed(effectiveDecimals).split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  // "8,60" → "8,6" (Figma C07); whole numbers have no fraction at all.
  final decimalsText = parts.length == 2
      ? parts.last.replaceFirst(RegExp(r'0+$'), '')
      : '';
  final fraction = decimalsText.isEmpty ? '' : ',$decimalsText';
  return '${value < 0 ? '-' : ''}$buffer$fraction';
}

/// "21/09 08:15" (Vietnam time) for list rows.
String formatShortVietnamDateTime(DateTime utc) {
  final value = utcToVietnamTime(utc);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)} '
      '${two(value.hour)}:${two(value.minute)}';
}
