import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/searchable_autocomplete_field.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/presentation/widgets/company_autocomplete_field.dart';
import '../../data/models/mix_design_models.dart';
import '../../data/repositories/mix_design_repository.dart';
import '../controllers/mix_designs_controller.dart';
import '../widgets/mix_design_widgets.dart';

class MixDesignsScreen extends StatefulWidget {
  const MixDesignsScreen({
    super.key,
    required this.repository,
    required this.companyRepository,
  });

  final MixDesignRepository repository;
  final CompanyRepository companyRepository;

  @override
  State<MixDesignsScreen> createState() => _MixDesignsScreenState();
}

class _MixDesignsScreenState extends State<MixDesignsScreen> {
  MixDesignsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (_controller != null ||
        !app.hasPermission(
          AccessFunctionCodes.mixDesigns,
          AccessPermission.dSach,
        )) {
      return;
    }
    _controller = MixDesignsController(
      widget.repository,
      widget.companyRepository,
      isAdmin: app.hasRole('ADMIN'),
      initialCompanyId: app.session?.user.companyId,
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
      AccessFunctionCodes.mixDesigns,
      AccessPermission.dSach,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý cấp phối')),
      body: SafeArea(
        child: !canList
            ? const AppContent(
                maxWidth: 720,
                child: Card(
                  child: AppEmptyState(
                    icon: Icons.lock_outline,
                    title: 'Không có quyền xem cấp phối',
                    message:
                        'Tài khoản chưa được cấp quyền QLCP - D.Sách để sử dụng chức năng này.',
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
      builder: (context, _) => RefreshIndicator(
        onRefresh: controller.result == null
            ? controller.retryStations
            : controller.retryResult,
        child: ListView(
          key: const PageStorageKey<String>('mix-designs-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            AppContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilters(controller),
                  if (controller.scopeError != null) ...[
                    const SizedBox(height: 12),
                    ErrorPanel(
                      message: controller.scopeError!.message,
                      onRetry: controller.retryScope,
                    ),
                  ],
                  if (controller.validationMessage != null) ...[
                    const SizedBox(height: 12),
                    ErrorPanel(message: controller.validationMessage!),
                  ],
                  const SizedBox(height: 18),
                  _buildResults(controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(MixDesignsController controller) {
    return Card(
      key: const ValueKey<String>('mix-design-filters'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final fields = <Widget>[
              if (controller.isAdmin) _companyField(controller),
              _stationField(controller),
            ];
            final filterFields = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        if (index > 0) const SizedBox(width: 10),
                        Expanded(child: fields[index]),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        if (index > 0) const SizedBox(height: 10),
                        fields[index],
                      ],
                    ],
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                filterFields,
                const SizedBox(height: 12),
                if (wide)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _searchButton(controller),
                      const SizedBox(width: 10),
                      _resetButton(controller),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(flex: 2, child: _searchButton(controller)),
                      const SizedBox(width: 10),
                      Expanded(child: _resetButton(controller)),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _companyField(MixDesignsController controller) {
    return CompanyAutocompleteField(
      key: ValueKey<String>(
        'mix-design-company-${controller.selectedCompanyId}-${controller.companies.length}',
      ),
      companies: controller.companies,
      selectedCompanyId: controller.selectedCompanyId,
      onSelected: (company) => controller.selectCompany(company.id),
      onCleared: () => controller.selectCompany(null),
      enabled: !controller.isLoadingCompanies,
      compact: true,
      hintText: controller.isLoadingCompanies
          ? 'Đang tải công ty...'
          : 'Chọn công ty',
    );
  }

  Widget _stationField(MixDesignsController controller) {
    return SearchableAutocompleteField<MixDesignStation>(
      key: ValueKey<String>(
        'mix-design-station-${controller.selectedStationId}-${controller.stations.length}',
      ),
      options: controller.stations,
      selectedOption: controller.selectedStation,
      displayStringForOption: (station) => station.displayName,
      searchStringForOption: (station) =>
          '${station.displayName} ${station.id}',
      optionSubtitle: (station) => 'Mã trạm ${station.id}',
      onSelected: (station) => controller.selectStation(station.id),
      onCleared: () => controller.selectStation(null),
      enabled:
          !controller.isLoadingStations &&
          (!controller.isAdmin || controller.selectedCompanyId != null) &&
          controller.stations.isNotEmpty,
      loading: controller.isLoadingStations,
      hintText: _stationHint(controller),
      labelText: 'Trạm',
      prefixIcon: Icons.factory_outlined,
      compact: true,
    );
  }

  String _stationHint(MixDesignsController controller) {
    if (controller.isAdmin && controller.selectedCompanyId == null) {
      return 'Chọn công ty trước';
    }
    if (controller.isLoadingStations) return 'Đang tải trạm...';
    if (controller.stations.isEmpty) return 'Không có trạm phù hợp';
    return 'Chọn trạm';
  }

  Widget _searchButton(MixDesignsController controller) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        key: const ValueKey<String>('mix-design-search'),
        onPressed: controller.isLoadingResult ? null : controller.search,
        icon: controller.isLoadingResult
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.search, size: 18),
        label: const Text('Tìm kiếm'),
      ),
    );
  }

  Widget _resetButton(MixDesignsController controller) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        key: const ValueKey<String>('mix-design-reset'),
        onPressed: controller.isLoadingResult ? null : controller.resetFilters,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Đặt lại'),
      ),
    );
  }

  Widget _buildResults(MixDesignsController controller) {
    final result = controller.result;
    if (controller.isLoadingResult && result == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (result == null && controller.resultError != null) {
      return ErrorPanel(
        message: controller.resultError!.message,
        onRetry: controller.search,
      );
    }
    if (result == null) {
      return const Card(
        child: AppEmptyState(
          icon: Icons.table_chart_outlined,
          title: 'Chưa tải danh sách cấp phối',
          message:
              'Chọn phạm vi công ty, trạm rồi bấm Tìm kiếm để xem dữ liệu.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.resultError != null) ...[
          ErrorPanel(
            message: controller.resultError!.message,
            onRetry: controller.retryResult,
          ),
          const SizedBox(height: 12),
        ],
        MixDesignOverviewCard(
          page: result,
          stationName:
              controller.selectedStation?.displayName ?? 'Trạm đã chọn',
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            MixDesignResultsTable(page: result),
            if (controller.isLoadingResult)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        MixDesignPagination(
          currentPage: result.pageNumber,
          totalPages: result.totalPages,
          canGoFirst: controller.canGoFirst,
          canGoPrevious: controller.canGoPrevious,
          canGoNext: controller.canGoNext,
          canGoLast: controller.canGoLast,
          onFirst: controller.goToFirstPage,
          onPrevious: controller.goToPreviousPage,
          onNext: controller.goToNextPage,
          onLast: controller.goToLastPage,
        ),
      ],
    );
  }
}
