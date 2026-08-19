import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _controller.initialize(),
    );
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
            builder: (context, _) => IconButton(
              tooltip: 'Làm mới',
              onPressed:
                  _controller.report == null || _controller.isLoadingReport
                  ? null
                  : _controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
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
    final report = _controller.report;
    return RefreshIndicator(
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
                      icon: Icons.inventory_2_outlined,
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
                    SegmentedButton<_ReportSection>(
                      key: const ValueKey<String>('material-report-section'),
                      segments: const [
                        ButtonSegment(
                          value: _ReportSection.overview,
                          icon: Icon(Icons.dashboard_outlined),
                          label: Text('Tổng quan'),
                        ),
                        ButtonSegment(
                          value: _ReportSection.transactions,
                          icon: Icon(Icons.receipt_long_outlined),
                          label: Text('Giao dịch'),
                        ),
                      ],
                      selected: {_section},
                      onSelectionChanged: (selection) => setState(() {
                        _section = selection.single;
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
    );
  }

  Widget _buildScopeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
            onSelected: (station) => _controller.selectStation(station.id),
            onCleared: () => _controller.selectStation(null),
            enabled:
                !_controller.isLoadingScope &&
                (!widget.isAdmin || _controller.selectedCompanyId != null),
            hintText: 'Tìm trạm trộn',
            labelText: 'Trạm trộn',
            prefixIcon: Icons.factory_outlined,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey<String>('material-date-range'),
            onPressed: () => _pickDateRange(context),
            icon: const Icon(Icons.date_range_outlined),
            label: Text(_dateRangeLabel(_controller.from, _controller.to)),
          ),
          const SizedBox(height: 10),
          Material(
            color: const Color(0xFFF8FAFC),
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
                    const Icon(
                      Icons.tune,
                      size: 20,
                      color: AppColors.brandBlue,
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
                    const Icon(Icons.chevron_right, color: AppColors.mutedText),
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
            icon: const Icon(Icons.analytics_outlined),
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
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
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
        style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
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
        if (report.transactions.isEmpty)
          const AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Chưa có giao dịch',
            message:
                'Không tìm thấy giao dịch phù hợp với bộ lọc và khoảng thời gian.',
          )
        else
          for (final transaction in report.transactions) ...[
            MaterialTransactionCard(
              transaction: transaction,
              onTap: () => showMaterialTransactionDetails(context, transaction),
            ),
            const SizedBox(height: 10),
          ],
        if (report.totalPages > 1) ...[
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
                  icon: const Icon(Icons.chevron_left),
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
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Trang sau'),
                ),
              ),
            ],
          ),
        ],
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
    if (result != null) _controller.setDateRange(result.start, result.end);
  }

  Future<void> _showFilters(BuildContext context) async {
    var group = _controller.materialGroup;
    var view = _controller.viewMode;
    var value = _controller.valueMode;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bộ lọc báo cáo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nhóm vật liệu',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MaterialGroupFilter.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: group == item,
                        showCheckmark: false,
                        onSelected: (_) => setSheetState(() => group = item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<MaterialViewMode>(
                initialValue: view,
                decoration: const InputDecoration(labelText: 'Loại dữ liệu'),
                items: MaterialViewMode.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (item) {
                  if (item != null) setSheetState(() => view = item);
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<MaterialValueMode>(
                segments: MaterialValueMode.values
                    .map(
                      (item) =>
                          ButtonSegment(value: item, label: Text(item.label)),
                    )
                    .toList(growable: false),
                selected: {value},
                onSelectionChanged: (selection) =>
                    setSheetState(() => value = selection.single),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Áp dụng bộ lọc'),
              ),
            ],
          ),
        ),
      ),
    );
    if (applied == true) {
      _controller
        ..setMaterialGroup(group)
        ..setViewMode(view)
        ..setValueMode(value);
    }
  }
}

class _WarningsPanel extends StatelessWidget {
  const _WarningsPanel({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFED7AA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
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
