import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/material_report_models.dart';
import '../../data/repositories/material_report_repository.dart';
import '../controllers/material_report_controller.dart';
import '../widgets/material_report_widgets.dart';
import '../widgets/material_units.dart';

enum _Section { stock, chart, vouchers }

/// "Quản lý vật liệu" (Figma C05–C07), view only: the web page of the same
/// name with its stock per material door, the import / export / stock chart
/// and the vouchers with the "Xuất tổng" of the period.
class MaterialReportScreen extends StatefulWidget {
  const MaterialReportScreen({
    super.key,
    required this.repository,
    required this.companyRepository,
    required this.isAdmin,
  });

  final MaterialReportRepository repository;
  final CompanyRepository companyRepository;
  final bool isAdmin;

  @override
  State<MaterialReportScreen> createState() => _MaterialReportScreenState();
}

class _MaterialReportScreenState extends State<MaterialReportScreen> {
  late final MaterialReportController _controller;
  var _section = _Section.stock;

  @override
  void initState() {
    super.initState();
    _controller = MaterialReportController(
      repository: widget.repository,
      companyRepository: widget.companyRepository,
      isAdmin: widget.isAdmin,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  /// The only station in scope is picked and its report loads by itself.
  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted || _controller.selectedStationId != null) return;
    if (_controller.stations.length == 1) {
      _controller.selectStation(_controller.stations.single.id);
      await _controller.loadReport();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý vật liệu'),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => AppIconButton(
              key: const ValueKey<String>('material-refresh'),
              tooltip: 'Làm mới',
              icon: LucideIcons.refreshCw,
              onPressed:
                  _controller.report == null || _controller.isLoadingReport
                  ? null
                  : _controller.refresh,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = _controller;
    final report = controller.report;
    // Tablets keep the phone layout, centred at a readable width.
    final side = math.max(
      kPagePadding,
      (MediaQuery.sizeOf(context).width - 720) / 2,
    );
    return InfiniteListView(
      storageKey: 'material-report-scroll',
      onLoadMore: () {},
      onRefresh: report == null ? null : controller.refresh,
      padding: EdgeInsets.fromLTRB(side, 4, side, 32),
      children: [
        FilterChipBar(
          children: [
            if (widget.isAdmin)
              FilterChipButton(
                key: const ValueKey<String>('material-company'),
                icon: LucideIcons.building,
                label:
                    controller.selectedCompany?.displayName ?? 'Chọn công ty',
                showChevron: true,
                onTap: controller.isLoadingScope ? null : _pickCompany,
              ),
            FilterChipButton(
              key: const ValueKey<String>('material-date-range'),
              icon: LucideIcons.calendar,
              label: _shortRange(controller.from, controller.to),
              active: true,
              onTap: () => _pickDateRange(context),
            ),
            FilterChipButton(
              key: const ValueKey<String>('material-station'),
              icon: LucideIcons.factory,
              label:
                  controller.selectedStation?.displayName ?? 'Chọn trạm trộn',
              showChevron: true,
              onTap: controller.isLoadingScope ? null : _pickStation,
            ),
          ],
        ),
        if (controller.scopeError != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message: controller.scopeError!.message,
            onRetry: controller.retryScope,
          ),
        ],
        if (controller.validationMessage != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(message: controller.validationMessage!),
        ],
        if (controller.reportError != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message: controller.reportError!.message,
            onRetry: report == null
                ? controller.loadReport
                : controller.refresh,
          ),
        ],
        const SizedBox(height: 12),
        if (report == null) ...[
          if (controller.isLoadingReport)
            const MaterialLoadingCard()
          else if (controller.isLoadingScope)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.reportError == null)
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: StateView(
                icon: LucideIcons.package,
                title: 'Chọn trạm trộn',
                message: 'Chọn trạm trộn để xem nhập, xuất và tồn vật liệu.',
                actions: [
                  AppButton(
                    label: 'Chọn trạm trộn',
                    icon: LucideIcons.factory,
                    expand: false,
                    onPressed: _pickStation,
                  ),
                ],
              ),
            ),
        ] else ...[
          SegmentedTabs<_Section>(
            key: const ValueKey<String>('material-report-section'),
            segments: const [
              (_Section.stock, 'Tồn kho'),
              (_Section.chart, 'Biểu đồ'),
              (_Section.vouchers, 'Phiếu'),
            ],
            selected: _section,
            onChanged: (selection) => setState(() => _section = selection),
          ),
          if (controller.isRefreshing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: 14),
          ...switch (_section) {
            _Section.stock => _stockTab(report),
            _Section.chart => _chartTab(report),
            _Section.vouchers => _vouchersTab(report),
          },
        ],
      ],
    );
  }

  // ------------------------------------------------------------ Tồn kho

  List<Widget> _stockTab(MaterialReport report) {
    final controller = _controller;
    final valueMode = controller.valueMode == MaterialValueMode.value;
    final materials = controller.materials;
    final notice = negativeStockNotice(materials, valueMode: valueMode);
    final warnings = materialWarningsFor(report.warnings, valueMode: valueMode);
    final groups = report.groups.where((group) => group.materials.isNotEmpty);
    return [
      _AsOfLine(
        'Tồn lũy kế đến ${formatVietnamDateTime(report.inventoryAsOf)}',
      ),
      if (notice != null) ...[const SizedBox(height: 12), notice],
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 8),
        WarningBanner(title: 'Dữ liệu cần lưu ý', items: warnings),
      ],
      const SizedBox(height: 16),
      _LabeledSwitch<MaterialValueMode>(
        key: const ValueKey<String>('material-value-mode'),
        label: 'Xem theo',
        maxWidth: 240,
        segments: [
          for (final mode in MaterialValueMode.values) (mode, mode.label),
        ],
        selected: controller.valueMode,
        onChanged: controller.setValueMode,
      ),
      const SizedBox(height: 18),
      if (materials.isEmpty)
        const StateView(
          icon: LucideIcons.package,
          title: 'Chưa có cửa vật liệu',
          message: 'Trạm chưa khai báo cửa vật liệu nên chưa có tồn kho.',
        )
      else
        for (final group in groups) ...[
          MaterialStockGroup(
            key: ValueKey<String>('material-group-${group.code}'),
            group: group,
            unit: controller.unitFor(group.code),
            valueMode: valueMode,
            onUnitTap: () => _pickUnit(group.code),
            onMaterialTap: (item) => _openMaterial(report, item),
          ),
          const SizedBox(height: 18),
        ],
    ];
  }

  // ------------------------------------------------------------ Biểu đồ

  List<Widget> _chartTab(MaterialReport report) {
    final controller = _controller;
    final p = context.palette;
    final group = controller.chartGroup;
    final items = controller.materials
        .where(
          (item) =>
              group == MaterialGroupFilter.all || item.groupCode == group.code,
        )
        .toList(growable: false);
    return [
      MaterialInlineSelect(
        key: const ValueKey<String>('material-chart-group'),
        label: 'Nhóm vật liệu',
        value: group.label,
        onTap: () async {
          final picked = await _pickGroup(group);
          if (picked != null) controller.setChartGroup(picked);
        },
      ),
      const SizedBox(height: 18),
      Text(
        'Nhập – xuất – tồn theo vật liệu',
        style: TextStyle(
          color: p.text1,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        'Lũy kế đến ${formatVietnamDateTime(report.inventoryAsOf)} · '
        'lớn nhất xếp trước',
        style: TextStyle(color: p.text2, fontSize: 13, height: 18 / 13),
      ),
      const SizedBox(height: 10),
      const MaterialChartLegend(),
      const SizedBox(height: 10),
      if (items.isEmpty)
        const StateView(
          icon: LucideIcons.chartColumn,
          title: 'Không có vật liệu trong nhóm',
          message: 'Chọn nhóm khác để xem biểu đồ.',
        )
      else
        MaterialChartList(
          items: items,
          onTap: (item) => _openMaterial(report, item),
        ),
    ];
  }

  // ------------------------------------------------------------ Phiếu

  List<Widget> _vouchersTab(MaterialReport report) {
    final controller = _controller;
    final summary = _summaryFor(controller.voucherGroup);
    return [
      _LabeledSwitch<MaterialViewMode>(
        key: const ValueKey<String>('material-voucher-type'),
        label: 'Loại',
        segments: const [
          (MaterialViewMode.all, 'Tất cả'),
          (MaterialViewMode.importData, 'Nhập'),
          (MaterialViewMode.exportData, 'Xuất'),
          (MaterialViewMode.stocktake, 'Kiểm kê'),
        ],
        selected: controller.voucherType,
        onChanged: (type) => controller.setVoucherFilters(type: type),
      ),
      const SizedBox(height: 10),
      MaterialInlineSelect(
        key: const ValueKey<String>('material-voucher-group'),
        label: 'Nhóm vật liệu',
        value: controller.voucherGroup.label,
        onTap: () async {
          final picked = await _pickGroup(controller.voucherGroup);
          if (picked != null) {
            await controller.setVoucherFilters(group: picked);
          }
        },
      ),
      const SizedBox(height: 16),
      _AsOfLine(
        'Phiếu từ ${formatShortVietnamDateTime(report.from)} đến '
        '${formatShortVietnamDateTime(report.to)}',
      ),
      const SizedBox(height: 12),
      if (summary != null) ...[
        MaterialSummaryExportCard(
          key: const ValueKey<String>('material-summary-export'),
          summary: summary,
          onTap: () => showMaterialTransactionDetails(context, summary),
        ),
        const SizedBox(height: 18),
      ],
      if (controller.isLoadingVouchers)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (controller.voucherError != null && controller.vouchers.isEmpty)
        ErrorBanner(
          message: controller.voucherError!.message,
          onRetry: () => controller.setVoucherFilters(),
        )
      else if (controller.vouchers.isEmpty)
        const _VouchersEmpty()
      else ...[
        GroupLabel('${controller.voucherCount} phiếu'),
        const SizedBox(height: 8),
        InsetCard(
          dividerIndent: kLeadingDividerIndent,
          children: [
            for (final voucher in controller.vouchers)
              MaterialVoucherRow(
                voucher: voucher,
                onTap: () => showMaterialTransactionDetails(context, voucher),
              ),
          ],
        ),
        if (controller.voucherError != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message: controller.voucherError!.message,
            onRetry: controller.loadMoreVouchers,
          ),
        ] else if (controller.canLoadMoreVouchers ||
            controller.isLoadingMoreVouchers) ...[
          const SizedBox(height: 14),
          AppButton(
            key: const ValueKey<String>('material-more-vouchers'),
            label: 'Xem thêm phiếu',
            variant: AppButtonVariant.outline,
            loading: controller.isLoadingMoreVouchers,
            onPressed: controller.isLoadingMoreVouchers
                ? null
                : controller.loadMoreVouchers,
          ),
        ],
      ],
    ];
  }

  /// "Xuất tổng trong kỳ" of the overview, limited to a group when one is
  /// picked (the API only sends it for all materials and all types).
  MaterialTransaction? _summaryFor(MaterialGroupFilter group) {
    final summary = _controller.summaryExport;
    if (summary == null || _controller.voucherType != MaterialViewMode.all) {
      return null;
    }
    if (group == MaterialGroupFilter.all) return summary;
    final codes = {
      for (final item in _controller.materials)
        if (item.groupCode == group.code) item.materialCode,
    };
    final details = summary.details
        .where((detail) => codes.contains(detail.materialCode))
        .toList(growable: false);
    return MaterialTransaction(
      rowNumber: summary.rowNumber,
      id: summary.id,
      occurredAt: summary.occurredAt,
      periodFrom: summary.periodFrom,
      periodTo: summary.periodTo,
      type: summary.type,
      content: summary.content,
      importQuantityKg: 0,
      exportQuantityKg: details.fold(0, (sum, item) => sum + item.quantityKg),
      valueVnd: details.fold<double>(
        0,
        (sum, item) => sum + (item.valueVnd ?? 0),
      ),
      note: summary.note,
      details: details,
    );
  }

  // ------------------------------------------------------------ actions

  void _openMaterial(MaterialReport report, MaterialSummaryItem item) {
    final summary = _controller.summaryExport;
    final detail = summary?.details
        .where((detail) => detail.materialCode == item.materialCode)
        .firstOrNull;
    showMaterialDetails(
      context,
      item: item,
      unit: _controller.unitFor(item.groupCode),
      inventoryAsOf: report.inventoryAsOf,
      periodLabel: _shortRange(_controller.from, _controller.to),
      // A material missing from the summary had no export in the period.
      periodExportKg: summary == null ? null : detail?.quantityKg ?? 0,
    );
  }

  Future<void> _pickUnit(String groupCode) async {
    final picked = await showPickerSheet<MaterialUnit>(
      context: context,
      title: 'Đơn vị nhóm ${materialGroupName(groupCode)}',
      icon: LucideIcons.scale,
      selected: _controller.unitFor(groupCode),
      options: [
        for (final unit in materialUnitsFor(groupCode))
          PickerOption(
            value: unit,
            title: unit.label,
            subtitle: unit.description,
          ),
      ],
    );
    final unit = picked?.value;
    if (unit != null) _controller.setUnit(groupCode, unit);
  }

  Future<MaterialGroupFilter?> _pickGroup(MaterialGroupFilter selected) async {
    final picked = await showPickerSheet<MaterialGroupFilter>(
      context: context,
      title: 'Nhóm vật liệu',
      icon: LucideIcons.layers,
      selected: selected,
      options: [
        for (final group in MaterialGroupFilter.values)
          PickerOption(value: group, title: group.label),
      ],
    );
    return picked?.value;
  }

  Future<void> _pickCompany() async {
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn công ty',
      searchHint: 'Tìm công ty',
      icon: LucideIcons.building,
      selected: _controller.selectedCompanyId,
      options: [
        for (final company in _controller.companies)
          PickerOption(value: company.id, title: company.displayName),
      ],
    );
    if (!mounted || picked == null) return;
    await _controller.selectCompany(picked.value);
  }

  Future<void> _pickStation() async {
    if (widget.isAdmin && _controller.selectedCompanyId == null) {
      await _pickCompany();
      if (!mounted || _controller.selectedCompanyId == null) return;
    }
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn trạm trộn',
      searchHint: 'Tìm trạm trộn',
      icon: LucideIcons.factory,
      selected: _controller.selectedStationId,
      emptyMessage: 'Không có trạm trộn trong phạm vi được cấp.',
      options: [
        for (final station in _controller.stations)
          PickerOption(
            value: station.id,
            title: station.displayName,
            subtitle: station.companyName?.trim().isNotEmpty == true
                ? station.companyName
                : null,
          ),
      ],
    );
    final stationId = picked?.value;
    if (!mounted || stationId == null) return;
    _controller.selectStation(stationId);
    await _controller.loadReport();
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final result = await showAppDateRangePicker(
      context: context,
      initialStart: _controller.from,
      initialEnd: _controller.to,
      title: 'Khoảng thời gian',
      keyPrefix: 'material-date-range-picker',
    );
    if (result == null) return;
    _controller.setDateRange(result.start, result.end);
    if (_controller.canViewReport) unawaited(_controller.loadReport());
  }
}

