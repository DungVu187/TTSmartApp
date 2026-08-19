import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../data/models/weigh_station_result_models.dart';

class WeighStationDetailTable extends StatelessWidget {
  const WeighStationDetailTable({super.key, required this.page});

  final WeighStationPage page;

  @override
  Widget build(BuildContext context) {
    final columns = <_ResultColumn<WeighStationItem>>[
      _ResultColumn('STT', (item) => '${item.stt}', numeric: true),
      _ResultColumn('Số phiếu', (item) => '${item.ticketNumber}'),
      _ResultColumn('Ngày cân', (item) => _dateTime(item.weighingAt)),
      _ResultColumn('Biển số xe', (item) => _text(item.vehiclePlate)),
      _ResultColumn('Lái xe', (item) => _text(item.driverName)),
      _ResultColumn('Số seal', (item) => _text(item.sealNumber)),
      _ResultColumn(
        'KL vào (kg)',
        (item) => _numberOrDash(item.inboundWeightKg),
        numeric: true,
      ),
      _ResultColumn(
        'KL ra (kg)',
        (item) => _numberOrDash(item.outboundWeightKg),
        numeric: true,
      ),
      _ResultColumn(
        'KL hàng (kg)',
        (item) => _numberOrDash(item.goodsWeightKg),
        numeric: true,
      ),
      _ResultColumn.widget(
        'Khối lượng quy đổi',
        (item) => _DetailConversion(item: item),
        numeric: true,
      ),
      _ResultColumn('Đơn vị', (item) => _text(item.unitName)),
      _ResultColumn('Tên hàng', (item) => _text(item.goodsName)),
      _ResultColumn('Kiểu cân', (item) => _text(item.weighingType)),
      _ResultColumn('NV cân lần 1', (item) => _text(item.firstOperatorName)),
      _ResultColumn('NV cân lần 2', (item) => _text(item.secondOperatorName)),
      _ResultColumn('Giờ cân lần 1', (item) => _dateTime(item.weighedInAt)),
      _ResultColumn('Giờ cân lần 2', (item) => _dateTime(item.weighedOutAt)),
      if (page.canViewMaterialValue)
        _ResultColumn(
          'Giá trị (VNĐ)',
          (item) => _currencyOrDash(item.materialValueVnd),
          numeric: true,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return _DetailCardList(page: page);
        }
        return _ResultTable<WeighStationItem>(
          key: const ValueKey<String>('weigh-station-detail-table'),
          horizontalScrollKey: const ValueKey<String>(
            'weigh-station-detail-horizontal-scroll',
          ),
          pinnedColumns: const [
            _PinnedColumnConfig(
              index: 0,
              width: 52,
              key: ValueKey<String>('weigh-station-detail-pinned-index'),
            ),
            _PinnedColumnConfig(
              index: 1,
              width: 82,
              key: ValueKey<String>(
                'weigh-station-detail-pinned-ticket-number',
              ),
            ),
          ],
          columns: columns,
          items: page.items,
          rowKey: (item) => ValueKey<String>('weigh-station-detail-${item.id}'),
        );
      },
    );
  }
}

class WeighStationSummaryTable extends StatelessWidget {
  const WeighStationSummaryTable({super.key, required this.summary});

  final WeighStationSummary summary;

  @override
  Widget build(BuildContext context) {
    final columns = <_ResultColumn<WeighStationSummaryItem>>[
      _ResultColumn('STT', (item) => '${item.stt}', numeric: true),
      _ResultColumn('Tên hàng', (item) => _text(item.goodsName)),
      _ResultColumn(
        'Khối lượng (kg)',
        (item) => _number(item.goodsWeightKg),
        numeric: true,
      ),
      _ResultColumn.widget(
        'Khối lượng quy đổi',
        (item) => _ConvertedQuantities(
          values: item.convertedQuantities,
          conversionMessage: item.conversionMessage,
        ),
        numeric: true,
      ),
      if (summary.canViewMaterialValue)
        _ResultColumn(
          'Giá trị (VNĐ)',
          (item) => _currencyOrDash(item.materialValueVnd),
          numeric: true,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return _SummaryCardList(summary: summary);
        }
        return _ResultTable<WeighStationSummaryItem>(
          key: const ValueKey<String>('weigh-station-summary-table'),
          horizontalScrollKey: const ValueKey<String>(
            'weigh-station-summary-horizontal-scroll',
          ),
          columns: columns,
          items: summary.items,
          rowKey: (item) =>
              ValueKey<String>('weigh-station-summary-${item.stt}'),
          dataRowHeight: _summaryRowHeight(summary.items),
        );
      },
    );
  }
}

