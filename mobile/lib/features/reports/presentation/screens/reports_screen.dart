import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
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
    this.now,
    this.exportFileSaver,
  });

  final ReportsRepository repository;
  final CompanyRepository companyRepository;
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
      _controller.initialize(
        isAdmin: app.hasRole('ADMIN'),
        initialCompanyId: app.session?.user.companyId,
      ),
    );
  }

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
        return ColoredBox(
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
                    _statisticsHeader(context),
                    const SizedBox(height: 12),
                    _buildViewMode(context),
                    const SizedBox(height: 12),
                    _buildFilters(context),
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
      },
    );
  }

  Widget _statisticsHeader(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Thống kê',
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
            label: Text('Tổng'),
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
      displayStringForOption: _stationLabel,
      searchStringForOption: (station) {
        final company = station.companyName?.trim();
        final stationLabel = _stationLabel(station);
        return company == null || company.isEmpty
            ? '$stationLabel ${station.id}'
            : '$company $stationLabel ${station.id}';
      },
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

  String _stationLabel(OrderStatisticsStation station) {
    final name = station.name?.trim();
    return name == null || name.isEmpty ? 'Trạm ${station.id}' : name;
  }

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
    await _controller.setTimeRange(selection.start, selection.end);
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
