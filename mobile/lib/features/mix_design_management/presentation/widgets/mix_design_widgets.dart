import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/mix_design_models.dart';

class MixDesignOverviewCard extends StatelessWidget {
  const MixDesignOverviewCard({
    super.key,
    required this.page,
    required this.stationName,
  });

  final MixDesignPage page;
  final String stationName;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey<String>('mix-design-overview'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _OverviewMetric(
              icon: Icons.factory_outlined,
              label: 'Trạm đang xem',
              value: stationName,
              accent: AppColors.brandBlue,
            ),
            _OverviewMetric(
              icon: Icons.science_outlined,
              label: 'Tổng cấp phối',
              value: '${page.totalCount}',
              accent: AppColors.brandTeal,
            ),
            _OverviewMetric(
              icon: Icons.table_rows_outlined,
              label: 'Trang hiện tại',
              value: page.totalPages == 0
                  ? '0 / 0'
                  : '${page.pageNumber} / ${page.totalPages}',
              accent: const Color(0xFF7C3AED),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 156, maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MixDesignResultsTable extends StatefulWidget {
  const MixDesignResultsTable({super.key, required this.page});

  final MixDesignPage page;

  @override
  State<MixDesignResultsTable> createState() => _MixDesignResultsTableState();
}

class _MixDesignResultsTableState extends State<MixDesignResultsTable> {
  static const _indexWidth = 48.0;
  static const _minimumGradeWidth = 72.0;
  static const _minimumScrollableWidth = 120.0;
  static const _gradeCellHorizontalPadding = 18.0;
  static const _headerHeight = 50.0;
  static const _rowHeight = 54.0;
  static const _gradeTextStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );
  final _headerHorizontal = ScrollController();
  final _bodyHorizontal = ScrollController();
  bool _syncing = false;

  List<_MixDesignColumn> get _columns => <_MixDesignColumn>[
    for (final material in widget.page.materialColumns)
      _MixDesignColumn(
        material.materialName,
        96,
        (item) =>
            formatMixDesignNumber(item.quantityForColumn(material.columnKey)),
        material: true,
        tooltip: '${material.category} · cửa ${material.slotNumber}',
      ),
    _MixDesignColumn('Cường độ', 94, (item) => '${item.strength}'),
    _MixDesignColumn('Cốt liệu max', 108, (item) => '${item.maxAggregate}'),
    _MixDesignColumn('Độ sụt', 96, (item) => item.slump),
  ];

  @override
  void initState() {
    super.initState();
    _headerHorizontal.addListener(_syncHeaderToBody);
    _bodyHorizontal.addListener(_syncBodyToHeader);
  }

  @override
  void dispose() {
    _headerHorizontal.dispose();
    _bodyHorizontal.dispose();
    super.dispose();
  }

  void _syncHeaderToBody() =>
      _sync(source: _headerHorizontal, target: _bodyHorizontal);

  void _syncBodyToHeader() =>
      _sync(source: _bodyHorizontal, target: _headerHorizontal);

  void _sync({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_syncing || !target.hasClients) return;
    _syncing = true;
    target.jumpTo(source.offset.clamp(0.0, target.position.maxScrollExtent));
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    final dataWidth = columns.fold<double>(0, (sum, item) => sum + item.width);
    final rowCount = widget.page.items.isEmpty ? 1 : widget.page.items.length;
    final tableHeight = _headerHeight + 1 + rowCount * _rowHeight;
    return Semantics(
      container: true,
      label: 'Bảng danh sách cấp phối bê tông',
      child: Card(
        key: const ValueKey<String>('mix-design-results-table'),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gradeWidth = _calculateGradeWidth(
              context,
              constraints.maxWidth,
            );
            return SizedBox(
              height: tableHeight,
              child: Column(
                children: [
                  _buildHeader(columns, dataWidth, gradeWidth),
                  const Divider(height: 1),
                  Expanded(child: _buildBody(columns, dataWidth, gradeWidth)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _calculateGradeWidth(BuildContext context, double tableWidth) {
    final values = <String>[
      'Mác BT',
      ...widget.page.items.map((item) => item.displayConcreteGradeName),
    ];
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var longestTextWidth = 0.0;
    for (final value in values) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: _gradeTextStyle),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      longestTextWidth = math.max(longestTextWidth, painter.width);
    }

    final preferredWidth = longestTextWidth + _gradeCellHorizontalPadding;
    if (!tableWidth.isFinite) {
      return math.max(_minimumGradeWidth, preferredWidth);
    }
    final maximumWidth = math.max(
      _minimumGradeWidth,
      tableWidth - _indexWidth - _minimumScrollableWidth - 1,
    );
    return preferredWidth.clamp(_minimumGradeWidth, maximumWidth).toDouble();
  }

  Widget _buildHeader(
    List<_MixDesignColumn> columns,
    double dataWidth,
    double gradeWidth,
  ) {
    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: [
          _headerCell('STT', _indexWidth),
          _headerCell(
            'Mác BT',
            gradeWidth,
            key: const ValueKey<String>('mix-design-grade-header'),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey<String>('mix-design-table-header-scroll'),
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
                          material: column.material,
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

  Widget _buildBody(
    List<_MixDesignColumn> columns,
    double dataWidth,
    double gradeWidth,
  ) {
    final items = widget.page.items;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _indexWidth + gradeWidth,
          child: Column(
            children: items.isEmpty
                ? [
                    Row(
                      children: [
                        _cell('', _indexWidth, 0, alignment: Alignment.center),
                        _cell(
                          'Không có dữ liệu',
                          gradeWidth,
                          0,
                          alignment: Alignment.center,
                        ),
                      ],
                    ),
                  ]
                : [
                    for (var index = 0; index < items.length; index++)
                      Row(
                        children: [
                          _cell(
                            '${items[index].stt}',
                            _indexWidth,
                            index,
                            alignment: Alignment.center,
                          ),
                          _cell(
                            items[index].displayConcreteGradeName,
                            gradeWidth,
                            index,
                            alignment: Alignment.center,
                            emphasized: true,
                          ),
                        ],
                      ),
                  ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey<String>('mix-design-table-horizontal-scroll'),
            controller: _bodyHorizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: dataWidth,
              child: Column(
                children: items.isEmpty
                    ? [
                        Row(children: [_cell('', dataWidth, 0)]),
                      ]
                    : [
                        for (var index = 0; index < items.length; index++)
                          Row(
                            children: columns
                                .map(
                                  (column) => _cell(
                                    column.value(items[index]),
                                    column.width,
                                    index,
                                    alignment: Alignment.center,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                      ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(
    String label,
    double width, {
    Key? key,
    bool material = false,
    String? tooltip,
  }) {
    return Container(
      key: key,
      width: width,
      height: _headerHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: material
            ? AppColors.brandTeal.withValues(alpha: 0.1)
            : AppColors.brandBlue.withValues(alpha: 0.08),
        border: const Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Tooltip(
        message: tooltip ?? label,
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _cell(
    String value,
    double width,
    int rowIndex, {
    Alignment alignment = Alignment.centerLeft,
    bool emphasized = false,
  }) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: rowIndex.isEven ? Colors.white : const Color(0xFFFAFBFC),
        border: const Border(
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: emphasized ? AppColors.brandBlue : const Color(0xFF1F2937),
          fontSize: 12,
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}

class MixDesignPagination extends StatelessWidget {
  const MixDesignPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.canGoFirst,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.canGoLast,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
  });

  final int currentPage;
  final int totalPages;
  final bool canGoFirst;
  final bool canGoPrevious;
  final bool canGoNext;
  final bool canGoLast;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey<String>('mix-design-pagination'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey<String>('mix-design-page-first'),
              tooltip: 'Trang đầu',
              onPressed: canGoFirst ? onFirst : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              key: const ValueKey<String>('mix-design-page-previous'),
              tooltip: 'Trang trước',
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                totalPages == 0 ? '0 / 0' : '$currentPage / $totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              key: const ValueKey<String>('mix-design-page-next'),
              tooltip: 'Trang sau',
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              key: const ValueKey<String>('mix-design-page-last'),
              tooltip: 'Trang cuối',
              onPressed: canGoLast ? onLast : null,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
      ),
    );
  }
}

class _MixDesignColumn {
  const _MixDesignColumn(
    this.label,
    this.width,
    this.value, {
    this.material = false,
    this.tooltip,
  });

  final String label;
  final double width;
  final String Function(MixDesignItem item) value;
  final bool material;
  final String? tooltip;
}

String formatMixDesignNumber(num value) {
  var text = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  if (text.isEmpty || text == '-0') text = '0';
  return text.replaceAll('.', ',');
}
