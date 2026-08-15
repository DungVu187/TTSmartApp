import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
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
              color: AppColors.success,
              icon: Icons.south_west,
            ),
            (
              label: 'Tổng xuất',
              value: totals.exportQuantityKg,
              color: AppColors.danger,
              icon: Icons.north_east,
            ),
            (
              label: 'Tồn hiện tại',
              value: totals.inventoryQuantityKg,
              color: AppColors.brandBlue,
              icon: Icons.inventory_2_outlined,
            ),
          ]
        : <({String label, double value, Color color, IconData icon})>[
            (
              label: 'Giá trị nhập',
              value: totals.importValueVnd,
              color: AppColors.success,
              icon: Icons.south_west,
            ),
            (
              label: 'Giá trị xuất',
              value: totals.exportValueVnd,
              color: AppColors.danger,
              icon: Icons.north_east,
            ),
            (
              label: 'Giá trị tồn',
              value: totals.inventoryValueVnd,
              color: AppColors.brandBlue,
              icon: Icons.account_balance_wallet_outlined,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
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
                          style: const TextStyle(
                            color: AppColors.mutedText,
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
                                ? AppColors.danger
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 150,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) =>
              _MaterialComparisonCard(item: items[index], valueMode: valueMode),
        );
      },
    );
  }
}

class _MaterialComparisonCard extends StatelessWidget {
  const _MaterialComparisonCard({required this.item, required this.valueMode});

  final MaterialChartItem item;
  final MaterialValueMode valueMode;

  @override
  Widget build(BuildContext context) {
    final imported = valueMode == MaterialValueMode.quantity
        ? item.importQuantityKg
        : item.importValueVnd;
    final exported = valueMode == MaterialValueMode.quantity
        ? item.exportQuantityKg
        : item.exportValueVnd;
    final inventory = valueMode == MaterialValueMode.quantity
        ? item.inventoryQuantityKg
        : item.inventoryValueVnd;
    final scale = math.max(1.0, math.max(imported.abs(), exported.abs()));
    String display(double value) => valueMode == MaterialValueMode.quantity
        ? formatWeight(value)
        : formatCurrency(value);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Tồn ${display(inventory)}',
                style: TextStyle(
                  color: inventory < 0 ? AppColors.danger : AppColors.brandBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ComparisonBar(
            label: 'Nhập',
            value: imported,
            maximum: scale,
            color: AppColors.success,
            displayValue: display(imported),
          ),
          const SizedBox(height: 10),
          _ComparisonBar(
            label: 'Xuất',
            value: exported,
            maximum: scale,
            color: AppColors.danger,
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
    required this.color,
    required this.displayValue,
  });

  final String label;
  final double value;
  final double maximum;
  final Color color;
  final String displayValue;

  @override
  Widget build(BuildContext context) {
    final ratio = (value.abs() / maximum).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.1),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 94,
          child: Text(
            displayValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
        ? AppColors.brandBlue
        : isImport
        ? AppColors.success
        : AppColors.danger;
    return Material(
      color: transaction.isSummary
          ? AppColors.brandBlue.withValues(alpha: 0.06)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
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
                      ? Icons.functions
                      : isImport
                      ? Icons.south_west
                      : Icons.north_east,
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
                      style: const TextStyle(
                        color: AppColors.mutedText,
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
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Icons.chevron_right, color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMaterialTransactionDetails(
  BuildContext context,
  MaterialTransaction transaction,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.72,
    minChildSize: 0.45,
    maxChildSize: 0.94,
    builder: (context, scrollController) => ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        Text(
          transaction.content,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          transaction.occurredAt == null
              ? transaction.id
              : '${formatVietnamDateTime(transaction.occurredAt!)} • ${transaction.id}',
          style: const TextStyle(color: AppColors.mutedText),
        ),
        if (transaction.note?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(transaction.note!),
        ],
        const SizedBox(height: 20),
        Text(
          'Chi tiết vật liệu',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (transaction.details.isEmpty)
          const _InlineEmpty(message: 'Phiếu này không có dòng chi tiết.')
        else
          for (final detail in transaction.details) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _DetailLine(
                    label: 'Khối lượng',
                    value: formatWeight(detail.quantityKg),
                  ),
                  _DetailLine(
                    label: 'Đơn giá',
                    value: detail.unitPriceVndPerKg == null
                        ? 'Chưa có giá'
                        : '${formatCurrency(detail.unitPriceVndPerKg!)}/kg',
                  ),
                  _DetailLine(
                    label: 'Thành tiền',
                    value: detail.valueVnd == null
                        ? '—'
                        : formatCurrency(detail.valueVnd!),
                  ),
                  if (detail.conversionVolume != null)
                    _DetailLine(
                      label: 'Quy đổi',
                      value:
                          '${formatNumber(detail.conversionVolume!)} ${detail.conversionUnit ?? ''}'
                              .trim(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    ),
  ),
);

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.mutedText),
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
  final fraction = parts.length == 2 ? ',${parts.last}' : '';
  return '${value < 0 ? '-' : ''}$buffer$fraction';
}
