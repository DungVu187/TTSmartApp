import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/files/export_file_saver.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/searchable_autocomplete_field.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/presentation/widgets/company_autocomplete_field.dart';
import '../../data/models/weigh_station_filter_models.dart';
import '../../data/repositories/weigh_station_repository.dart';
import '../controllers/weigh_station_controller.dart';
import '../widgets/weigh_station_result_widgets.dart';

abstract final class _WeighStationDesign {
  static const background = Color(0xFFF8FAFC);
  static const border = Color(0xFF94A3B8);
  static const borderWidth = 1.25;
}

class WeighStationScreen extends StatefulWidget {
  const WeighStationScreen({
    super.key,
    required this.repository,
    required this.companyRepository,
    this.now,
    this.exportFileSaver,
  });

  final WeighStationRepository repository;
  final CompanyRepository companyRepository;
  final DateTime Function()? now;
  final ExportFileSaver? exportFileSaver;

  @override
  State<WeighStationScreen> createState() => _WeighStationScreenState();
}

class _WeighStationScreenState extends State<WeighStationScreen> {
  WeighStationController? _controller;
  bool _canExport = false;
  bool _showAdvancedFilters = false;
  int _lastFeedbackVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (_controller != null ||
        !app.hasPermission(
          AccessFunctionCodes.weighStations,
          AccessPermission.dSach,
        )) {
      return;
    }
    _canExport = app.hasPermission(
      AccessFunctionCodes.weighStations,
      AccessPermission.exportData,
    );
    _controller = WeighStationController(
      repository: widget.repository,
      companyRepository: widget.companyRepository,
      isAdmin: app.hasRole('ADMIN'),
      initialCompanyId: app.session?.user.companyId,
      now: widget.now,
      exportFileSaver: widget.exportFileSaver,
    );
    unawaited(_controller!.initialize());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final canList = app.hasPermission(
      AccessFunctionCodes.weighStations,
      AccessPermission.dSach,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý cân ô tô')),
      body: SafeArea(
        child: !canList
            ? const AppContent(
                maxWidth: 720,
                child: Card(
                  child: AppEmptyState(
                    icon: Icons.lock_outline,
                    title: 'Không có quyền xem cân ô tô',
                    message:
                        'Tài khoản chưa được cấp quyền TKTC - D.Sách để sử dụng chức năng này.',
                  ),
                ),
              )
            : _buildAuthorizedBody(),
      ),
    );
  }

  Widget _buildAuthorizedBody() {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _showFeedbackIfNeeded(controller);
        return ColoredBox(
          color: _WeighStationDesign.background,
          child: ListView(
            key: const PageStorageKey<String>('weigh-station-scroll'),
            children: [
              AppContent(
                horizontalPadding: 12,
                topPadding: 12,
                maxWidth: 1320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionHeader(
                      title: 'Quản lý cân ô tô',
                      subtitle:
                          'Tra cứu phiếu cân và tổng hợp theo trạm, giai đoạn tùy chọn và khoảng ngày.',
                    ),
                    const SizedBox(height: 12),
                    _buildFilterCard(controller),
                    const SizedBox(height: 18),
                    _buildDetailSection(controller),
                    const SizedBox(height: 18),
                    _buildSummarySection(controller),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterCard(WeighStationController controller) {
    return Card(
      key: const ValueKey<String>('weigh-station-filters'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bộ lọc',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              'Chọn trạm, thời gian và trạng thái xe trước khi tra cứu.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            if (controller.companyError != null) ...[
              ErrorPanel(
                message: weighStationErrorMessage(
                  controller.companyError!,
                  fallback: 'Không thể tải danh sách công ty.',
                ),
                onRetry: controller.retryCompanies,
              ),
              const SizedBox(height: 12),
            ],
            if (controller.stationError != null) ...[
              ErrorPanel(
                message: weighStationErrorMessage(
                  controller.stationError!,
                  fallback: 'Không thể tải danh sách trạm cân.',
                ),
                onRetry: controller.retryStations,
              ),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final fields = <Widget>[
                  if (controller.isAdmin)
                    CompanyAutocompleteField(
                      companies: controller.companies,
                      selectedCompanyId: controller.selectedCompanyId,
                      onSelected: (company) =>
                          controller.selectCompany(company.id),
                      onCleared: () => controller.selectCompany(null),
                      enabled: !controller.isLoadingCompanies,
                      compact: true,
                      borderColor: _WeighStationDesign.border,
                      borderWidth: _WeighStationDesign.borderWidth,
                    ),
                  SearchableAutocompleteField<WeighStationStation>(
                    key: const ValueKey<String>('weigh-station-station'),
                    options: controller.stations,
                    selectedOption: controller.selectedStation,
                    displayStringForOption: (station) => station.displayName,
                    searchStringForOption: (station) =>
                        '${station.displayName} ${station.id}',
                    optionSubtitle: (station) => 'Mã trạm: ${station.id}',
                    onSelected: (station) =>
                        controller.selectStation(station.id),
                    onCleared: () => controller.selectStation(null),
                    enabled:
                        (!controller.isAdmin ||
                            controller.selectedCompanyId != null) &&
                        !controller.isLoadingStations,
                    loading: controller.isLoadingStations,
                    hintText: 'Chọn trạm cân',
                    labelText: 'Trạm cân',
                    prefixIcon: Icons.scale_outlined,
                    compact: true,
                    borderColor: _WeighStationDesign.border,
                    borderWidth: _WeighStationDesign.borderWidth,
                  ),
                  KeyedSubtree(
                    key: const ValueKey<String>('weigh-station-stage'),
                    child: DropdownButtonFormField<WeighStationStage>(
                      key: ValueKey<WeighStationStage?>(
                        controller.selectedStage,
                      ),
                      isExpanded: true,
                      initialValue: controller.selectedStage,
                      decoration: _fieldDecoration(
                        label: 'Giai đoạn cân (tùy chọn)',
                        icon: Icons.low_priority_outlined,
                      ),
                      hint: const Text('Tất cả giai đoạn'),
                      items: <DropdownMenuItem<WeighStationStage>>[
                        const DropdownMenuItem<WeighStationStage>(
                          value: null,
                          child: Text('Tất cả giai đoạn'),
                        ),
                        ...WeighStationStage.values.map(
                          (stage) => DropdownMenuItem<WeighStationStage>(
                            value: stage,
                            child: Text(stage.label),
                          ),
                        ),
                      ],
                      onChanged: controller.selectStage,
                    ),
                  ),
                  _DateRangeField(
                    fromDate: controller.fromDate,
                    toDate: controller.toDate,
                    onTap: () => _pickDateRange(controller),
                  ),
                ];
                return _ResponsiveFieldGrid(fields: fields, wide: wide);
              },
            ),
            if (controller.optionsError != null) ...[
              const SizedBox(height: 12),
              ErrorPanel(
                message: weighStationErrorMessage(
                  controller.optionsError!,
                  fallback: 'Không thể tải danh sách bộ lọc.',
                ),
                onRetry: controller.retryOptions,
              ),
            ],
            if (controller.isLoadingOptions) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final fields = <Widget>[
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-vehicle'),
                    label: 'Biển số xe',
                    hint: 'Chọn biển số xe',
                    icon: Icons.local_shipping_outlined,
                    options: controller.filterOptions.vehiclePlates,
                    selected: controller.selectedVehiclePlate,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setVehiclePlate,
                  ),
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-goods'),
                    label: 'Tên hàng',
                    hint: 'Chọn tên hàng',
                    icon: Icons.inventory_2_outlined,
                    options: controller.filterOptions.goodsNames,
                    selected: controller.selectedGoodsName,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setGoodsName,
                  ),
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-operator'),
                    label: 'Người cân',
                    hint: 'Chọn người cân',
                    icon: Icons.person_outline,
                    options: controller.filterOptions.operatorNames,
                    selected: controller.selectedOperatorName,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setOperatorName,
                  ),
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-unit'),
                    label: 'Đơn vị',
                    hint: 'Chọn đơn vị',
                    icon: Icons.business_outlined,
                    options: controller.filterOptions.unitNames,
                    selected: controller.selectedUnitName,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setUnitName,
                  ),
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-type'),
                    label: 'Kiểu cân',
                    hint: 'Chọn kiểu cân',
                    icon: Icons.compare_arrows_outlined,
                    options: controller.filterOptions.weighingTypes,
                    selected: controller.selectedWeighingType,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setWeighingType,
                  ),
                ];
                final grid = _ResponsiveFieldGrid(fields: fields, wide: wide);
                if (wide) return grid;
                final selectedCount = [
                  controller.selectedVehiclePlate,
                  controller.selectedGoodsName,
                  controller.selectedOperatorName,
                  controller.selectedUnitName,
                  controller.selectedWeighingType,
                ].where((value) => value != null).length;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        key: const ValueKey<String>(
                          'weigh-station-advanced-filters',
                        ),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(
                          () => _showAdvancedFilters = !_showAdvancedFilters,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bộ lọc nâng cao',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedCount == 0
                                          ? 'Biển số, hàng hóa, người cân, đơn vị, kiểu cân'
                                          : 'Đang áp dụng $selectedCount bộ lọc',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _showAdvancedFilters
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: const Color(0xFF2563EB),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showAdvancedFilters)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: grid,
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: FilledButton.icon(
                    key: const ValueKey<String>('weigh-station-search'),
                    onPressed: controller.search,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Tìm kiếm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('weigh-station-reset'),
                    onPressed: controller.resetFilters,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Đặt lại'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(WeighStationController controller) {
    final result = controller.detailResult;
    return _ResultSection(
      key: const ValueKey<String>('weigh-station-detail-section'),
      title: 'Chi tiết phiếu cân',
      subtitle: result == null ? null : '${result.totalCount} phiếu cân',
      exportButton: _canExport
          ? _ExportButton(
              key: const ValueKey<String>('weigh-station-detail-export'),
              label: 'Xuất Excel chi tiết',
              loading: controller.isExportingDetail,
              onPressed: controller.exportDetail,
            )
          : null,
      loading: controller.isLoadingDetail,
      error: controller.detailError == null
          ? null
          : ErrorPanel(
              message: weighStationErrorMessage(
                controller.detailError!,
                fallback: 'Không thể tải chi tiết phiếu cân.',
              ),
              onRetry: controller.retryDetail,
            ),
      child: _detailContent(controller),
    );
  }

  Widget _detailContent(WeighStationController controller) {
    final result = controller.detailResult;
    if (!controller.hasSearched) {
      return const AppEmptyState(
        icon: Icons.search_outlined,
        title: 'Chưa tìm kiếm phiếu cân',
        message: 'Chọn bộ lọc rồi bấm Tìm kiếm để tải dữ liệu.',
      );
    }
    if (result == null && controller.isLoadingDetail) {
      return const _LocalLoading();
    }
    if (result == null && controller.detailError != null) {
      return const SizedBox.shrink();
    }
    if (result == null || result.items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inbox_outlined,
        title: 'Không có dữ liệu',
        message: 'Không có dữ liệu trong khoảng thời gian đã chọn',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeighStationDetailTable(page: result),
        const SizedBox(height: 10),
        _Pagination(
          keyPrefix: 'weigh-station-detail',
          currentPage: result.pageNumber,
          totalPages: result.totalPages,
          loading: controller.isLoadingDetail,
          onPage: controller.goToDetailPage,
        ),
      ],
    );
  }

  Widget _buildSummarySection(WeighStationController controller) {
    final summary = controller.summaryResult;
    return _ResultSection(
      key: const ValueKey<String>('weigh-station-summary-section'),
      title: 'Tổng hợp',
      subtitle: summary == null ? null : '${summary.totalCount} loại hàng',
      exportButton: _canExport
          ? _ExportButton(
              key: const ValueKey<String>('weigh-station-summary-export'),
              label: 'Xuất Excel tổng hợp',
              loading: controller.isExportingSummary,
              onPressed: controller.exportSummary,
            )
          : null,
      loading: controller.isLoadingSummary,
      error: controller.summaryError == null
          ? null
          : ErrorPanel(
              message: weighStationErrorMessage(
                controller.summaryError!,
                fallback: 'Không thể tải dữ liệu tổng hợp.',
              ),
              onRetry: controller.retrySummary,
            ),
      child: _summaryContent(controller),
    );
  }

  Widget _summaryContent(WeighStationController controller) {
    final summary = controller.summaryResult;
    if (!controller.hasSearched) {
      return const AppEmptyState(
        icon: Icons.query_stats_outlined,
        title: 'Chưa có dữ liệu tổng hợp',
        message: 'Kết quả tổng hợp sẽ xuất hiện sau khi bấm Tìm kiếm.',
      );
    }
    if (summary == null && controller.isLoadingSummary) {
      return const _LocalLoading();
    }
    if (summary == null && controller.summaryError != null) {
      return const SizedBox.shrink();
    }
    if (summary == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.items.isEmpty)
          const AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Không có dữ liệu',
            message: 'Không có dữ liệu trong khoảng thời gian đã chọn',
          )
        else ...[
          WeighStationSummaryTable(summary: summary),
          const SizedBox(height: 10),
          _Pagination(
            keyPrefix: 'weigh-station-summary',
            currentPage: summary.pageNumber,
            totalPages: summary.totalPages,
            loading: controller.isLoadingSummary,
            onPage: controller.goToSummaryPage,
          ),
          const SizedBox(height: 12),
        ],
        WeighStationSummaryOverview(summary: summary),
      ],
    );
  }

  Future<void> _pickDateRange(WeighStationController controller) async {
    final selection = await showAppDateRangePicker(
      context: context,
      initialStart: controller.fromDate,
      initialEnd: controller.toDate,
      now: widget.now?.call() ?? DateTime.now(),
      title: 'Chọn khoảng ngày cân',
      keyPrefix: 'weigh-station-date',
    );
    if (!mounted || selection == null) return;
    await controller.setDateRange(selection.start, selection.end);
  }

  void _showFeedbackIfNeeded(WeighStationController controller) {
    if (controller.feedbackVersion == _lastFeedbackVersion ||
        controller.feedbackMessage == null) {
      return;
    }
    _lastFeedbackVersion = controller.feedbackVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(controller.feedbackMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }
}

