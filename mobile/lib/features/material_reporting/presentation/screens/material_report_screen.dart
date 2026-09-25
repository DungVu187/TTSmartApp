import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';

import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/searchable_autocomplete_field.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/presentation/widgets/company_autocomplete_field.dart';
import '../../data/models/material_report_models.dart';
import '../../data/repositories/material_report_repository.dart';
import '../controllers/material_report_controller.dart';
import '../widgets/material_report_widgets.dart';

enum _ReportSection { overview, transactions }

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
  var _section = _ReportSection.overview;

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

  Future<void> _initialize() async {
    await _controller.initialize();
    // Phones have no "Tìm kiếm" button: the only station in scope is picked
    // and its report loads straight away.
    if (!mounted || !_isCompact || _controller.selectedStationId != null) {
      return;
    }
    if (_controller.stations.length == 1) {
      _controller.selectStation(_controller.stations.single.id);
      await _controller.loadReport();
    }
  }

  bool get _isCompact => MediaQuery.sizeOf(context).width < 600;

  int get _activeFilterCount => [
    _controller.materialGroup != MaterialGroupFilter.all,
    _controller.viewMode != MaterialViewMode.all,
    _controller.valueMode != MaterialValueMode.quantity,
  ].where((active) => active).length;

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
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconButton(
                  key: const ValueKey<String>('material-refresh'),
                  tooltip: 'Làm mới',
                  icon: LucideIcons.refreshCw,
                  onPressed:
                      _controller.report == null || _controller.isLoadingReport
                      ? null
                      : _controller.refresh,
                ),
                AppIconButton(
                  key: const ValueKey<String>('material-filters'),
                  tooltip: 'Bộ lọc',
                  icon: LucideIcons.slidersHorizontal,
                  badgeCount: _activeFilterCount,
                  onPressed: () => _showFilters(context),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) =>
              _isCompact ? _buildMobileBody(context) : _buildBody(context),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- mobile

  /// Phone layout (Figma C05/C06): date and station chips that reload on
  /// change, overview / transactions tabs, infinite transaction list.
  Widget _buildMobileBody(BuildContext context) {
    final controller = _controller;
    final report = controller.report;
    final p = context.palette;
    return InfiniteListView(
      storageKey: 'material-report-mobile-scroll',
      onLoadMore: () {
        if (_section == _ReportSection.transactions) {
          unawaited(controller.loadMore());
        }
      },
      onRefresh: report == null ? () async {} : controller.refresh,
      padding: const EdgeInsets.fromLTRB(kPagePadding, 4, kPagePadding, 28),
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
        if (controller.reportError != null && report == null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message: controller.reportError!.message,
            onRetry: controller.loadReport,
          ),
        ],
        const SizedBox(height: 12),
        if (report == null) ...[
          if (controller.isLoadingReport || controller.isLoadingScope)
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
          Text(
            'Tồn kho tính đến ${formatVietnamDateTime(report.inventoryAsOf)}',
            style: TextStyle(
              color: p.text3,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (report.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            WarningBanner(title: 'Dữ liệu cần lưu ý', items: report.warnings),
          ],
          const SizedBox(height: 14),
          SegmentedTabs<_ReportSection>(
            key: const ValueKey<String>('material-report-section'),
            segments: const [
              (_ReportSection.overview, 'Tổng quan'),
              (_ReportSection.transactions, 'Giao dịch'),
            ],
            selected: _section,
            onChanged: (selection) => setState(() => _section = selection),
          ),
          const SizedBox(height: 16),
          if (_section == _ReportSection.overview)
            _buildMobileOverview(report)
          else
            _buildMobileTransactions(report),
        ],
      ],
    );
  }

  Widget _buildMobileOverview(MaterialReport report) {
    final p = context.palette;
    final quantity = _controller.valueMode == MaterialValueMode.quantity;
    final totals = report.totals;
    String show(double value) =>
        quantity ? formatWeight(value) : formatCurrency(value);
    Widget total(IconData icon, AppTone tone, String label, double value) {
      final (fg, _) = p.tone(tone);
      return NavRow(
        leading: IconTile(icon: icon, tone: tone),
        title: label,
        showChevron: false,
        trailing: Text(
          show(value),
          style: TextStyle(
            color: value < 0 ? p.danger : fg,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsetCard(
          dividerIndent: kLeadingDividerIndent,
          children: [
            total(
              LucideIcons.arrowDownLeft,
              AppTone.success,
              quantity ? 'Tổng nhập' : 'Giá trị nhập',
              quantity ? totals.importQuantityKg : totals.importValueVnd,
            ),
            total(
              LucideIcons.arrowUpRight,
              AppTone.danger,
              quantity ? 'Tổng xuất' : 'Giá trị xuất',
              quantity ? totals.exportQuantityKg : totals.exportValueVnd,
            ),
            total(
              quantity ? LucideIcons.package : LucideIcons.wallet,
              AppTone.primary,
              quantity ? 'Tồn hiện tại' : 'Giá trị tồn',
              quantity ? totals.inventoryQuantityKg : totals.inventoryValueVnd,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'So sánh theo vật liệu',
          style: TextStyle(
            color: p.text1,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          quantity
              ? 'Khối lượng nhập, xuất và tồn lũy kế đến cuối kỳ.'
              : 'Giá trị FIFO nhập, xuất và tồn lũy kế đến cuối kỳ.',
          style: TextStyle(color: p.text2, fontSize: 13),
        ),
        const SizedBox(height: 10),
        MaterialComparisonList(
          items: report.chartItems,
          valueMode: _controller.valueMode,
        ),
      ],
    );
  }

  Widget _buildMobileTransactions(MaterialReport report) {
    final controller = _controller;
    if (controller.loadedTransactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: StateView(
          icon: LucideIcons.receiptText,
          title: 'Chưa có giao dịch',
          message:
              'Không tìm thấy giao dịch phù hợp với bộ lọc và khoảng thời gian.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel('${report.totalCount} giao dịch'),
        const SizedBox(height: 8),
        InsetCard(
          dividerIndent: kLeadingDividerIndent,
          children: [
            for (final transaction in controller.loadedTransactions)
              _TransactionRow(
                transaction: transaction,
                onTap: () =>
                    showMaterialTransactionDetails(context, transaction),
              ),
          ],
        ),
        LoadMoreFooter(
          loading: controller.isRefreshing,
          errorMessage: controller.reportError?.message,
          onRetry: controller.loadMore,
        ),
      ],
    );
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
                : 'Mã trạm ${station.id}',
          ),
      ],
    );
    final stationId = picked?.value;
    if (!mounted || stationId == null) return;
    _controller.selectStation(stationId);
    await _controller.loadReport();
  }

  Widget _buildBody(BuildContext context) {
    final report = _controller.report;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_section == _ReportSection.transactions &&
            notification.metrics.extentAfter < 300) {
          _controller.loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: report == null ? () async {} : _controller.refresh,
        child: ListView(
          key: const ValueKey<String>('material-report-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildScopeCard(context),
                    if (_controller.validationMessage != null) ...[
                      const SizedBox(height: 10),
                      ErrorPanel(message: _controller.validationMessage!),
                    ],
                    if (_controller.scopeError != null) ...[
                      const SizedBox(height: 10),
                      ErrorPanel(
                        message: _controller.scopeError!.message,
                        onRetry: _controller.retryScope,
                      ),
                    ],
                    if (_controller.reportError != null) ...[
                      const SizedBox(height: 10),
                      ErrorPanel(
                        message: _controller.reportError!.message,
                        onRetry: _controller.loadReport,
                      ),
                    ],
                    if (_controller.isLoadingReport && report == null) ...[
                      const SizedBox(height: 36),
                      const Center(child: CircularProgressIndicator()),
                    ] else if (report == null) ...[
                      const SizedBox(height: 20),
                      AppEmptyState(
                        icon: LucideIcons.package,
                        title: 'Chọn trạm để xem báo cáo',
                        message: widget.isAdmin
                            ? 'Chọn cụ thể công ty, trạm trộn và khoảng thời gian rồi bấm Xem báo cáo.'
                            : 'Chọn cụ thể trạm trộn và khoảng thời gian rồi bấm Xem báo cáo.',
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _buildReportHeader(report),
                      if (report.warnings.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _WarningsPanel(warnings: report.warnings),
                      ],
                      const SizedBox(height: 14),
                      SegmentedTabs<_ReportSection>(
                        key: const ValueKey<String>('material-report-section'),
                        segments: const [
                          (_ReportSection.overview, 'Tổng quan'),
                          (_ReportSection.transactions, 'Giao dịch'),
                        ],
                        selected: _section,
                        onChanged: (selection) => setState(() {
                          _section = selection;
                        }),
                      ),
                      const SizedBox(height: 14),
                      if (_section == _ReportSection.overview)
                        _buildOverview(report)
                      else
                        _buildTransactions(report),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Phạm vi báo cáo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (_controller.isLoadingScope)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.isAdmin) ...[
            CompanyAutocompleteField(
              key: ValueKey<String>(
                'material-company-${_controller.selectedCompanyId}',
              ),
              companies: _controller.companies,
              selectedCompanyId: _controller.selectedCompanyId,
              onSelected: (company) => _controller.selectCompany(company.id),
              onCleared: () => _controller.selectCompany(null),
              enabled: !_controller.isLoadingScope,
              hintText: 'Tìm theo tên hoặc mã công ty',
            ),
            const SizedBox(height: 12),
          ],
          SearchableAutocompleteField<MaterialReportStation>(
            key: ValueKey<String>(
              'material-station-${_controller.selectedCompanyId}-${_controller.selectedStationId}',
            ),
            options: _controller.stations,
            selectedOption: _controller.selectedStation,
            displayStringForOption: (station) => station.displayName,
            searchStringForOption: (station) {
              final company = station.companyName?.trim();
              return company == null || company.isEmpty
                  ? '${station.displayName} ${station.id}'
                  : '${station.displayName} ${station.id} $company';
            },
            optionSubtitle: (station) => station.companyName?.trim(),
            onSelected: (station) {
              final hadReport = _controller.report != null;
              _controller.selectStation(station.id);
              if (hadReport) _controller.loadReport();
            },
            onCleared: () => _controller.selectStation(null),
            enabled:
                !_controller.isLoadingScope &&
                (!widget.isAdmin || _controller.selectedCompanyId != null),
            hintText: 'Tìm trạm trộn',
            labelText: 'Trạm trộn',
            prefixIcon: LucideIcons.factory,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey<String>('material-date-range'),
            onPressed: () => _pickDateRange(context),
            icon: const Icon(LucideIcons.calendarRange),
            label: Text(_dateRangeLabel(_controller.from, _controller.to)),
          ),
          const SizedBox(height: 10),
          Material(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: const ValueKey<String>('material-filter-button'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showFilters(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.slidersHorizontal,
                      size: 20,
                      color: context.palette.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_controller.materialGroup.label} • ${_controller.viewMode.label} • ${_controller.valueMode.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      color: context.palette.text2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey<String>('material-view-report'),
            onPressed: _controller.isLoadingReport
                ? null
                : _controller.loadReport,
            icon: const Icon(LucideIcons.chartNoAxesColumnIncreasing),
            label: const Text('Tìm kiếm'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader(MaterialReport report) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.stationName?.trim().isNotEmpty == true
                    ? report.stationName!
                    : _controller.selectedStation?.displayName ?? 'Trạm trộn',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Tồn kho tính đến ${formatVietnamDateTime(report.inventoryAsOf)}',
                style: TextStyle(color: context.palette.text2, fontSize: 12),
              ),
            ],
          ),
        ),
        if (_controller.isRefreshing)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildOverview(MaterialReport report) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MaterialTotalsGrid(
        totals: report.totals,
        valueMode: _controller.valueMode,
      ),
      const SizedBox(height: 22),
      const Text(
        'So sánh theo vật liệu',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        _controller.valueMode == MaterialValueMode.quantity
            ? 'Khối lượng nhập, xuất và tồn lũy kế đến cuối kỳ.'
            : 'Giá trị FIFO nhập, xuất và tồn lũy kế đến cuối kỳ.',
        style: TextStyle(color: context.palette.text2, fontSize: 12),
      ),
      const SizedBox(height: 10),
      MaterialComparisonList(
        items: report.chartItems,
        valueMode: _controller.valueMode,
      ),
    ],
  );

  Widget _buildTransactions(MaterialReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          report.totalCount == 0
              ? 'Không có giao dịch trong kỳ'
              : 'Giao dịch ${report.fromRowNumber}–${report.toRowNumber} / ${report.totalCount}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (_controller.loadedTransactions.isEmpty)
          const AppEmptyState(
            icon: LucideIcons.receiptText,
            title: 'Chưa có giao dịch',
            message:
                'Không tìm thấy giao dịch phù hợp với bộ lọc và khoảng thời gian.',
          )
        else
          for (final transaction in _controller.loadedTransactions) ...[
            MaterialTransactionCard(
              transaction: transaction,
              onTap: () => showMaterialTransactionDetails(context, transaction),
            ),
            const SizedBox(height: 10),
          ],
        if (report.totalPages > 1 &&
            MediaQuery.sizeOf(context).width >= 600) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      report.pageNumber <= 1 || _controller.isLoadingReport
                      ? null
                      : () => _controller.loadReport(
                          pageNumber: report.pageNumber - 1,
                        ),
                  icon: const Icon(LucideIcons.chevronLeft),
                  label: const Text('Trang trước'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${report.pageNumber}/${report.totalPages}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      report.pageNumber >= report.totalPages ||
                          _controller.isLoadingReport
                      ? null
                      : () => _controller.loadReport(
                          pageNumber: report.pageNumber + 1,
                        ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(LucideIcons.chevronRight),
                  label: const Text('Trang sau'),
                ),
              ),
            ],
          ),
        ],
        if (MediaQuery.sizeOf(context).width < 600)
          LoadMoreFooter(
            loading: _controller.isRefreshing && _controller.canLoadMore,
            errorMessage: _controller.reportError?.message,
            onRetry: _controller.loadMore,
          ),
      ],
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final result = await showAppDateRangePicker(
      context: context,
      initialStart: _controller.from,
      initialEnd: _controller.to,
      title: 'Khoảng giao dịch',
      keyPrefix: 'material-date-range-picker',
    );
    if (result != null) {
      final shouldLoad = _shouldReloadOnChange;
      _controller.setDateRange(result.start, result.end);
      if (shouldLoad) await _controller.loadReport();
    }
  }

  /// Wide layouts keep the explicit "Tìm kiếm" flow until a report exists;
  /// phones reload as soon as a station is chosen.
  bool get _shouldReloadOnChange =>
      _controller.report != null || (_isCompact && _controller.canViewReport);

  Future<void> _showFilters(BuildContext context) async {
    var group = _controller.materialGroup;
    var view = _controller.viewMode;
    var value = _controller.valueMode;
    final applied = await showAppSheet<bool>(
      context: context,
      title: 'Bộ lọc báo cáo',
      footer: (sheetContext) => AppButton(
        key: const ValueKey<String>('material-apply-filters'),
        onPressed: () => Navigator.pop(sheetContext, true),
        icon: LucideIcons.check,
        label: 'Áp dụng bộ lọc',
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            const GroupLabel('Nhóm vật liệu'),
            const SizedBox(height: 8),
            OptionChipGroup<MaterialGroupFilter>(
              options: [
                for (final item in MaterialGroupFilter.values)
                  (item, item.label),
              ],
              selected: group,
              onChanged: (item) => setSheetState(() => group = item),
            ),
            const SizedBox(height: 18),
            const GroupLabel('Loại dữ liệu'),
            const SizedBox(height: 8),
            OptionChipGroup<MaterialViewMode>(
              options: [
                for (final item in MaterialViewMode.values) (item, item.label),
              ],
              selected: view,
              onChanged: (item) => setSheetState(() => view = item),
            ),
            const SizedBox(height: 18),
            const GroupLabel('Hiển thị theo'),
            const SizedBox(height: 8),
            SegmentedTabs<MaterialValueMode>(
              segments: [
                for (final item in MaterialValueMode.values) (item, item.label),
              ],
              selected: value,
              onChanged: (selection) => setSheetState(() => value = selection),
            ),
          ],
        ),
      ),
    );
    if (applied == true) {
      final shouldLoad = _shouldReloadOnChange;
      _controller
        ..setMaterialGroup(group)
        ..setViewMode(view)
        ..setValueMode(value);
      if (shouldLoad) await _controller.loadReport();
    }
  }
}

