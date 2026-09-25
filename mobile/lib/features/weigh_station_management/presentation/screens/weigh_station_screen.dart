import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
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
import '../../data/models/weigh_station_result_models.dart';
import '../../data/repositories/weigh_station_repository.dart';
import '../controllers/weigh_station_controller.dart';
import '../widgets/weigh_station_result_widgets.dart';
import 'weigh_ticket_detail_screen.dart';

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
  bool _showSummary = false;
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
    unawaited(_initialize(_controller!));
  }

  Future<void> _initialize(WeighStationController controller) async {
    await controller.initialize();
    // On a phone the only station of the scope is picked for the user, which
    // saves a pointless tap before the first result.
    if (!mounted || !_isCompact || controller.selectedStationId != null) return;
    if (controller.stations.length == 1) {
      await _applyStation(controller, controller.stations.single.id);
    }
  }

  bool get _isCompact => MediaQuery.sizeOf(context).width < 600;

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
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý cân ô tô'),
        actions: [
          if (canList && controller != null && _isCompact)
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    key: const ValueKey<String>(
                      'weigh-station-advanced-filters',
                    ),
                    icon: LucideIcons.slidersHorizontal,
                    tooltip: 'Bộ lọc nâng cao',
                    badgeCount: _advancedFilterCount(controller),
                    onPressed: () => _openAdvancedFilters(controller),
                  ),
                  if (_canExport)
                    AppIconButton(
                      key: const ValueKey<String>('weigh-station-export'),
                      icon: LucideIcons.download,
                      tooltip: _showSummary
                          ? 'Xuất Excel tổng hợp'
                          : 'Xuất Excel chi tiết',
                      onPressed:
                          (_showSummary
                              ? controller.isExportingSummary
                              : controller.isExportingDetail)
                          ? null
                          : () => _showSummary
                                ? controller.exportSummary()
                                : controller.exportDetail(),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: !canList
            ? const AppContent(
                maxWidth: 720,
                child: Card(
                  child: AppEmptyState(
                    icon: LucideIcons.lock,
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
        if (_isCompact) return _buildMobileBody(controller);
        return ColoredBox(
          color: context.palette.surfaceMuted,
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

  // ---------------------------------------------------------------- mobile

  /// Phone layout (Figma C11/C13): tabs, scope chips that search on change,
  /// and an infinite list. Advanced filters live in a sheet (C14).
  Widget _buildMobileBody(WeighStationController controller) {
    final stationName = controller.selectedStation?.displayName;
    final company = controller.selectedCompany;
    return InfiniteListView(
      storageKey: 'weigh-station-mobile-scroll',
      onLoadMore: () => unawaited(
        _showSummary
            ? controller.loadMoreSummary()
            : controller.loadMoreDetail(),
      ),
      onRefresh: () =>
          controller.hasSearched ? controller.search() : Future.value(),
      padding: const EdgeInsets.fromLTRB(kPagePadding, 4, kPagePadding, 28),
      children: [
        SegmentedTabs<bool>(
          segments: const [(false, 'Phiếu cân'), (true, 'Tổng hợp')],
          selected: _showSummary,
          onChanged: (value) => setState(() => _showSummary = value),
        ),
        const SizedBox(height: 9),
        FilterChipBar(
          children: [
            if (controller.isAdmin)
              FilterChipButton(
                key: const ValueKey<String>('weigh-station-company'),
                icon: LucideIcons.building,
                label: company?.displayName ?? 'Chọn công ty',
                showChevron: true,
                onTap: controller.isLoadingCompanies
                    ? null
                    : () => _pickCompany(controller),
              ),
            FilterChipButton(
              key: const ValueKey<String>('weigh-station-date-range'),
              icon: LucideIcons.calendar,
              label:
                  '${_shortDate(controller.fromDate)} – '
                  '${_shortDate(controller.toDate)}',
              active: true,
              onTap: () => _pickDateRange(controller),
            ),
            FilterChipButton(
              key: const ValueKey<String>('weigh-station-station'),
              icon: LucideIcons.scale,
              label: stationName ?? 'Chọn trạm cân',
              showChevron: true,
              onTap: controller.isLoadingStations
                  ? null
                  : () => _pickStation(controller),
            ),
          ],
        ),
        for (final (error, fallback, retry) in [
          (
            controller.companyError,
            'Không thể tải danh sách công ty.',
            controller.retryCompanies,
          ),
          (
            controller.stationError,
            'Không thể tải danh sách trạm cân.',
            controller.retryStations,
          ),
        ])
          if (error != null) ...[
            const SizedBox(height: 10),
            ErrorBanner(
              message: weighStationErrorMessage(error, fallback: fallback),
              onRetry: retry,
            ),
          ],
        const SizedBox(height: 16),
        if (!controller.hasSearched)
          _mobilePrompt(controller)
        else if (_showSummary)
          _mobileSummary(controller)
        else
          _mobileDetail(controller),
      ],
    );
  }

  Widget _mobilePrompt(WeighStationController controller) {
    if (controller.isLoadingStations || controller.isLoadingCompanies) {
      return const _LocalLoading();
    }
    final needsCompany =
        controller.isAdmin && controller.selectedCompanyId == null;
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: StateView(
        icon: LucideIcons.scale,
        title: needsCompany ? 'Chọn công ty' : 'Chọn trạm cân',
        message: needsCompany
            ? 'Chọn công ty rồi chọn trạm cân để xem phiếu cân.'
            : 'Chọn trạm cân và khoảng ngày để xem phiếu cân.',
        actions: [
          AppButton(
            label: needsCompany ? 'Chọn công ty' : 'Chọn trạm cân',
            icon: needsCompany ? LucideIcons.building : LucideIcons.scale,
            expand: false,
            onPressed: () => needsCompany
                ? _pickCompany(controller)
                : _pickStation(controller),
          ),
        ],
      ),
    );
  }

  Widget _mobileDetail(WeighStationController controller) {
    final result = controller.detailResult;
    if (result == null && controller.isLoadingDetail) {
      return const _LocalLoading();
    }
    if (result == null && controller.detailError != null) {
      return ErrorBanner(
        message: weighStationErrorMessage(
          controller.detailError!,
          fallback: 'Không thể tải chi tiết phiếu cân.',
        ),
        onRetry: controller.retryDetail,
      );
    }
    if (result == null || controller.loadedDetailItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 36),
        child: StateView(
          icon: LucideIcons.inbox,
          title: 'Không có phiếu cân',
          message: 'Không có dữ liệu trong khoảng thời gian đã chọn.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel('${result.totalCount} phiếu cân'),
        const SizedBox(height: 8),
        InsetCard(
          dividerIndent: kLeadingDividerIndent,
          children: [
            for (final item in controller.loadedDetailItems)
              _TicketRow(
                item: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WeighTicketDetailScreen(
                      item: item,
                      canViewMaterialValue: result.canViewMaterialValue,
                    ),
                  ),
                ),
              ),
          ],
        ),
        LoadMoreFooter(
          loading: controller.isLoadingDetail,
          errorMessage: controller.detailError == null
              ? null
              : weighStationErrorMessage(
                  controller.detailError!,
                  fallback: 'Không thể tải thêm phiếu cân.',
                ),
          onRetry: controller.retryDetail,
        ),
      ],
    );
  }

  Widget _mobileSummary(WeighStationController controller) {
    final summary = controller.summaryResult;
    if (summary == null && controller.isLoadingSummary) {
      return const _LocalLoading();
    }
    if (summary == null && controller.summaryError != null) {
      return ErrorBanner(
        message: weighStationErrorMessage(
          controller.summaryError!,
          fallback: 'Không thể tải dữ liệu tổng hợp.',
        ),
        onRetry: controller.retrySummary,
      );
    }
    if (summary == null) return const SizedBox.shrink();
    final p = context.palette;
    final converted = summary.totalConvertedQuantities
        .map((value) => '${formatWeighNumber(value.quantity)} ${value.unit}')
        .join(' · ');
    final top = summary.topGoods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatRow(
          children: [
            StatTile(
              label: 'Tổng số loại hàng',
              value: '${summary.totalCount}',
              unit: 'loại',
            ),
            StatTile(
              label: 'Tổng khối lượng',
              value: formatWeighNumber(summary.totalGoodsWeightKg),
              unit: 'kg',
            ),
          ],
        ),
        const SizedBox(height: 8),
        StatRow(
          children: [
            if (summary.canViewMaterialValue)
              StatTile(
                label: 'Tổng giá trị',
                value: formatWeighCurrency(summary.totalMaterialValueVnd),
              ),
            StatTile(
              label: 'Khối lượng quy đổi',
              value: converted.isEmpty ? '—' : converted,
              valueColor: converted.isEmpty ? null : p.success,
            ),
          ],
        ),
        if (top != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: p.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconTile(icon: LucideIcons.trendingUp, background: p.surface),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loại hàng nhiều nhất',
                        style: TextStyle(
                          color: p.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        top.goodsName?.trim().isNotEmpty == true
                            ? top.goodsName!
                            : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${formatWeighNumber(top.goodsWeightKg)} kg',
                  style: TextStyle(
                    color: p.onPrimaryContainer,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (controller.loadedSummaryItems.isEmpty)
          const StateView(
            icon: LucideIcons.inbox,
            title: 'Không có dữ liệu',
            message: 'Không có dữ liệu trong khoảng thời gian đã chọn.',
          )
        else ...[
          GroupLabel('${summary.totalCount} loại hàng'),
          const SizedBox(height: 8),
          InsetCard(
            children: [
              for (final item in controller.loadedSummaryItems)
                _SummaryGoodsRow(
                  item: item,
                  showValue: summary.canViewMaterialValue,
                ),
            ],
          ),
          LoadMoreFooter(
            loading: controller.isLoadingSummary,
            errorMessage: controller.summaryError == null
                ? null
                : weighStationErrorMessage(
                    controller.summaryError!,
                    fallback: 'Không thể tải thêm dữ liệu tổng hợp.',
                  ),
            onRetry: controller.retrySummary,
          ),
        ],
      ],
    );
  }

  int _advancedFilterCount(WeighStationController controller) => [
    controller.selectedStage,
    controller.selectedVehiclePlate,
    controller.selectedGoodsName,
    controller.selectedOperatorName,
    controller.selectedUnitName,
    controller.selectedWeighingType,
  ].where((value) => value != null).length;

  /// Station change searches immediately; filter options load in parallel.
  Future<void> _applyStation(
    WeighStationController controller,
    int stationId,
  ) async {
    final optionsLoad = controller.selectStation(stationId);
    await controller.search();
    await optionsLoad;
  }

  Future<void> _pickCompany(WeighStationController controller) async {
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn công ty',
      searchHint: 'Tìm công ty',
      icon: LucideIcons.building,
      selected: controller.selectedCompanyId,
      options: [
        for (final company in controller.companies)
          PickerOption(value: company.id, title: company.displayName),
      ],
    );
    if (!mounted || picked == null) return;
    await controller.selectCompany(picked.value);
  }

  Future<void> _pickStation(WeighStationController controller) async {
    if (controller.isAdmin && controller.selectedCompanyId == null) {
      await _pickCompany(controller);
      if (!mounted || controller.selectedCompanyId == null) return;
    }
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn trạm cân',
      searchHint: 'Tìm trạm cân',
      icon: LucideIcons.scale,
      tone: AppTone.violet,
      selected: controller.selectedStationId,
      emptyMessage: 'Không có trạm cân trong phạm vi được cấp.',
      options: [
        for (final station in controller.stations)
          PickerOption(
            value: station.id,
            title: station.displayName,
            subtitle: 'Mã trạm: ${station.id}',
          ),
      ],
    );
    final stationId = picked?.value;
    if (!mounted || stationId == null) return;
    await _applyStation(controller, stationId);
  }

  Future<void> _openAdvancedFilters(WeighStationController controller) async {
    if (controller.selectedStationId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Chọn trạm cân trước khi lọc.')),
        );
      return;
    }
    final draft = await showAppModalSheet<_WeighAdvancedDraft>(
      context: context,
      builder: (_) => _WeighAdvancedFilterSheet(
        controller: controller,
        initial: _WeighAdvancedDraft.fromController(controller),
      ),
    );
    if (!mounted || draft == null) return;
    if (draft.stage != controller.selectedStage) {
      unawaited(controller.selectStage(draft.stage));
    }
    controller
      ..setVehiclePlate(draft.vehiclePlate)
      ..setGoodsName(draft.goodsName)
      ..setOperatorName(draft.operatorName)
      ..setUnitName(draft.unitName)
      ..setWeighingType(draft.weighingType);
    await controller.search();
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
              ).textTheme.bodySmall?.copyWith(color: context.palette.text2),
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
                      borderColor: context.palette.text3,
                      borderWidth: 1.25,
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
                    prefixIcon: LucideIcons.scale,
                    compact: true,
                    borderColor: context.palette.text3,
                    borderWidth: 1.25,
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
                        context,
                        label: 'Giai đoạn cân (tùy chọn)',
                        icon: LucideIcons.listOrdered,
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
                    icon: LucideIcons.truck,
                    options: controller.filterOptions.vehiclePlates,
                    selected: controller.selectedVehiclePlate,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setVehiclePlate,
                  ),
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-goods'),
                    label: 'Tên hàng',
                    hint: 'Chọn tên hàng',
                    icon: LucideIcons.package,
                    options: controller.filterOptions.goodsNames,
                    selected: controller.selectedGoodsName,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setGoodsName,
                  ),
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-operator'),
                    label: 'Người cân',
                    hint: 'Chọn người cân',
                    icon: LucideIcons.user,
                    options: controller.filterOptions.operatorNames,
                    selected: controller.selectedOperatorName,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setOperatorName,
                  ),
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-unit'),
                    label: 'Đơn vị',
                    hint: 'Chọn đơn vị',
                    icon: LucideIcons.building,
                    options: controller.filterOptions.unitNames,
                    selected: controller.selectedUnitName,
                    enabled: controller.canLoadOptions,
                    onChanged: controller.setUnitName,
                  ),
                  _StringFilterField(
                    key: const ValueKey<String>('weigh-station-type'),
                    label: 'Kiểu cân',
                    hint: 'Chọn kiểu cân',
                    icon: LucideIcons.arrowLeftRight,
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
                    color: context.palette.surfaceMuted,
                    border: Border.all(color: context.palette.border),
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
                              Icon(
                                LucideIcons.slidersHorizontal,
                                color: context.palette.primary,
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
                                    ? LucideIcons.chevronUp
                                    : LucideIcons.chevronDown,
                                color: context.palette.primary,
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
                    icon: const Icon(LucideIcons.search, size: 18),
                    label: const Text('Tìm kiếm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('weigh-station-reset'),
                    onPressed: controller.resetFilters,
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
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
        icon: LucideIcons.search,
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
        icon: LucideIcons.inbox,
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
        icon: LucideIcons.chartNoAxesColumnIncreasing,
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
            icon: LucideIcons.inbox,
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
    final optionsLoad = controller.setDateRange(selection.start, selection.end);
    // Phones have no Search button: a new range reloads straight away.
    if (_isCompact && controller.selectedStationId != null) {
      await controller.search();
    }
    await optionsLoad;
  }

  String _shortDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}';

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
      borderColor: context.palette.text3,
      borderWidth: 1.25,
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
          context,
          label: 'Khoảng ngày cân',
          icon: LucideIcons.calendar,
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
          : const Icon(LucideIcons.download, size: 18),
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
          icon: const Icon(LucideIcons.chevronsLeft),
        ),
        IconButton(
          key: ValueKey<String>('$keyPrefix-page-previous'),
          tooltip: 'Trang trước',
          onPressed: canPrevious ? () => onPage(currentPage - 1) : null,
          icon: const Icon(LucideIcons.chevronLeft),
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
          icon: const Icon(LucideIcons.chevronRight),
        ),
        IconButton(
          key: ValueKey<String>('$keyPrefix-page-last'),
          tooltip: 'Trang cuối',
          onPressed: canNext ? () => onPage(totalPages) : null,
          icon: const Icon(LucideIcons.chevronsRight),
        ),
      ],
    );
  }
}