class _ResponsiveFieldGrid extends StatelessWidget {
  const _ResponsiveFieldGrid({required this.fields, required this.wide});

  final List<Widget> fields;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            fields[index],
            if (index < fields.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: fields
          .map((field) => SizedBox(width: 280, child: field))
          .toList(growable: false),
    );
  }
}

class _StringFilterField extends StatelessWidget {
  const _StringFilterField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final List<String> options;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SearchableAutocompleteField<String>(
      options: options,
      selectedOption: selected,
      displayStringForOption: (value) => value,
      onSelected: onChanged,
      onCleared: () => onChanged(null),
      enabled: enabled,
      hintText: hint,
      labelText: label,
      prefixIcon: icon,
      compact: true,
      borderColor: _WeighStationDesign.border,
      borderWidth: _WeighStationDesign.borderWidth,
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.fromDate,
    required this.toDate,
    required this.onTap,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey<String>('weigh-station-date-range'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: _fieldDecoration(
          label: 'Khoảng ngày cân',
          icon: Icons.calendar_month_outlined,
        ),
        child: Text('${_date(fromDate)} - ${_date(toDate)}'),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    super.key,
    required this.title,
    required this.loading,
    required this.child,
    this.subtitle,
    this.exportButton,
    this.error,
  });

  final String title;
  final String? subtitle;
  final bool loading;
  final Widget child;
  final Widget? exportButton;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      if (exportButton != null) ...[
                        const SizedBox(height: 10),
                        exportButton!,
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    if (exportButton != null) ...[
                      const SizedBox(width: 10),
                      exportButton!,
                    ],
                  ],
                );
              },
            ),
            if (loading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (error != null) ...[const SizedBox(height: 12), error!],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined, size: 18),
      label: Text(label),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.keyPrefix,
    required this.currentPage,
    required this.totalPages,
    required this.loading,
    required this.onPage,
  });

  final String keyPrefix;
  final int currentPage;
  final int totalPages;
  final bool loading;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final canPrevious = currentPage > 1 && !loading;
    final canNext = totalPages > 0 && currentPage < totalPages && !loading;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: ValueKey<String>('$keyPrefix-page-first'),
          tooltip: 'Trang đầu',
          onPressed: canPrevious ? () => onPage(1) : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton(
          key: ValueKey<String>('$keyPrefix-page-previous'),
          tooltip: 'Trang trước',
          onPressed: canPrevious ? () => onPage(currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            totalPages == 0 ? '0/0' : '$currentPage/$totalPages',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          key: ValueKey<String>('$keyPrefix-page-next'),
          tooltip: 'Trang sau',
          onPressed: canNext ? () => onPage(currentPage + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          key: ValueKey<String>('$keyPrefix-page-last'),
          tooltip: 'Trang cuối',
          onPressed: canNext ? () => onPage(totalPages) : null,
          icon: const Icon(Icons.last_page),
        ),
      ],
    );
  }
}

class _LocalLoading extends StatelessWidget {
  const _LocalLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
}) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon, size: 18),
  isDense: true,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(
      color: _WeighStationDesign.border,
      width: _WeighStationDesign.borderWidth,
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(
      color: _WeighStationDesign.border,
      width: _WeighStationDesign.borderWidth,
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
  ),
);

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-${value.year}';
