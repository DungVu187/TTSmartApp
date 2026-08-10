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
      _ResultColumn('Mã phiếu', (item) => _text(item.ticketCode)),
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
    return _ResultTable<WeighStationItem>(
      key: const ValueKey<String>('weigh-station-detail-table'),
      columns: columns,
      items: page.items,
      rowKey: (item) => ValueKey<String>('weigh-station-detail-${item.id}'),
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
    return _ResultTable<WeighStationSummaryItem>(
      key: const ValueKey<String>('weigh-station-summary-table'),
      columns: columns,
      items: summary.items,
      rowKey: (item) => ValueKey<String>('weigh-station-summary-${item.stt}'),
      dataRowHeight: _summaryRowHeight(summary.items),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final values = <Widget>[
              _SummaryTotalValue(
                label: 'Khối lượng',
                value: Text('${_number(summary.totalGoodsWeightKg)} kg'),
              ),
              _SummaryTotalValue(
                label: 'Khối lượng quy đổi',
                value: _ConvertedQuantities(
                  values: summary.totalConvertedQuantities,
                ),
              ),
            ];
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tổng',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < values.length; index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    values[index],
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'Tổng',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(child: values[0]),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: values[1]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryTotalValue extends StatelessWidget {
  const _SummaryTotalValue({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 3),
        DefaultTextStyle(
          style:
              theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ) ??
              const TextStyle(fontWeight: FontWeight.w800),
          child: value,
        ),
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
    required this.columns,
    required this.items,
    required this.rowKey,
    this.dataRowHeight = 44,
  });

  final List<_ResultColumn<T>> columns;
  final List<T> items;
  final LocalKey Function(T item) rowKey;
  final double dataRowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
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
              for (final column in columns)
                DataColumn(numeric: column.numeric, label: Text(column.label)),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  key: rowKey(item),
                  cells: [
                    for (final column in columns)
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