/// One weigh ticket in the phone list: plate · goods · time · weight + state.
class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.item, required this.onTap});

  final WeighStationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final plate = item.vehiclePlate?.trim();
    final goods = item.goodsName?.trim();
    final type = item.weighingType?.trim();
    final pending = item.weighedOutAt == null;
    return NavRow(
      leading: const IconTile(icon: LucideIcons.truck, tone: AppTone.info),
      title: plate?.isNotEmpty == true ? plate! : 'Phiếu #${item.ticketNumber}',
      titleStyle: TextStyle(
        color: p.text1,
        fontSize: 16,
        height: 21 / 16,
        fontWeight: FontWeight.w700,
      ),
      subtitle:
          '${goods?.isNotEmpty == true ? goods : 'Số phiếu ${item.ticketNumber}'}'
          // Date and time stay together when the line wraps on 360dp.
          ' · ${formatWeighShortDateTime(item.weighingAt).replaceAll(' ', ' ')}',
      subtitleMaxLines: 2,
      showChevron: false,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatWeighNumber(item.goodsWeightKg),
                  style: TextStyle(
                    color: item.goodsWeightKg == null ? p.text3 : p.text1,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.goodsWeightKg != null)
                  TextSpan(
                    text: ' kg',
                    style: TextStyle(
                      color: p.text2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (pending)
            const AppTag(
              label: 'Xe chưa ra',
              tone: AppTone.warning,
              compact: true,
            )
          else if (type != null && type.isNotEmpty)
            AppTag(label: type, tone: weighingTypeTone(type), compact: true),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// One goods line of the weigh summary: name, conversion/value, weight.
class _SummaryGoodsRow extends StatelessWidget {
  const _SummaryGoodsRow({required this.item, required this.showValue});

  final WeighStationSummaryItem item;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = item.goodsName?.trim();
    final details = <String>[
      if (item.convertedQuantities.isNotEmpty)
        'Quy đổi ${item.convertedQuantities.map((value) => '${formatWeighNumber(value.quantity)} ${value.unit}').join(' · ')}'
      else if (item.conversionMessage != null)
        item.conversionMessage!,
      if (showValue && item.materialValueVnd != null)
        formatWeighCurrency(item.materialValueVnd).replaceAll(' ', ' '),
    ];
    return NavRow(
      title: name?.isNotEmpty == true ? name! : 'Loại hàng #${item.stt}',
      subtitle: details.isEmpty ? null : details.join(' · '),
      subtitleMaxLines: 2,
      showChevron: false,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatWeighNumber(item.goodsWeightKg),
                  style: TextStyle(
                    color: p.text1,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' kg',
                  style: TextStyle(
                    color: p.text2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          AppTag(
            label: '${item.ticketCount} phiếu',
            tone: AppTone.neutral,
            compact: true,
          ),
        ],
      ),
    );
  }
}

/// Advanced-filter values edited in the sheet; applied only on "Tìm kiếm".
class _WeighAdvancedDraft {
  _WeighAdvancedDraft({
    this.stage,
    this.vehiclePlate,
    this.goodsName,
    this.operatorName,
    this.unitName,
    this.weighingType,
  });

  factory _WeighAdvancedDraft.fromController(WeighStationController c) =>
      _WeighAdvancedDraft(
        stage: c.selectedStage,
        vehiclePlate: c.selectedVehiclePlate,
        goodsName: c.selectedGoodsName,
        operatorName: c.selectedOperatorName,
        unitName: c.selectedUnitName,
        weighingType: c.selectedWeighingType,
      );

  WeighStationStage? stage;
  String? vehiclePlate;
  String? goodsName;
  String? operatorName;
  String? unitName;
  String? weighingType;

  void clear() {
    stage = null;
    vehiclePlate = null;
    goodsName = null;
    operatorName = null;
    unitName = null;
    weighingType = null;
  }
}

/// Figma C14 — stage + five option filters, pinned Đặt lại / Tìm kiếm.
class _WeighAdvancedFilterSheet extends StatefulWidget {
  const _WeighAdvancedFilterSheet({
    required this.controller,
    required this.initial,
  });

  final WeighStationController controller;
  final _WeighAdvancedDraft initial;

  @override
  State<_WeighAdvancedFilterSheet> createState() =>
      _WeighAdvancedFilterSheetState();
}

class _WeighAdvancedFilterSheetState extends State<_WeighAdvancedFilterSheet> {
  late final _WeighAdvancedDraft _draft = widget.initial;

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
        final enabled =
            controller.canLoadOptions && !controller.isLoadingOptions;
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
            placeholder: 'Tất cả',
            value: current,
            enabled: enabled,
            onTap: () => _pick(title, values, current, apply),
            onClear: () => setState(() => apply(null)),
          ),
        );
        return AppSheetFrame(
          title: 'Bộ lọc nâng cao',
          footer: Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const ValueKey<String>('weigh-station-reset'),
                  label: 'Đặt lại',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => setState(_draft.clear),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  key: const ValueKey<String>('weigh-station-search'),
                  label: 'Tìm kiếm',
                  icon: LucideIcons.search,
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
              if (controller.optionsError != null) ...[
                ErrorBanner(
                  message: weighStationErrorMessage(
                    controller.optionsError!,
                    fallback: 'Không thể tải danh sách bộ lọc.',
                  ),
                  onRetry: controller.retryOptions,
                ),
                const SizedBox(height: 12),
              ],
              const GroupLabel('Giai đoạn cân'),
              const SizedBox(height: 8),
              KeyedSubtree(
                key: const ValueKey<String>('weigh-station-stage'),
                child: OptionChipGroup<WeighStationStage?>(
                  options: [
                    (null, 'Tất cả'),
                    for (final stage in WeighStationStage.values)
                      (stage, stage.label),
                  ],
                  selected: _draft.stage,
                  onChanged: (value) => setState(() => _draft.stage = value),
                ),
              ),
              const SizedBox(height: 18),
              field(
                'weigh-station-vehicle',
                'BIỂN SỐ XE',
                'Biển số xe',
                options.vehiclePlates,
                _draft.vehiclePlate,
                (value) => _draft.vehiclePlate = value,
              ),
              field(
                'weigh-station-goods',
                'TÊN HÀNG',
                'Tên hàng',
                options.goodsNames,
                _draft.goodsName,
                (value) => _draft.goodsName = value,
              ),
              field(
                'weigh-station-operator',
                'NGƯỜI CÂN',
                'Người cân',
                options.operatorNames,
                _draft.operatorName,
                (value) => _draft.operatorName = value,
              ),
              field(
                'weigh-station-unit',
                'ĐƠN VỊ',
                'Đơn vị',
                options.unitNames,
                _draft.unitName,
                (value) => _draft.unitName = value,
              ),
              field(
                'weigh-station-type',
                'KIỂU CÂN',
                'Kiểu cân',
                options.weighingTypes,
                _draft.weighingType,
                (value) => _draft.weighingType = value,
              ),
            ],
          ),
        );
      },
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

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
}) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon, size: 18),
  isDense: true,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: context.palette.text3, width: 1.25),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: context.palette.text3, width: 1.25),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: context.palette.primary, width: 1.5),
  ),
);

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-${value.year}';