/// One stock movement in the phone list (Figma C06).
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, required this.onTap});

  final MaterialTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isImport = transaction.importQuantityKg > 0;
    final quantity = isImport
        ? transaction.importQuantityKg
        : transaction.exportQuantityKg;
    final tone = transaction.isSummary
        ? AppTone.primary
        : isImport
        ? AppTone.success
        : AppTone.danger;
    final (fg, _) = p.tone(tone);
    final occurredAt = transaction.occurredAt;
    return NavRow(
      background: transaction.isSummary ? p.primaryContainer : null,
      leading: IconTile(
        icon: transaction.isSummary
            ? LucideIcons.sigma
            : isImport
            ? LucideIcons.arrowDownLeft
            : LucideIcons.arrowUpRight,
        tone: tone,
        background: transaction.isSummary ? p.surface : null,
      ),
      title: transaction.content,
      titleMaxLines: 2,
      subtitle: occurredAt == null
          ? transaction.id
          : '${formatShortVietnamDateTime(occurredAt).replaceAll(' ', ' ')} · ${transaction.id}',
      subtitleMaxLines: 2,
      showChevron: false,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatWeight(quantity),
            semanticsLabel:
                '${isImport ? 'Nhập' : 'Xuất'} ${formatWeight(quantity)}',
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (transaction.valueVnd != null) ...[
            const SizedBox(height: 2),
            Text(
              formatCurrency(transaction.valueVnd!),
              style: TextStyle(
                color: p.text3,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

String _shortRange(DateTime start, DateTime end) {
  String two(int number) => number.toString().padLeft(2, '0');
  String date(DateTime value) => '${two(value.day)}/${two(value.month)}';
  return '${date(start)} – ${date(end)}';
}

class _WarningsPanel extends StatelessWidget {
  const _WarningsPanel({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.palette.warningBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: context.palette.warning.withValues(alpha: 0.35),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.triangleAlert, color: context.palette.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dữ liệu cần lưu ý',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '• $warning',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _dateRangeLabel(DateTime start, DateTime end) {
  String two(int number) => number.toString().padLeft(2, '0');
  String date(DateTime value) =>
      '${two(value.day)}/${two(value.month)}/${value.year}';
  return '${date(start)} – ${date(end)}';
}
