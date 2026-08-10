import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/report_models.dart';

class StatisticsResultsTable extends StatelessWidget {
  const StatisticsResultsTable({super.key, required this.page});

  final OrderStatisticsPage page;

  @override
  Widget build(BuildContext context) {
    final layoutsByKey = <String, OrderStatisticsMaterialLayout>{
      for (final layout in page.layouts) layout.layoutKey: layout,
    };
    final fallbackLayout = page.layouts.isEmpty
        ? const OrderStatisticsMaterialLayout(layoutKey: '', columns: [])
        : page.layouts.first;
    final groupedItems = <String, List<OrderStatisticsItem>>{};
    for (final item in page.items) {
      final layoutKey = item.layoutKey.trim().isEmpty
          ? fallbackLayout.layoutKey
          : item.layoutKey;
      groupedItems.putIfAbsent(layoutKey, () => []).add(item);
    }
    if (groupedItems.isEmpty) {
      groupedItems[fallbackLayout.layoutKey] = <OrderStatisticsItem>[];
    }

    final entries = groupedItems.entries.toList(growable: false);
    return Column(
      key: const ValueKey<String>('statistics-results-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _StatisticsLayoutTable(
            key: ValueKey<String>('statistics-layout-group-$index'),
            groupIndex: index,
            resultToken: page,
            layout: layoutsByKey[entries[index].key] ?? fallbackLayout,
            items: entries[index].value,
            showLayoutLabel: entries.length > 1,
          ),
          if (index < entries.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StatisticsLayoutTable extends StatefulWidget {
  const _StatisticsLayoutTable({
    super.key,
    required this.groupIndex,
    required this.resultToken,
    required this.layout,
    required this.items,
    required this.showLayoutLabel,
  });

  final int groupIndex;
  final Object resultToken;
  final OrderStatisticsMaterialLayout layout;
  final List<OrderStatisticsItem> items;
  final bool showLayoutLabel;

  @override
  State<_StatisticsLayoutTable> createState() => _StatisticsLayoutTableState();
}

class _StatisticsLayoutTableState extends State<_StatisticsLayoutTable> {
  static const _indexWidth = 56.0;
  static const _headerHeight = 48.0;
  static const _rowHeight = 52.0;
  static const _visibleRowCount = OrderStatisticsQuery.pageSize;
  static const _maximumTableHeight =
      _headerHeight + _visibleRowCount * _rowHeight + 1;
  final _headerHorizontal = ScrollController();
  final _bodyHorizontal = ScrollController();
  final _indexVertical = ScrollController();
  final _bodyVertical = ScrollController();
  bool _syncingHorizontal = false;
  bool _syncingVertical = false;

  @override
  void initState() {
    super.initState();
    _headerHorizontal.addListener(_syncHeaderToBody);
    _bodyHorizontal.addListener(_syncBodyToHeader);
    _indexVertical.addListener(_syncIndexToBody);
    _bodyVertical.addListener(_syncBodyToIndex);
  }

  @override
  void didUpdateWidget(covariant _StatisticsLayoutTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.resultToken, widget.resultToken)) return;
    _resetScrollOffsets();
  }

  @override
  void dispose() {
    _headerHorizontal.dispose();
    _bodyHorizontal.dispose();
    _indexVertical.dispose();
    _bodyVertical.dispose();
    super.dispose();
  }

  void _syncHeaderToBody() =>
      _jumpHorizontal(source: _headerHorizontal, target: _bodyHorizontal);

  void _syncBodyToHeader() =>
      _jumpHorizontal(source: _bodyHorizontal, target: _headerHorizontal);

  void _syncIndexToBody() =>
      _jumpVertical(source: _indexVertical, target: _bodyVertical);

  void _syncBodyToIndex() =>
      _jumpVertical(source: _bodyVertical, target: _indexVertical);

  void _jumpHorizontal({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_syncingHorizontal || !target.hasClients) return;
    _syncingHorizontal = true;
    target.jumpTo(source.offset.clamp(0.0, target.position.maxScrollExtent));
    _syncingHorizontal = false;
  }

  void _jumpVertical({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_syncingVertical || !target.hasClients) return;
    _syncingVertical = true;
    target.jumpTo(source.offset.clamp(0.0, target.position.maxScrollExtent));
    _syncingVertical = false;
  }

  void _resetScrollOffsets() {
    if (!mounted) return;
    for (final controller in <ScrollController>[
      _headerHorizontal,
      _bodyHorizontal,
      _indexVertical,
      _bodyVertical,
    ]) {
      if (controller.hasClients && controller.offset != 0) {
        controller.jumpTo(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.items
        .map(_StatisticsRowData.new)
        .toList(growable: false);
    final columns = _columns(widget.layout.columns);
    final dataWidth = columns.fold<double>(
      0,
      (total, column) => total + column.width,
    );
    final rowCount = rows.isEmpty ? 1 : rows.length;
    final tableHeight = (_headerHeight + rowCount * _rowHeight + 1)
        .clamp(160.0, _maximumTableHeight)
        .toDouble();
    final layoutName = widget.layout.layoutKey.trim().isEmpty
        ? 'Bố cục vật liệu ${widget.groupIndex + 1}'
        : 'Bố cục vật liệu ${widget.groupIndex + 1}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showLayoutLabel) ...[
          Text(
            layoutName,
            key: ValueKey<String>(
              'statistics-layout-label-${widget.groupIndex}',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
        ],
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            key: _groupKey('statistics-layout-table-frame'),
            height: tableHeight,
            child: Column(
              children: [
                _buildHeader(columns, dataWidth),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        key: _groupKey('statistics-sticky-index-column'),
                        width: _indexWidth,
                        child: SingleChildScrollView(
                          controller: _indexVertical,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: rows.isEmpty
                                ? [_cell('', _indexWidth, center: true)]
                                : rows
                                      .map(
                                        (row) => _cell(
                                          '${row.item.rowNumber}',
                                          _indexWidth,
                                          center: true,
                                        ),
                                      )
                                      .toList(growable: false),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          key: _groupKey('statistics-table-horizontal-scroll'),
                          controller: _bodyHorizontal,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: dataWidth,
                            child: SingleChildScrollView(
                              controller: _bodyVertical,
                              child: Column(
                                children: rows.isEmpty
                                    ? [
                                        Row(
                                          children: [
                                            _cell(
                                              'Không có dữ liệu',
                                              dataWidth,
                                            ),
                                          ],
                                        ),
                                      ]
                                    : rows
                                          .map(
                                            (row) => Row(
                                              children: columns
                                                  .map(
                                                    (column) => _cell(
                                                      column.value(row),
                                                      column.width,
                                                      center: column.center,
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                          )
                                          .toList(growable: false),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<_StatisticsColumn> _columns(
    List<OrderStatisticsMaterialColumn> materialColumns,
  ) {
    final columns = <_StatisticsColumn>[
      _StatisticsColumn('Trạm', 140, (row) => _text(row.item.stationName)),
      _StatisticsColumn('Ngày', 96, (row) => _date(row.item.mixingDate)),
      _StatisticsColumn('Bắt đầu', 84, (row) => _time(row.item.startedAt)),
      _StatisticsColumn('Kết thúc', 84, (row) => _time(row.item.finishedAt)),
      _StatisticsColumn(
        'Tên khách hàng',
        150,
        (row) => _text(row.item.customerName),
      ),
      _StatisticsColumn('Tên dự án', 140, (row) => _text(row.item.projectName)),
      _StatisticsColumn(
        'Tên hạng mục',
        140,
        (row) => _text(row.item.workItemName),
      ),
      _StatisticsColumn(
        'Tên địa điểm',
        140,
        (row) => _text(row.item.locationName),
      ),
      _StatisticsColumn('Xe', 100, (row) => _text(row.item.vehiclePlate)),
      _StatisticsColumn('Tên lái xe', 120, (row) => _text(row.item.driverName)),
      _StatisticsColumn(
        'Mác bê tông',
        104,
        (row) => _text(row.item.concreteGradeName),
      ),
      _StatisticsColumn('Độ sụt', 84, (row) => _text(row.item.slump)),
      _StatisticsColumn(
        'NV KINH DOANH',
        140,
        (row) => _text(row.item.salesEmployeeName),
      ),
      _StatisticsColumn(
        'TÊN NHÂN VIÊN',
        140,
        (row) => _text(row.item.employeeName),
      ),
      _StatisticsColumn(
        'Thể tích đặt',
        100,
        (row) => _number(row.item.requestedVolume),
        center: true,
      ),
      _StatisticsColumn(
        'Thể tích trộn',
        100,
        (row) => _number(row.item.mixedVolume),
        center: true,
      ),
    ];
    for (final materialColumn in materialColumns) {
      columns.addAll([
        _StatisticsColumn(
          materialColumn.designLabel,
          112,
          (row) =>
              _number(row.materialFor(materialColumn)?.designQuantity ?? 0),
          center: true,
        ),
        _StatisticsColumn(
          materialColumn.tLabel,
          112,
          (row) => _number(row.materialFor(materialColumn)?.tQuantity ?? 0),
          center: true,
        ),
        _StatisticsColumn(
          materialColumn.actualLabel,
          112,
          (row) =>
              _number(row.materialFor(materialColumn)?.actualQuantity ?? 0),
          center: true,
        ),
        _StatisticsColumn(
          materialColumn.varianceLabel,
          112,
          (row) => _number(row.materialFor(materialColumn)?.variance ?? 0),
          center: true,
        ),
      ]);
    }
    return columns;
  }

  Widget _buildHeader(List<_StatisticsColumn> columns, double dataWidth) {
    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: [
          KeyedSubtree(
            key: _groupKey('statistics-sticky-index-header'),
            child: _headerCell('STT', _indexWidth, center: true),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SingleChildScrollView(
              key: _groupKey('statistics-sticky-header-scroll'),
              controller: _headerHorizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: dataWidth,
                child: Row(
                  children: columns
                      .map(
                        (column) => _headerCell(
                          column.label,
                          column.width,
                          center: column.center,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Key _groupKey(String value) => widget.groupIndex == 0
      ? ValueKey<String>(value)
      : ValueKey<String>('$value-${widget.groupIndex}');

  Widget _headerCell(String label, double width, {bool center = false}) =>
      Container(
        width: width,
        height: _headerHeight,
        alignment: center ? Alignment.center : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFF0F5FF),
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      );

  Widget _cell(String value, double width, {bool center = false}) => Container(
    width: width,
    height: _rowHeight,
    alignment: center ? Alignment.center : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(
      border: Border(
        right: BorderSide(color: AppColors.border),
        bottom: BorderSide(color: AppColors.border),
      ),
    ),
    child: Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(fontSize: 12),
    ),
  );
}

class StatisticsMaterialSummaryTable extends StatelessWidget {
  const StatisticsMaterialSummaryTable({super.key, required this.page});

  static const _indexWidth = 58.0;
  static const _quantityWidth = 92.0;
  static const _categoryCodes = <String>[
    'CAT',
    'DA',
    'XIMANG',
    'NUOC',
    'PHUGIA',
  ];

  final OrderStatisticsPage page;

  @override
  Widget build(BuildContext context) {
    final rows = page.materialSummaryRows;
    final categories = _categories(rows);
    final dataWidth = categories.length * _quantityWidth;
    final rowCount = rows.isEmpty ? 1 : rows.length;
    final tableHeight = 52.0 + rowCount * 52 + 52 + 1;
    return Card(
      key: const ValueKey<String>('statistics-material-summary-table'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: tableHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const ValueKey<String>(
                    'statistics-summary-index-column',
                  ),
                  width: _indexWidth,
                  child: Column(
                    children: [
                      _summaryHeaderCell('VẬT LIỆU', _indexWidth, 52),
                      if (rows.isEmpty)
                        _summaryCell('', _indexWidth)
                      else
                        ...rows.map(
                          (row) => _summaryCell(
                            '${row.rowNumber}',
                            _indexWidth,
                            key: ValueKey<String>(
                              'statistics-summary-row-${row.rowNumber}',
                            ),
                          ),
                        ),
                      _summaryCell(
                        'ĐV',
                        _indexWidth,
                        key: const ValueKey<String>(
                          'statistics-summary-unit-row-label',
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey<String>(
                      'statistics-summary-horizontal-scroll',
                    ),
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: dataWidth,
                      child: Column(
                        children: [
                          _summaryHeader(categories),
                          if (rows.isEmpty)
                            _summaryCell('Không có dữ liệu', dataWidth)
                          else
                            ...rows.map((row) => _summaryRow(row, categories)),
                          _summaryUnitRow(categories),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tổng',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _summaryTotalValue(
                  '${_summaryNumber(page.totalMaterialQuantity)} kg',
                  const ValueKey<String>('statistics-summary-total-material'),
                ),
                const SizedBox(height: 6),
                _summaryTotalValue(
                  '${_summaryNumber(page.totalConcreteVolume)} m³',
                  const ValueKey<String>('statistics-summary-total-concrete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTotalValue(String value, Key key) => Text(
    value,
    key: key,
    style: const TextStyle(fontWeight: FontWeight.w800),
  );

  Widget _summaryHeader(List<_SummaryCategory> categories) {
    return SizedBox(
      height: 52,
      child: Row(
        children: categories
            .map(
              (category) => _summaryHeaderCell(
                category.label.toUpperCase(),
                _quantityWidth,
                52,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _summaryRow(
    OrderStatisticsMaterialSummaryRow row,
    List<_SummaryCategory> categories,
  ) {
    final cellsByKey = <String, OrderStatisticsMaterialSummaryCell>{
      for (final cell in row.cells)
        _summaryCellKey(cell.categoryCode, cell.typePosition): cell,
    };
    return Row(
      children: [
        for (final category in categories)
          _summaryCell(
            _summaryNumber(
              cellsByKey[_summaryCellKey(category.code, row.rowNumber)]
                      ?.actualQuantity ??
                  0,
            ),
            _quantityWidth,
            key: ValueKey<String>(
              'statistics-summary-${row.rowNumber}-${category.code}-actual',
            ),
          ),
      ],
    );
  }

  Widget _summaryUnitRow(List<_SummaryCategory> categories) => Row(
    children: [
      for (final category in categories)
        _summaryCell(
          category.unit,
          _quantityWidth,
          key: ValueKey<String>('statistics-summary-unit-${category.code}'),
        ),
    ],
  );

  List<_SummaryCategory> _categories(
    List<OrderStatisticsMaterialSummaryRow> rows,
  ) {
    final labelsByCode = <String, String>{};
    final unitsByCode = <String, String>{};
    for (final row in rows) {
      for (final cell in row.cells) {
        labelsByCode.putIfAbsent(
          cell.categoryCode,
          () => _categoryLabel(cell.categoryCode, cell.category),
        );
        final unit = cell.unit?.trim();
        if (unit != null && unit.isNotEmpty) {
          unitsByCode.putIfAbsent(cell.categoryCode, () => unit);
        }
      }
    }
    final codes = <String>[
      ..._categoryCodes,
      ...labelsByCode.keys.where((code) => !_categoryCodes.contains(code)),
    ];
    return codes
        .map(
          (code) => _SummaryCategory(
            code,
            labelsByCode[code] ?? _categoryLabel(code, null),
            unitsByCode[code] ?? _categoryUnit(code),
          ),
        )
        .toList(growable: false);
  }

  Widget _summaryHeaderCell(String value, double width, double height) =>
      Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: const BoxDecoration(
          color: Color(0xFFF0F5FF),
          border: Border(
            right: BorderSide(color: AppColors.border),
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      );

  Widget _summaryCell(String value, double width, {Key? key}) => Container(
    key: key,
    width: width,
    height: 52,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: const BoxDecoration(
      border: Border(
        right: BorderSide(color: AppColors.border),
        bottom: BorderSide(color: AppColors.border),
      ),
    ),
    child: Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12),
    ),
  );
}

class _StatisticsRowData {
  _StatisticsRowData(this.item)
    : materialsByColumnKey = <String, OrderStatisticsMaterial>{
        for (final material in item.materials)
          if (material.columnKey.trim().isNotEmpty)
            material.columnKey: material,
      },
      materialsBySlotNumber = <int, OrderStatisticsMaterial>{
        for (final material in item.materials) material.slotNumber: material,
      };

  final OrderStatisticsItem item;
  final Map<String, OrderStatisticsMaterial> materialsByColumnKey;
  final Map<int, OrderStatisticsMaterial> materialsBySlotNumber;

  OrderStatisticsMaterial? materialFor(OrderStatisticsMaterialColumn column) {
    if (column.columnKey.trim().isNotEmpty) {
      return materialsByColumnKey[column.columnKey];
    }
    return materialsBySlotNumber[column.slotNumber];
  }
}

class _StatisticsColumn {
  const _StatisticsColumn(
    this.label,
    this.width,
    this.value, {
    this.center = false,
  });

  final String label;
  final double width;
  final String Function(_StatisticsRowData row) value;
  final bool center;
}

class _SummaryCategory {
  const _SummaryCategory(this.code, this.label, this.unit);

  final String code;
  final String label;
  final String unit;
}

String _summaryCellKey(String categoryCode, int typePosition) =>
    '$categoryCode|$typePosition';

String _categoryLabel(String code, String? fallback) => switch (code) {
  'CAT' => 'Cát',
  'DA' => 'Đá',
  'XIMANG' => 'Xi măng',
  'NUOC' => 'Nước',
  'PHUGIA' => 'Phụ gia',
  _ => fallback?.trim().isNotEmpty == true ? fallback!.trim() : code,
};

String _categoryUnit(String code) => code == 'NUOC' ? 'LÍT' : 'KG';

String _text(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? '—' : normalized;
}

String _date(DateTime? value) {
  if (value == null) return '—';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _time(DateTime? value) {
  if (value == null) return '—';
  final vietnam = value.toUtc().add(const Duration(hours: 7));
  return '${vietnam.hour.toString().padLeft(2, '0')}:'
      '${vietnam.minute.toString().padLeft(2, '0')}';
}

String _number(double value) =>
    value.toStringAsFixed(3).replaceFirst(RegExp(r'\.0+$'), '');

String _summaryNumber(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final integerPart = parts.first;
  final isNegative = integerPart.startsWith('-');
  final digits = isNegative ? integerPart.substring(1) : integerPart;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(digits[index]);
  }
  return '${isNegative ? '-' : ''}$grouped.${parts.last}';
}