class WeighStationSummaryOverview extends StatelessWidget {
  const WeighStationSummaryOverview({super.key, required this.summary});

  final WeighStationSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey<String>('weigh-station-summary-overview'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final values = <Widget>[
              _SummaryMetricCard(
                icon: Icons.category_outlined,
                label: 'Tổng số loại hàng',
                value: '${summary.totalCount}',
                suffix: 'loại',
              ),
              _SummaryMetricCard(
                icon: Icons.monitor_weight_outlined,
                label: 'Tổng khối lượng',
                value: _number(summary.totalGoodsWeightKg),
                suffix: 'kg',
              ),
              _SummaryMetricCard(
                icon: Icons.trending_up_rounded,
                label: 'Loại hàng nhiều nhất',
                value: _text(summary.topGoods?.goodsName),
                detail: summary.topGoods == null
                    ? null
                    : '${_number(summary.topGoods!.goodsWeightKg)} kg',
              ),
              if (summary.canViewMaterialValue)
                _SummaryMetricCard(
                  icon: Icons.payments_outlined,
                  label: 'Tổng giá trị',
                  value: _currencyOrDash(summary.totalMaterialValueVnd),
                ),
              _SummaryMetricCard(
                icon: Icons.swap_vert_rounded,
                label: 'Khối lượng quy đổi',
                valueWidget: _ConvertedQuantities(
                  values: summary.totalConvertedQuantities,
                ),
              ),
            ];
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final gap = 10.0;
            final width =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tổng quan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final value in values)
                      SizedBox(width: width, child: value),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.suffix,
    this.detail,
  }) : assert(value != null || valueWidget != null);

  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? suffix;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, size: 20, color: AppColors.brandBlue),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ) ??
                        const TextStyle(fontWeight: FontWeight.w800),
                    child:
                        valueWidget ??
                        Text(
                          [value, suffix]
                              .where((part) => part != null && part.isNotEmpty)
                              .join(' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCardList extends StatelessWidget {
  const _DetailCardList({required this.page});

  final WeighStationPage page;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('weigh-station-detail-card-list'),
      children: [
        for (final item in page.items) ...[
          _DetailCard(item: item, showMaterialValue: page.canViewMaterialValue),
          if (item != page.items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.item, required this.showMaterialValue});

  final WeighStationItem item;
  final bool showMaterialValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey<String>('weigh-station-detail-card-${item.id}'),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'weigh-station-detail-expansion-${item.id}',
        ),
        tilePadding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _text(item.vehiclePlate),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            _StatusPill(label: _text(item.weighingType)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(item.goodsName),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PrimaryValue(
                      label: 'Khối lượng hàng',
                      value: '${_numberOrDash(item.goodsWeightKg)} kg',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PrimaryValue(
                      label: 'Quy đổi',
                      valueWidget: _DetailConversion(item: item),
                    ),
                  ),
                ],
              ),
              if (showMaterialValue) ...[
                const SizedBox(height: 10),
                _InfoLine(
                  icon: Icons.payments_outlined,
                  label: 'Giá trị',
                  value: _currencyOrDash(item.materialValueVnd),
                  emphasized: true,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Phiếu #${item.ticketNumber} · ${_dateTime(item.weighingAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 12),
          _WeightPair(item: item),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.person_outline,
            label: 'Lái xe',
            value: _text(item.driverName),
          ),
          _InfoLine(
            icon: Icons.business_outlined,
            label: 'Đơn vị',
            value: _text(item.unitName),
          ),
          _InfoLine(
            icon: Icons.qr_code_2_outlined,
            label: 'Mã phiếu / niêm chì',
            value: '${_text(item.ticketCode)} / ${_text(item.sealNumber)}',
          ),
          _InfoLine(
            icon: Icons.login_rounded,
            label: 'Cân lần 1',
            value:
                '${_text(item.firstOperatorName)} · ${_dateTime(item.weighedInAt)}',
          ),
          _InfoLine(
            icon: Icons.logout_rounded,
            label: 'Cân lần 2',
            value:
                '${_text(item.secondOperatorName)} · ${_dateTime(item.weighedOutAt)}',
          ),
        ],
      ),
    );
  }
}

