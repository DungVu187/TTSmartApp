import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/searchable_autocomplete_field.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/presentation/widgets/company_autocomplete_field.dart';
import '../../data/models/report_models.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/services/report_export_file_saver.dart';
import '../controllers/reports_controller.dart';
import '../widgets/statistics_tables.dart';
import 'mix_batch_detail_screen.dart';
import 'statistics_summary_screen.dart';

abstract final class _StatisticsDesign {
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFFEFF6FF);
  static const border = Color(0xFFE5E7EB);
  static const fieldBorder = Color(0xFFCBD5E1);
  static const fieldBorderWidth = 1.25;
  static const background = Color(0xFFF8FAFC);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const label = Color(0xFF374151);
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.repository,
    required this.companyRepository,
    this.showHeading = true,
    this.now,
    this.exportFileSaver,
  });

  final ReportsRepository repository;
  final CompanyRepository companyRepository;
  final bool showHeading;
  final DateTime Function()? now;
  final ReportExportFileSaver? exportFileSaver;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late ReportsController _controller;
  bool _ready = false;
  bool _canExport = false;
  int _lastFeedbackVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final app = AppScope.of(context);
    _canExport = app.hasPermission(
      AccessFunctionCodes.orderStatistics,
      AccessPermission.exportData,
    );
    _controller = ReportsController(
      repository: widget.repository,
      companyRepository: widget.companyRepository,
      now: widget.now,
      exportFileSaver: widget.exportFileSaver,
    );
    _ready = true;
    unawaited(
      _initialize(
        isAdmin: app.hasRole('ADMIN'),
        initialCompanyId: app.session?.user.companyId,
      ),
    );
  }

  Future<void> _initialize({
    required bool isAdmin,
    int? initialCompanyId,
  }) async {
    await _controller.initialize(
      isAdmin: isAdmin,
      initialCompanyId: initialCompanyId,
    );
    // Phones have no Search button: the only station in scope loads at once.
    if (!mounted || !_isCompact || _controller.selectedStationId != null) {
      return;
    }
    if (_controller.stations.length == 1) {
      await _applyStation(_controller.stations.single.id);
    }
  }

  bool get _isCompact => MediaQuery.sizeOf(context).width < 600;

  int get _extraFilterCount => [
    _controller.selectedVehiclePlate,
    _controller.selectedCustomerName,
    _controller.selectedConcreteGradeName,
    _controller.selectedEmployeeName,
  ].where((value) => value != null).length;

  @override
  void dispose() {
    if (_ready) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        _showFeedbackIfNeeded();
        if (_isCompact) {
          return Column(
            children: [
              SafeArea(
                bottom: false,
                child: TabTitleBar(
                  title: 'Thống kê đơn hàng',
                  actions: [
                    RoundIconButton(
                      key: const ValueKey<String>('statistics-extra-filters'),
                      icon: Icons.tune_rounded,
                      tooltip: 'Lọc thêm',
                      badgeCount: _extraFilterCount,
                      onPressed: _openExtraFilters,
                    ),
                    if (_canExport)
                      RoundIconButton(
                        key: const ValueKey<String>('statistics-export'),
                        icon: Icons.file_download_outlined,
                        tooltip: 'Xuất Excel',
                        loading: _controller.isExporting,
                        onPressed: _controller.exportExcel,
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildMobileBody()),
            ],
          );
        }
        final wide = ColoredBox(
          color: _StatisticsDesign.background,
          child: ListView(
            key: const PageStorageKey<String>('statistics-scroll'),
            padding: EdgeInsets.zero,
            children: [
              AppContent(
                horizontalPadding: 12,
                topPadding: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showHeading) ...[
                      _statisticsHeader(context),
                      const SizedBox(height: 12),
                    ],
                    _buildViewMode(context),
                    const SizedBox(height: 12),
                    _buildFilters(context),
                    if (_controller.isLoadingScope ||
                        _controller.isLoadingOptions) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_controller.scopeErrorMessage != null) ...[
                      const SizedBox(height: 12),
                      ErrorPanel(
                        message: _controller.scopeErrorMessage!,
                        onRetry: _controller.retryScope,
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (_controller.isSearching) ...[
                      const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 12),
                    ],
                    if (_controller.resultErrorMessage != null) ...[
                      ErrorPanel(
                        message: _controller.resultErrorMessage!,
                        onRetry: _controller.retryResult,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_controller.result == null && _controller.isSearching)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 56),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_controller.result == null)
                      const Card(
                        child: AppEmptyState(
                          icon: Icons.search_outlined,
                          title: 'Chưa có dữ liệu thống kê',
                          message:
                              'Chọn bộ lọc rồi bấm Tìm kiếm để tải dữ liệu.',
                        ),
                      )
                    else ...[
                      StatisticsResultsTable(page: _controller.result!),
                      const SizedBox(height: 12),
                      _buildPagination(context),
                      const SizedBox(height: 18),
                      const Text(
                        'Thống kê tổng',
                        key: ValueKey<String>('statistics-summary-title'),
                        style: TextStyle(
                          color: _StatisticsDesign.textPrimary,
                          fontSize: 17,
                          height: 22 / 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StatisticsMaterialSummaryTable(page: _controller.result!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
        if (widget.showHeading) return wide;
        return Column(
          children: [
            const SafeArea(
              bottom: false,
              child: TabTitleBar(title: 'Thống kê đơn hàng'),
            ),
            Expanded(child: wide),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- mobile

  /// Phone layout (Figma C01): view tabs, scope chips that search on
  /// change, totals and the infinite batch list.
  Widget _buildMobileBody() {
    final controller = _controller;
    final result = controller.result;
    return InfiniteListView(
      storageKey: 'statistics-mobile-scroll',
      onLoadMore: () => unawaited(controller.loadMore()),
      onRefresh: result == null ? () async {} : controller.search,
      padding: const EdgeInsets.fromLTRB(kPagePadding, 4, kPagePadding, 28),
      children: [
        SegmentedTabs<ReportViewMode>(
          key: const ValueKey<String>('statistics-view-mode'),
          segments: const [
            (ReportViewMode.detail, 'Chi tiết'),
            (ReportViewMode.total, 'Tổng hợp'),
          ],
          selected: controller.viewMode,
          onChanged: _setViewMode,
        ),
        const SizedBox(height: 9),
        FilterChipBar(
          children: [
            if (controller.isAdmin)
              FilterChipButton(
                key: const ValueKey<String>('statistics-company'),
                icon: Icons.apartment_outlined,
                label:
                    controller.selectedCompany?.displayName ?? 'Chọn công ty',
                showChevron: true,
                onTap: controller.isLoadingScope ? null : _pickCompany,
              ),
            FilterChipButton(
              key: const ValueKey<String>('statistics-date-range'),
              icon: Icons.calendar_month_outlined,
              label: _shortRange(controller.fromDate, controller.toDate),
              active: true,
              onTap: () => _pickDateRange(context),
            ),
            FilterChipButton(
              key: const ValueKey<String>('statistics-station'),
              icon: Icons.factory_outlined,
              label: controller.selectedStation?.displayName ?? 'Chọn trạm',
              showChevron: true,
              onTap: controller.isLoadingScope ? null : _pickStation,
            ),
          ],
        ),
        if (controller.scopeErrorMessage != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message: controller.scopeErrorMessage!,
            onRetry: controller.retryScope,
          ),
        ],
        const SizedBox(height: 14),
        if (result == null) ...[
          if (controller.isSearching || controller.isLoadingScope)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.resultErrorMessage != null)
            ErrorBanner(
              message: controller.resultErrorMessage!,
              onRetry: controller.retryResult,
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: StateView(
                icon: Icons.query_stats_outlined,
                title: 'Chọn trạm',
                message: 'Chọn trạm và khoảng thời gian để xem các mẻ trộn.',
                actions: [
                  AppButton(
                    label: 'Chọn trạm',
                    icon: Icons.factory_outlined,
                    expand: false,
                    onPressed: _pickStation,
                  ),
                ],
              ),
            ),
        ] else
          ..._mobileResults(result),
      ],
    );
  }

  List<Widget> _mobileResults(OrderStatisticsPage page) {
    final controller = _controller;
    final p = context.palette;
    return [
      StatRow(
        children: [
          StatTile(
            label: 'Tổng bê tông',
            value: formatStatisticsTotal(page.totalConcreteVolume, digits: 3),
            unit: 'm³',
            valueColor: p.success,
          ),
          StatTile(
            key: const ValueKey<String>('statistics-summary-tile'),
            label: 'Tổng vật liệu',
            value: formatStatisticsTotal(page.totalMaterialQuantity),
            unit: 'kg',
            onTap: () => _openSummary(page),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (controller.loadedItems.isEmpty)
        const StateView(
          icon: Icons.query_stats_outlined,
          title: 'Chưa có mẻ trộn',
          message: 'Thử đổi khoảng thời gian hoặc bộ lọc.',
        )
      else ...[
        GroupLabel(
          controller.viewMode == ReportViewMode.detail
              ? '${page.totalCount} mẻ trộn'
              : '${page.totalCount} dòng tổng hợp',
        ),
        const SizedBox(height: 8),
        InsetCard(
          dividerIndent: 69,
          children: [
            for (final item in controller.loadedItems)
              _BatchRow(
                item: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MixBatchDetailScreen(item: item),
                  ),
                ),
              ),
          ],
        ),
        LoadMoreFooter(
          loading: controller.isSearching,
          errorMessage: controller.resultErrorMessage,
          onRetry: controller.retryResult,
        ),
      ],
    ];
  }

  void _openSummary(OrderStatisticsPage page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatisticsSummaryScreen(
          page: page,
          stationName:
              _controller.selectedStation?.displayName ?? 'Trạm đã chọn',
          rangeLabel: _dateRangeLabel(_controller.fromDate, _controller.toDate),
        ),
      ),
    );
  }

  void _setViewMode(ReportViewMode mode) {
    _controller.setViewMode(mode);
    if (_controller.selectedStationId != null) unawaited(_controller.search());
  }

  /// Station change searches immediately; filter options load in parallel.
  Future<void> _applyStation(int stationId) async {
    final optionsLoad = _controller.selectStation(stationId);
    await _controller.search();
    await optionsLoad;
  }

  Future<void> _pickCompany() async {
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn công ty',
      searchHint: 'Tìm công ty',
      icon: Icons.apartment_outlined,
      selected: _controller.selectedCompanyId,
      options: [
        for (final company in _controller.companies)
          PickerOption(
            value: company.id,
            title: company.displayName,
            subtitle: company.code,
          ),
      ],
    );
    if (!mounted || picked == null) return;
    await _controller.selectCompany(picked.value);
    if (mounted && _controller.stations.length == 1) {
      await _applyStation(_controller.stations.single.id);
    }
  }

  Future<void> _pickStation() async {
    if (_controller.isAdmin && _controller.selectedCompanyId == null) {
      await _pickCompany();
      if (!mounted || _controller.selectedCompanyId == null) return;
      if (_controller.selectedStationId != null) return;
    }
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn trạm',
      searchHint: 'Tìm trạm',
      icon: Icons.factory_outlined,
      selected: _controller.selectedStationId,
      emptyMessage: 'Không có trạm trong phạm vi được cấp.',
      options: [
        for (final station in _controller.stations)
          PickerOption(
            value: station.id,
            title: station.displayName,
            subtitle: station.companyName,
          ),
      ],
    );
    final stationId = picked?.value;
    if (!mounted || stationId == null) return;
    await _applyStation(stationId);
  }

  Future<void> _openExtraFilters() async {
    if (_controller.selectedStationId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Chọn trạm trước khi lọc thêm.')),
        );
      return;
    }
    final draft = await showAppModalSheet<_ExtraFiltersDraft>(
      context: context,
      builder: (_) => _ExtraFiltersSheet(
        controller: _controller,
        initial: _ExtraFiltersDraft.fromController(_controller),
      ),
    );
    if (!mounted || draft == null) return;
    _controller
      ..setVehiclePlate(draft.vehiclePlate)
      ..setCustomerName(draft.customerName)
      ..setConcreteGradeName(draft.concreteGradeName)
      ..setEmployeeName(draft.employeeName);
    await _controller.search();
  }

  Widget _statisticsHeader(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Thống kê đơn hàng',
        style: TextStyle(
          color: _StatisticsDesign.textPrimary,
          fontSize: 19,
          height: 24 / 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        'Tra cứu chi tiết và tổng hợp các mẻ trộn',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _StatisticsDesign.textSecondary,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );

  Widget _buildViewMode(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SizedBox(
      width: 276,
      height: 40,
      child: SegmentedButton<ReportViewMode>(
        key: const ValueKey<String>('statistics-view-mode'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<ReportViewMode>(
            value: ReportViewMode.detail,
            label: Text('Chi tiết'),
            icon: Icon(Icons.check, size: 16),
          ),
          ButtonSegment<ReportViewMode>(
            value: ReportViewMode.total,
            label: Text('Tổng hợp'),
            icon: Icon(Icons.description_outlined, size: 16),
          ),
        ],
        selected: <ReportViewMode>{_controller.viewMode},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) _controller.setViewMode(selection.first);
        },
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: _StatisticsDesign.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _StatisticsDesign.lightBlue
                : Colors.white,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _StatisticsDesign.blue
                : _StatisticsDesign.textPrimary,
          ),
          overlayColor: const WidgetStatePropertyAll(
            _StatisticsDesign.lightBlue,
          ),
        ),
      ),
    ),
  );

  Widget _buildFilters(BuildContext context) {
    return Card(
      key: const ValueKey<String>('statistics-filters'),
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _StatisticsDesign.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final fields = <Widget>[
              if (_controller.isAdmin) _companyField(),
              _stationField(),
              _dateRangeField(context),
              _optionalAutocomplete(
                keyName: 'statistics-vehicle',
                label: 'Xe',
                icon: Icons.local_shipping_outlined,
                values: _controller.filterOptions.vehiclePlates,
                value: _controller.selectedVehiclePlate,
                onChanged: _controller.setVehiclePlate,
              ),
              _optionalAutocomplete(
                keyName: 'statistics-customer',
                label: 'Khách hàng',
                icon: Icons.person_outline,
                values: _controller.filterOptions.customerNames,
                value: _controller.selectedCustomerName,
                onChanged: _controller.setCustomerName,
              ),
              _optionalAutocomplete(
                keyName: 'statistics-grade',
                label: 'Mác bê tông',
                icon: Icons.view_in_ar_outlined,
                values: _controller.filterOptions.concreteGradeNames,
                value: _controller.selectedConcreteGradeName,
                onChanged: _controller.setConcreteGradeName,
              ),
              _optionalAutocomplete(
                keyName: 'statistics-employee',
                label: 'Nhân viên',
                icon: Icons.badge_outlined,
                values: _controller.filterOptions.employeeNames,
                value: _controller.selectedEmployeeName,
                onChanged: _controller.setEmployeeName,
              ),
            ];
            final children = <Widget>[];
            for (var index = 0; index < fields.length; index++) {
              if (index > 0) children.add(const SizedBox(height: 8));
              children.add(fields[index]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  _wideFilterRows(fields)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                const SizedBox(height: 10),
                _filterActions(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _wideFilterRows(List<Widget> fields) {
    final rows = <Widget>[];
    for (var index = 0; index < fields.length; index += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(
        Row(
          children: [
            Expanded(child: fields[index]),
            const SizedBox(width: 8),
            Expanded(
              child: index + 1 < fields.length
                  ? fields[index + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _companyField() => SizedBox(
    height: 38,
    child: CompanyAutocompleteField(
      key: ValueKey<String>(
        'statistics-company-${_controller.selectedCompanyId}-${_controller.companies.length}',
      ),
      companies: _controller.companies,
      selectedCompanyId: _controller.selectedCompanyId,
      enabled: !_controller.isLoadingScope,
      hintText: 'Chọn công ty',
      labelText: 'Công ty',
      compact: true,
      borderColor: _StatisticsDesign.fieldBorder,
      borderWidth: _StatisticsDesign.fieldBorderWidth,
      onSelected: (company) => _controller.selectCompany(company.id),
      onCleared: () => _controller.selectCompany(null),
    ),
  );

  Widget _stationField() => SizedBox(
    height: 38,
    child: SearchableAutocompleteField<OrderStatisticsStation>(
      key: ValueKey<String>(
        'statistics-station-${_controller.selectedStationId}-${_controller.stations.length}',
      ),
      options: _controller.stations,
      selectedOption: _controller.selectedStation,
      displayStringForOption: (station) => station.displayName,
      searchStringForOption: (station) => station.displayName,
      optionSubtitle: (station) => station.companyName?.trim(),
      onSelected: (station) => _controller.selectStation(station.id),
      onCleared: () => _controller.selectStation(null),
      enabled: !_controller.isLoadingScope && _controller.stations.isNotEmpty,
      loading: _controller.isLoadingScope,
      hintText: _controller.stations.isEmpty ? 'Không có dữ liệu' : 'Chọn trạm',
      labelText: 'Trạm',
      prefixIcon: Icons.factory_outlined,
      compact: true,
      borderColor: _StatisticsDesign.fieldBorder,
      borderWidth: _StatisticsDesign.fieldBorderWidth,
    ),
  );

  Widget _optionalAutocomplete({
    required String keyName,
    required String label,
    required IconData icon,
    required List<String> values,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) => SizedBox(
    height: 38,
    child: SearchableAutocompleteField<String>(
      key: ValueKey<String>('$keyName-${value ?? ''}-${values.length}'),
      options: values,
      selectedOption: values.contains(value) ? value : null,
      displayStringForOption: (item) => item,
      onSelected: onChanged,
      onCleared: () => onChanged(null),
      enabled: values.isNotEmpty && !_controller.isLoadingOptions,
      loading: _controller.isLoadingOptions,
      hintText: values.isEmpty ? 'Không có dữ liệu' : 'Tất cả',
      labelText: label,
      prefixIcon: icon,
      compact: true,
      borderColor: _StatisticsDesign.fieldBorder,
      borderWidth: _StatisticsDesign.fieldBorderWidth,
    ),
  );

  InputDecoration _compactDecoration({
    required String label,
    required IconData icon,
  }) => InputDecoration(
    labelText: label,
    isDense: true,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
    prefixIcon: Icon(icon, size: 16),
    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 38),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: _StatisticsDesign.fieldBorder,
        width: _StatisticsDesign.fieldBorderWidth,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: _StatisticsDesign.fieldBorder,
        width: _StatisticsDesign.fieldBorderWidth,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _StatisticsDesign.blue, width: 1.5),
    ),
    hintStyle: const TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400,
    ),
    labelStyle: const TextStyle(
      color: _StatisticsDesign.label,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      color: _StatisticsDesign.label,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _dateRangeField(BuildContext context) => SizedBox(
    height: 38,
    child: Semantics(
      button: true,
      label: 'Chọn khoảng thời gian thống kê',
      child: InkWell(
        key: const ValueKey<String>('statistics-date-range'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pickDateRange(context),
        child: InputDecorator(
          decoration: _compactDecoration(
            label: 'Thời gian',
            icon: Icons.calendar_month_outlined,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatDateTime(_controller.fromDate)} - '
                  '${_formatDateTime(_controller.toDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _StatisticsDesign.textPrimary,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _filterActions(BuildContext _) {
    final searchButton = SizedBox(
      height: 38,
      child: FilledButton.icon(
        key: const ValueKey<String>('statistics-search'),
        onPressed: _controller.isSearching ? null : _controller.search,
        style: FilledButton.styleFrom(
          backgroundColor: _StatisticsDesign.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: _controller.isSearching
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.search, size: 16),
        label: const Text('Tìm kiếm'),
      ),
    );
    final resetButton = SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        key: const ValueKey<String>('statistics-reset'),
        onPressed: _controller.isSearching ? null : _controller.resetFilters,
        style: OutlinedButton.styleFrom(
          foregroundColor: _StatisticsDesign.blue,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: _StatisticsDesign.border),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Đặt lại'),
      ),
    );
    final exportButton = SizedBox(
      height: 38,
      child: FilledButton.tonalIcon(
        key: const ValueKey<String>('statistics-export'),
        onPressed: _controller.isExporting ? null : _controller.exportExcel,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(38),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: _controller.isExporting
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_download_outlined, size: 17),
        label: const Text('Xuất Excel'),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(flex: 5, child: searchButton),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: resetButton),
          ],
        ),
        if (_canExport) ...[const SizedBox(height: 8), exportButton],
      ],
    );
  }

  Widget _buildPagination(BuildContext context) {
    final current = _controller.currentPage;
    final total = _controller.totalPages;
    return Card(
      key: const ValueKey<String>('statistics-pagination'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey<String>('statistics-page-first'),
              tooltip: 'Trang đầu',
              onPressed: _controller.canGoFirst
                  ? _controller.goToFirstPage
                  : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              key: const ValueKey<String>('statistics-page-previous'),
              tooltip: 'Trang trước',
              onPressed: _controller.canGoPrevious
                  ? _controller.goToPreviousPage
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                total == 0 ? '0/0' : '$current/$total',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              key: const ValueKey<String>('statistics-page-next'),
              tooltip: 'Trang sau',
              onPressed: _controller.canGoNext
                  ? _controller.goToNextPage
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              key: const ValueKey<String>('statistics-page-last'),
              tooltip: 'Trang cuối',
              onPressed: _controller.canGoLast
                  ? _controller.goToLastPage
                  : null,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final selection = await showAppDateRangePicker(
      context: context,
      initialStart: _controller.fromDate,
      initialEnd: _controller.toDate,
      now: widget.now?.call() ?? DateTime.now(),
      title: 'Chọn khoảng thời gian',
      keyPrefix: 'statistics-date',
    );
    if (!mounted || selection == null) return;
    final reload =
        _controller.hasResult ||
        (_isCompact && _controller.selectedStationId != null);
    final optionsLoad = _controller.setTimeRange(
      selection.start,
      selection.end,
    );
    if (reload) await _controller.search();
    await optionsLoad;
  }

  void _showFeedbackIfNeeded() {
    final version = _controller.feedbackVersion;
    final message = _controller.feedbackMessage;
    if (version == _lastFeedbackVersion || message == null) return;
    _lastFeedbackVersion = version;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }
}

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

/// "01/09 – 21/09/2026" (dates only, like Figma C03).
String _dateRangeLabel(DateTime start, DateTime end) {
  String two(int number) => number.toString().padLeft(2, '0');
  final last = '${two(end.day)}/${two(end.month)}/${end.year}';
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return last;
  }
  final first = start.year == end.year
      ? '${two(start.day)}/${two(start.month)}'
      : '${two(start.day)}/${two(start.month)}/${start.year}';
  return '$first – $last';
}

String _shortRange(DateTime start, DateTime end) {
  String two(int number) => number.toString().padLeft(2, '0');
  String date(DateTime value) => '${two(value.day)}/${two(value.month)}';
  return '${date(start)} – ${date(end)}';
}

/// One batch of the phone list: start time, customer + meta, mixed volume.
class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.item, required this.onTap});

  final OrderStatisticsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final day = item.mixingDate;
    final meta =
        [
              item.concreteGradeName,
              item.vehiclePlate,
              item.locationName ?? item.projectName,
            ]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty);
    final customer = item.customerName?.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "07:30" is ~45pt in Inter ExtraBold: never wrap it.
                  Text(
                    formatStatisticsTime(item.startedAt),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (day != null)
                    Text(
                      '${day.day.toString().padLeft(2, '0')}/'
                      '${day.month.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: p.text3,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.isNotEmpty == true
                        ? customer!
                        : 'Mẻ #${item.rowNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 16,
                      height: 21 / 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text2,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatStatisticsVolume(item.mixedVolume),
                        style: TextStyle(
                          color: p.success,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' m³',
                        style: TextStyle(
                          color: p.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'đặt ${formatStatisticsVolume(item.requestedVolume)} m³',
                  style: TextStyle(
                    color: p.text3,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Draft of the four "Lọc thêm" filters; applied only on Tìm kiếm.
class _ExtraFiltersDraft {
  _ExtraFiltersDraft({
    this.vehiclePlate,
    this.customerName,
    this.concreteGradeName,
    this.employeeName,
  });

  factory _ExtraFiltersDraft.fromController(ReportsController controller) =>
      _ExtraFiltersDraft(
        vehiclePlate: controller.selectedVehiclePlate,
        customerName: controller.selectedCustomerName,
        concreteGradeName: controller.selectedConcreteGradeName,
        employeeName: controller.selectedEmployeeName,
      );

  String? vehiclePlate;
  String? customerName;
  String? concreteGradeName;
  String? employeeName;

  void clear() {
    vehiclePlate = null;
    customerName = null;
    concreteGradeName = null;
    employeeName = null;
  }
}

/// Figma C04: Xe / Khách hàng / Mác bê tông / Nhân viên of the station.
class _ExtraFiltersSheet extends StatefulWidget {
  const _ExtraFiltersSheet({required this.controller, required this.initial});

  final ReportsController controller;
  final _ExtraFiltersDraft initial;

  @override
  State<_ExtraFiltersSheet> createState() => _ExtraFiltersSheetState();
}

class _ExtraFiltersSheetState extends State<_ExtraFiltersSheet> {
  late final _ExtraFiltersDraft _draft = widget.initial;

  Future<void> _pick(
    String title,
    List<String> options,
    String? current,
    ValueChanged<String?> apply,
  ) async {
    final picked = await showPickerSheet<String>(
      context: context,
      title: title,
      searchHint: 'Tìm ${title.toLowerCase()}',
      clearLabel: 'Tất cả',
      selected: current,
      options: [
        for (final option in options)
          PickerOption(value: option, title: option),
      ],
    );
    if (!mounted || picked == null) return;
    setState(() => apply(picked.value));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final options = controller.filterOptions;
        Widget field(
          String key,
          String label,
          String title,
          List<String> values,
          String? current,
          ValueChanged<String?> apply,
        ) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SelectFieldButton(
            key: ValueKey<String>(key),
            label: label,
            placeholder: values.isEmpty ? 'Không có dữ liệu' : 'Tất cả',
            value: current,
            enabled: !controller.isLoadingOptions && values.isNotEmpty,
            onTap: () => _pick(title, values, current, apply),
            onClear: () => setState(() => apply(null)),
          ),
        );
        return AppSheetFrame(
          title: 'Lọc thêm',
          footer: Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const ValueKey<String>('statistics-extra-reset'),
                  label: 'Đặt lại',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => setState(_draft.clear),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  key: const ValueKey<String>('statistics-extra-search'),
                  label: 'Tìm kiếm',
                  icon: Icons.search_rounded,
                  onPressed: () => Navigator.of(context).pop(_draft),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.isLoadingOptions) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
              ],
              field(
                'statistics-vehicle',
                'XE',
                'Xe',
                options.vehiclePlates,
                _draft.vehiclePlate,
                (value) => _draft.vehiclePlate = value,
              ),
              field(
                'statistics-customer',
                'KHÁCH HÀNG',
                'Khách hàng',
                options.customerNames,
                _draft.customerName,
                (value) => _draft.customerName = value,
              ),
              field(
                'statistics-grade',
                'MÁC BÊ TÔNG',
                'Mác bê tông',
                options.concreteGradeNames,
                _draft.concreteGradeName,
                (value) => _draft.concreteGradeName = value,
              ),
              field(
                'statistics-employee',
                'NHÂN VIÊN',
                'Nhân viên',
                options.employeeNames,
                _draft.employeeName,
                (value) => _draft.employeeName = value,
              ),
            ],
          ),
        );
      },
    );
  }
}