/// A short label and a compact switch, so it never reads as a second row
/// of tabs under "Tồn kho · Biểu đồ · Phiếu".
class _LabeledSwitch<T> extends StatelessWidget {
  const _LabeledSwitch({
    super.key,
    required this.label,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.maxWidth = double.infinity,
  });

  final String label;
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: p.text2,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SegmentedTabs<T>(
              segments: segments,
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// "ⓘ Tồn lũy kế đến …": says which moment the numbers are for.
class _AsOfLine extends StatelessWidget {
  const _AsOfLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(LucideIcons.info, size: 15, color: p.text2),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: p.text2,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Figma C07c: no voucher in the period.
class _VouchersEmpty extends StatelessWidget {
  const _VouchersEmpty();

  @override
  Widget build(BuildContext context) => const StateView(
    icon: LucideIcons.clipboardList,
    title: 'Không có phiếu nhập, xuất hay kiểm kê trong kỳ',
    message:
        'Phiếu kho được tạo trên web Quản lý kho. Thử chọn khoảng ngày dài hơn.',
  );
}

String _shortRange(DateTime start, DateTime end) {
  String two(int number) => number.toString().padLeft(2, '0');
  String date(DateTime value) => '${two(value.day)}/${two(value.month)}';
  return '${date(start)} – ${date(end)}';
}