class _WeightPair extends StatelessWidget {
  const _WeightPair({required this.item});

  final WeighStationItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WeightBox(
            label: 'Cân vào',
            value: '${_numberOrDash(item.inboundWeightKg)} kg',
            icon: Icons.call_received_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _WeightBox(
            label: 'Cân ra',
            value: '${_numberOrDash(item.outboundWeightKg)} kg',
            icon: Icons.call_made_rounded,
          ),
        ),
      ],
    );
  }
}

class _WeightBox extends StatelessWidget {
  const _WeightBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.brandBlue),
                const SizedBox(width: 6),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _PrimaryValue extends StatelessWidget {
  const _PrimaryValue({required this.label, this.value, this.valueWidget})
    : assert(value != null || valueWidget != null);

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 3),
        DefaultTextStyle(
          style:
              Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ) ??
              const TextStyle(fontWeight: FontWeight.w900),
          child: valueWidget ?? Text(value!),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.brandTeal,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.mutedText),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
                color: emphasized ? AppColors.brandTeal : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardList extends StatelessWidget {
  const _SummaryCardList({required this.summary});

  final WeighStationSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('weigh-station-summary-card-list'),
      children: [
        for (final item in summary.items) ...[
          Card(
            key: ValueKey<String>('weigh-station-summary-card-${item.stt}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _text(item.goodsName),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (item.ticketCount > 0)
                        _StatusPill(label: '${item.ticketCount} phiếu'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PrimaryValue(
                          label: 'Khối lượng',
                          value: '${_number(item.goodsWeightKg)} kg',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PrimaryValue(
                          label: 'Quy đổi',
                          valueWidget: _ConvertedQuantities(
                            values: item.convertedQuantities,
                            conversionMessage: item.conversionMessage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (summary.canViewMaterialValue) ...[
                    const Divider(height: 24),
                    _InfoLine(
                      icon: Icons.payments_outlined,
                      label: 'Giá trị',
                      value: _currencyOrDash(item.materialValueVnd),
                      emphasized: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (item != summary.items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ConvertedQuantities extends StatelessWidget {
  const _ConvertedQuantities({required this.values, this.conversionMessage});

  final List<WeighStationConvertedQuantity> values;
  final String? conversionMessage;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty && conversionMessage == null) return const Text('-');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final value in values)
          Text(
            '${_number(value.quantity)} ${value.unit.trim()}'.trim(),
            style: const TextStyle(height: 1.05),
          ),
        if (conversionMessage case final message?)
          _ConversionWarning(message: message),
      ],
    );
  }
}

class _DetailConversion extends StatelessWidget {
  const _DetailConversion({required this.item});

  final WeighStationItem item;

  @override
  Widget build(BuildContext context) {
    if (item.conversionMessage case final message?) {
      return _ConversionWarning(message: message);
    }
    final quantity = item.convertedQuantity;
    if (quantity == null) return const Text('-');
    final unit = item.convertedUnit?.trim();
    return Text(
      unit == null || unit.isEmpty
          ? _number(quantity)
          : '${_number(quantity)} $unit',
      style: const TextStyle(height: 1.05),
    );
  }
}

class _ConversionWarning extends StatelessWidget {
  const _ConversionWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTable<T> extends StatelessWidget {
  const _ResultTable({
    super.key,
    required this.horizontalScrollKey,
    required this.columns,
    required this.items,
    required this.rowKey,
    this.pinnedColumns = const [],
    this.dataRowHeight = 44,
  });

  final Key horizontalScrollKey;
  final List<_PinnedColumnConfig> pinnedColumns;
  final List<_ResultColumn<T>> columns;
  final List<T> items;
  final LocalKey Function(T item) rowKey;
  final double dataRowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinnedIndices = pinnedColumns
        .map((configuration) => configuration.index)
        .toSet();
    final scrollingColumns = [
      for (var index = 0; index < columns.length; index++)
        if (!pinnedIndices.contains(index)) columns[index],
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pinnedColumns.isNotEmpty)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final configuration in pinnedColumns)
                      SizedBox(
                        key: configuration.key,
                        width: configuration.width,
                        child: _PinnedResultColumn<T>(
                          column: columns[configuration.index],
                          items: items,
                          dataRowHeight: dataRowHeight,
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                key: horizontalScrollKey,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                  ),
                  headingTextStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                    fontSize: 12,
                    height: 1.05,
                  ),
                  dataTextStyle: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF1F2937),
                    height: 1.05,
                  ),
                  headingRowHeight: 42,
                  columnSpacing: 18,
                  horizontalMargin: 10,
                  dataRowMinHeight: dataRowHeight,
                  dataRowMaxHeight: dataRowHeight,
                  dividerThickness: 0.7,
                  columns: [
                    for (final column in scrollingColumns)
                      DataColumn(
                        numeric: column.numeric,
                        label: Text(column.label),
                      ),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        key: rowKey(item),
                        cells: [
                          for (final column in scrollingColumns)
                            DataCell(
                              column.valueWidget?.call(item) ??
                                  Text(
                                    column.value!(item),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedColumnConfig {
  const _PinnedColumnConfig({
    required this.index,
    required this.width,
    required this.key,
  });

  final int index;
  final double width;
  final Key key;
}

class _PinnedResultColumn<T> extends StatelessWidget {
  const _PinnedResultColumn({
    required this.column,
    required this.items,
    required this.dataRowHeight,
  });

  final _ResultColumn<T> column;
  final List<T> items;
  final double dataRowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: 42,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
          child: Text(
            column.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
              fontSize: 12,
              height: 1.05,
            ),
          ),
        ),
        for (final item in items)
          Container(
            height: dataRowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.7),
              ),
            ),
            child:
                column.valueWidget?.call(item) ??
                Text(
                  column.value!(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF1F2937),
                    height: 1.05,
                  ),
                ),
          ),
      ],
    );
  }
}

class _ResultColumn<T> {
  const _ResultColumn(this.label, this.value, {this.numeric = false})
    : valueWidget = null,
      assert(value != null);

  const _ResultColumn.widget(
    this.label,
    this.valueWidget, {
    this.numeric = false,
  }) : value = null,
       assert(valueWidget != null);

  final String label;
  final String Function(T item)? value;
  final bool numeric;
  final Widget Function(T item)? valueWidget;
}

double _summaryRowHeight(List<WeighStationSummaryItem> items) {
  var maximumLineCount = 1;
  for (final item in items) {
    final lineCount =
        item.convertedQuantities.length +
        (item.conversionMessage == null ? 0 : 1);
    if (lineCount > maximumLineCount) {
      maximumLineCount = lineCount;
    }
  }
  return 44 + ((maximumLineCount - 1) * 14);
}

String _text(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? '—' : normalized;
}

String _dateTime(DateTime? value) {
  if (value == null) return '—';
  final vietnam = utcToVietnamTime(value);
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(vietnam.day)}/${twoDigits(vietnam.month)}/${vietnam.year} '
      '${twoDigits(vietnam.hour)}:${twoDigits(vietnam.minute)}';
}

String _numberOrDash(double? value) => value == null ? '—' : _number(value);

String _number(double value) {
  final parts = value.toStringAsFixed(3).split('.');
  final trimmedFraction = parts.last.replaceFirst(RegExp(r'0+$'), '');
  final fraction = trimmedFraction.isEmpty ? '' : ',$trimmedFraction';
  return '${_groupDigits(parts.first)}$fraction';
}

String _currencyOrDash(double? value) =>
    value == null ? '—' : '${_groupDigits(value.round().toString())} ₫';

String _groupDigits(String value) {
  final negative = value.startsWith('-');
  final digits = negative ? value.substring(1) : value;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}$buffer';
}
