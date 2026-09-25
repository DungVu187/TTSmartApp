import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/searchable_autocomplete_field.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/presentation/widgets/company_autocomplete_field.dart';
import '../../data/models/order_report_models.dart';
import '../../data/repositories/order_report_repository.dart';
import '../controllers/order_reports_controller.dart';
import '../widgets/order_report_widgets.dart';

class OrderReportsScreen extends StatefulWidget {
  const OrderReportsScreen({
    super.key,
    required this.repository,
    required this.companyRepository,
    this.showHeading = true,
    this.now,
    this.initialStationId,
  });

  final OrderReportRepository repository;
  final CompanyRepository companyRepository;
  final bool showHeading;
  final DateTime Function()? now;
  final int? initialStationId;

  @override
  State<OrderReportsScreen> createState() => _OrderReportsScreenState();
}

class _OrderReportsScreenState extends State<OrderReportsScreen> {
  OrderReportsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (_controller != null ||
        !app.hasPermission(
          AccessFunctionCodes.orderReports,
          AccessPermission.dSach,
        )) {
      return;
    }
    final session = app.session!;
    _controller = OrderReportsController(
      repository: widget.repository,
      companyRepository: widget.companyRepository,
      isAdmin: app.hasRole('ADMIN'),
      initialCompanyId: session.user.companyId,
      initialStationId: widget.initialStationId,
      now: widget.now,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.initialize();
    // Phones have no Search button: the only station in scope loads at once.
    if (!mounted || !_isCompact) return;
    if (controller.hasLoadedReport || controller.isLoadingReport) return;
    if (controller.selectedStationId == null &&
        controller.stations.length == 1) {
      await _applyChange(
        controller,
        () => controller.selectStation(controller.stations.single.id),
      );
    }
  }

  bool get _isCompact => MediaQuery.sizeOf(context).width < 600;

  Widget? _backButton() =>
      ModalRoute.of(context)?.canPop == true ? const BackButton() : null;

  Widget _withTitleBar(Widget body, {List<Widget> actions = const []}) =>
      Column(
        children: [
          SafeArea(
            bottom: false,
            child: TabTitleBar(
              title: 'Đơn hàng',
              leading: _backButton(),
              horizontalPadding: 20,
              actions: actions,
            ),
          ),
          Expanded(child: body),
        ],
      );

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final canList = app.hasPermission(
      AccessFunctionCodes.orderReports,
      AccessPermission.dSach,
    );
    final ownTitleBar = _isCompact || !widget.showHeading;
    if (!canList) {
      final denied = ListView(
        padding: EdgeInsets.zero,
        children: const [
          AppContent(
            child: AppEmptyState(
              icon: LucideIcons.lock,
              title: 'Không có quyền xem đơn hàng',
              message:
                  'Tài khoản chưa được cấp quyền BCDH - D.Sách để xem đơn hàng.',
            ),
          ),
        ],
      );
      return ownTitleBar ? _withTitleBar(denied) : denied;
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (_isCompact) {
          return _withTitleBar(
            _buildMobileBody(controller),
            actions: [
              RoundIconButton(
                key: const ValueKey<String>('order-report-filters-button'),
                size: 40,
                icon: LucideIcons.slidersHorizontal,
                tooltip: 'Bộ lọc đơn hàng',
                badgeCount: _filterCount(controller),
                onPressed: () => _openFilters(controller),
              ),
            ],
          );
        }
        final wide = _buildWide(controller);
        return ownTitleBar ? _withTitleBar(wide) : wide;
      },
    );
  }

  Widget _buildWide(OrderReportsController controller) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 360) controller.loadMore();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () => _refresh(controller),
          child: ListView.builder(
            key: const PageStorageKey<String>('order-reports-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: controller.items.isEmpty
                ? 1
                : controller.items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return _buildHeader(controller);
              if (index <= controller.items.length) {
                final item = controller.items[index - 1];
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        MediaQuery.sizeOf(context).width >= 720 ? 24 : 12,
                        0,
                        MediaQuery.sizeOf(context).width >= 720 ? 24 : 12,
                        10,
                      ),
                      child: OrderReportItemCard(item: item),
                    ),
                  ),
                );
              }
              return _buildFooter(controller);
            },
          ),
        ),
      );

  /// Pull to refresh reloads the employee list and the orders on screen.
  Future<void> _refresh(OrderReportsController controller) async {
    await controller.refresh();
    if (controller.hasLoadedReport && controller.canSearch) {
      await controller.loadReport();
    }
  }

  // ---------------------------------------------------------------- mobile

  /// Figma "03 Orders": scope chips that reload on change, totals and the
  /// infinite order list. Every filter also lives in the C17 sheet.
  Widget _buildMobileBody(OrderReportsController controller) {
    return InfiniteListView(
      storageKey: 'order-reports-mobile-scroll',
      onLoadMore: () => unawaited(controller.loadMore()),
      onRefresh: () => _refresh(controller),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        FilterChipBar(
          children: [
            if (controller.isAdmin)
              FilterChipButton(
                size: FilterChipSize.medium,
                key: const ValueKey<String>('order-report-company-chip'),
                icon: LucideIcons.building,
                label:
                    controller.selectedCompany?.displayName ?? 'Tất cả công ty',
                showChevron: true,
                onTap: controller.isLoadingScope
                    ? null
                    : () => _pickCompany(controller),
              ),
            FilterChipButton(
              size: FilterChipSize.medium,
              key: const ValueKey<String>('order-report-date-chip'),
              icon: LucideIcons.calendar,
              label: _shortRange(controller.fromDate, controller.toDate),
              active: true,
              onTap: () => _pickDateRange(controller),
            ),
            FilterChipButton(
              size: FilterChipSize.medium,
              key: const ValueKey<String>('order-report-station-chip'),
              icon: LucideIcons.factory,
              label:
                  controller.selectedStation?.displayName ??
                  (controller.isAdmin ? 'Tất cả trạm' : 'Chọn trạm'),
              showChevron: true,
              onTap: controller.isLoadingScope || controller.stations.isEmpty
                  ? null
                  : () => _pickStation(controller),
            ),
            FilterChipButton(
              size: FilterChipSize.medium,
              key: const ValueKey<String>('order-report-employee-chip'),
              icon: LucideIcons.idCard,
              label: controller.selectedEmployeeName ?? 'Nhân viên',
              showChevron: true,
              onTap: _canPickEmployee(controller)
                  ? () => _pickEmployee(controller)
                  : null,
            ),
          ],
        ),
        if (controller.validationMessage != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(message: controller.validationMessage!),
        ],
        if (controller.scopeError != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message: controller.scopeError!.message,
            onRetry: controller.retryScope,
          ),
        ],
        if (controller.employeeError != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message:
                'Không tải được danh sách nhân viên: '
                '${controller.employeeError!.message}',
            onRetry: () => _refresh(controller),
          ),
        ],
        const SizedBox(height: 14),
        ..._mobileState(controller),
      ],
    );
  }

  List<Widget> _mobileState(OrderReportsController controller) {
    const spinner = Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(child: CircularProgressIndicator()),
    );
    if (controller.isLoadingScope && controller.stations.isEmpty) {
      return const [spinner];
    }
    if (controller.scopeError != null) return const [];
    if (controller.isLoadingReport && controller.items.isEmpty) {
      return const [spinner];
    }
    if (controller.reportError != null && controller.items.isEmpty) {
      return [
        ErrorBanner(
          message: controller.reportError!.message,
          onRetry: controller.loadReport,
        ),
      ];
    }
    if (controller.stations.isEmpty) {
      return const [
        StateView(
          icon: LucideIcons.factory,
          title: 'Không có trạm trộn phù hợp',
          message: 'Phạm vi hiện tại chưa có trạm trộn đang hoạt động.',
        ),
      ];
    }
    if (!controller.hasLoadedReport) return [_mobilePrompt(controller)];
    return _mobileResults(controller);
  }

  Widget _mobilePrompt(OrderReportsController controller) {
    final noStation = controller.selectedStationId == null;
    final mustPick = !controller.isAdmin && noStation;
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: StateView(
        icon: noStation ? LucideIcons.factory : LucideIcons.receiptText,
        title: mustPick ? 'Chọn trạm để xem đơn hàng' : 'Xem đơn hàng',
        message: mustPick
            ? 'Đơn hàng luôn được hiển thị theo một trạm cụ thể.'
            : noStation
            ? 'Chọn một trạm, hoặc xem đơn hàng của tất cả trạm trong phạm vi.'
            : 'Tải đơn hàng theo bộ lọc đang chọn.',
        actions: [
          if (noStation)
            AppButton(
              key: const ValueKey<String>('order-report-pick-station'),
              label: 'Chọn trạm',
              icon: LucideIcons.factory,
              expand: false,
              onPressed: () => _pickStation(controller),
            ),
          if (controller.canSearch)
            AppButton(
              key: const ValueKey<String>('order-report-load'),
              label: noStation ? 'Xem tất cả trạm' : 'Tải đơn hàng',
              variant: noStation
                  ? AppButtonVariant.ghost
                  : AppButtonVariant.primary,
              expand: false,
              onPressed: controller.loadReport,
            ),
        ],
      ),
    );
  }

  List<Widget> _mobileResults(OrderReportsController controller) {
    final p = context.palette;
    return [
      if (controller.isRefreshing) ...[
        const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 10),
      ],
      StatRow(
        children: [
          StatTile(
            compact: true,
            label: 'Đơn hàng',
            value: _formatCount(controller.totalCount),
          ),
          StatTile(
            compact: true,
            label: 'KL đặt',
            value: formatOrderReportVolume(controller.totalOrderedVolume),
            unit: 'm³',
          ),
          StatTile(
            compact: true,
            label: 'Đã sản xuất',
            value: formatOrderReportVolume(controller.totalProducedVolume),
            unit: 'm³',
            valueColor: p.success,
          ),
        ],
      ),
      if (controller.isPartial) ...[
        const SizedBox(height: 12),
        WarningBanner(
          key: const ValueKey<String>('order-report-partial-warning'),
          title:
              'Không thể tải dữ liệu từ '
              '${controller.unavailableStationCount} trạm',
          // Same as web: only the count, no per-station list.
          items: const [],
        ),
      ],
      const SizedBox(height: 14),
      if (controller.items.isEmpty)
        const StateView(
          icon: LucideIcons.searchX,
          title: 'Không có đơn hàng',
          message: 'Thử đổi khoảng ngày hoặc bỏ lọc nhân viên kinh doanh.',
        )
      else ...[
        for (final item in controller.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OrderCard(
              item: item,
              showCompany:
                  controller.isAdmin && controller.selectedCompanyId == null,
            ),
          ),
        LoadMoreFooter(
          loading: controller.isLoadingMore,
          errorMessage: controller.loadMoreError?.message,
          onRetry: controller.loadMore,
        ),
      ],
    ];
  }

  int _filterCount(OrderReportsController controller) => [
    if (controller.isAdmin) controller.selectedCompanyId,
    if (controller.isAdmin) controller.selectedStationId,
    controller.selectedEmployeeName,
  ].where((value) => value != null).length;

  bool _canPickEmployee(OrderReportsController controller) =>
      controller.selectedStationId != null &&
      !controller.isLoadingEmployees &&
      controller.employees.isNotEmpty;

  /// Applies one filter change; on phones the list then reloads by itself
  /// (unless [reload] is false, e.g. while the C17 sheet is still open).
  Future<void> _applyChange(
    OrderReportsController controller,
    Future<void> Function() apply, {
    bool? hadResult,
    bool reload = true,
  }) async {
    final wasLoaded = hadResult ?? controller.hasLoadedReport;
    // Synchronous part of [apply] updates the scope; slow option lists
    // (employees) finish in parallel with the report request.
    final applying = apply();
    if (reload && _shouldReload(controller, wasLoaded)) {
      await controller.loadReport();
    }
    await applying;
  }

  /// Admins without a station would query every station, so that only
  /// happens after an explicit "Xem tất cả trạm" / Tìm kiếm or when a result
  /// was already on screen.
  bool _shouldReload(OrderReportsController controller, bool hadResult) =>
      controller.canSearch &&
      (hadResult || controller.selectedStationId != null);

  Future<void> _pickCompany(
    OrderReportsController controller, {
    bool reload = true,
  }) async {
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn công ty',
      searchHint: 'Tìm công ty',
      icon: LucideIcons.building,
      clearLabel: 'Tất cả công ty',
      selected: controller.selectedCompanyId,
      options: [
        for (final company in controller.companies)
          PickerOption(value: company.id, title: company.displayName),
      ],
    );
    if (!mounted || picked == null) return;
    await _applyCompany(controller, picked.value, reload: reload);
  }

  Future<void> _applyCompany(
    OrderReportsController controller,
    int? companyId, {
    bool reload = true,
  }) async {
    if (companyId == controller.selectedCompanyId) return;
    final hadResult = controller.hasLoadedReport;
    await controller.selectCompany(companyId);
    if (!mounted) return;
    if (controller.stations.length == 1) {
      await _applyChange(
        controller,
        () => controller.selectStation(controller.stations.single.id),
        hadResult: hadResult,
        reload: reload,
      );
    } else if (reload && _shouldReload(controller, hadResult)) {
      await controller.loadReport();
    }
  }

  Future<void> _pickStation(
    OrderReportsController controller, {
    bool reload = true,
  }) async {
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn trạm',
      searchHint: 'Tìm trạm',
      icon: LucideIcons.factory,
      clearLabel: controller.isAdmin ? 'Tất cả trạm' : null,
      selected: controller.selectedStationId,
      emptyMessage: 'Không có trạm trong phạm vi được cấp.',
      options: [
        for (final station in controller.stations)
          PickerOption(
            value: station.id,
            title: station.displayName,
            subtitle: controller.isAdmin ? station.companyName : null,
          ),
      ],
    );
    if (!mounted || picked == null) return;
    await _applyStation(controller, picked.value, reload: reload);
  }

  Future<void> _applyStation(
    OrderReportsController controller,
    int? stationId, {
    bool reload = true,
  }) async {
    if (stationId == controller.selectedStationId) return;
    if (stationId == null && !controller.isAdmin) return;
    await _applyChange(
      controller,
      () => controller.selectStation(stationId),
      reload: reload,
    );
  }

  Future<void> _pickEmployee(
    OrderReportsController controller, {
    bool reload = true,
  }) async {
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Chọn nhân viên',
      searchHint: 'Tìm nhân viên',
      icon: LucideIcons.idCard,
      clearLabel: 'Tất cả nhân viên',
      selected: controller.selectedEmployeeName,
      options: [
        for (final employee in controller.employees)
          PickerOption(value: employee.name, title: employee.name),
      ],
    );
    if (!mounted || picked == null) return;
    await _applyEmployee(controller, picked.value, reload: reload);
  }

  Future<void> _applyEmployee(
    OrderReportsController controller,
    String? name, {
    bool reload = true,
  }) async {
    if (name == controller.selectedEmployeeName) return;
    await _applyChange(
      controller,
      () async => controller.setEmployeeName(name),
      reload: reload,
    );
  }

  Future<void> _openFilters(OrderReportsController controller) async {
    String snapshot() =>
        '${controller.selectedCompanyId}|${controller.selectedStationId}|'
        '${controller.selectedEmployeeName}|${controller.fromDate}|'
        '${controller.toDate}';
    final before = snapshot();
    final hadResult = controller.hasLoadedReport;
    final searched = await showAppModalSheet<bool>(
      context: context,
      builder: (_) => _OrderFiltersSheet(host: this, controller: controller),
    );
    if (!mounted) return;
    if (searched == true) {
      if (controller.canSearch) await controller.loadReport();
    } else if (snapshot() != before && _shouldReload(controller, hadResult)) {
      await controller.loadReport();
    }
  }

  Widget _buildHeader(OrderReportsController controller) {
    return AppContent(
      maxWidth: 960,
      topPadding: 12,
      horizontalPadding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeading) ...[
            const _OrderReportIntro(),
            const SizedBox(height: 12),
          ],
          _OrderReportFilters(
            controller: controller,
            onPickDateRange: () => _pickDateRange(controller),
          ),
          if (controller.validationMessage != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(message: controller.validationMessage!),
          ],
          if (controller.scopeError != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(
              message: controller.scopeError!.message,
              onRetry: controller.retryScope,
            ),
          ],
          if (controller.employeeError != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(
              message:
                  'Không tải được danh sách nhân viên: '
                  '${controller.employeeError!.message}',
              onRetry: controller.refresh,
            ),
          ],
          if (controller.isRefreshing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 20),
          _buildReportState(controller),
        ],
      ),
    );
  }

  Widget _buildReportState(OrderReportsController controller) {
    if (controller.isLoadingScope && controller.stations.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.scopeError != null) return const SizedBox.shrink();
    if (controller.isLoadingReport && controller.items.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.reportError != null && controller.items.isEmpty) {
      return ErrorPanel(
        message: controller.reportError!.message,
        onRetry: controller.loadReport,
      );
    }
    if (!controller.isLoadingScope && controller.stations.isEmpty) {
      return const AppEmptyState(
        icon: LucideIcons.factory,
        title: 'Không có trạm trộn phù hợp',
        message: 'Phạm vi hiện tại chưa có trạm trộn đang hoạt động.',
      );
    }
    if (!controller.isAdmin && controller.selectedStationId == null) {
      return const AppEmptyState(
        icon: LucideIcons.factory,
        title: 'Chọn trạm để xem đơn hàng',
        message: 'Đơn hàng luôn được hiển thị theo một trạm cụ thể.',
      );
    }
    if (!controller.hasLoadedReport) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        controller.isAdmin
            ? _ScopeBannerV2(controller: controller)
            : _ScopeBanner(controller: controller),
        if (controller.isPartial) ...[
          const SizedBox(height: 12),
          OrderReportPartialWarning(
            unavailableStationCount: controller.unavailableStationCount,
          ),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: compact ? 8 : 12,
              mainAxisSpacing: compact ? 8 : 12,
              mainAxisExtent: compact ? 174 : 180,
              children: [
                OrderReportMetricCard(
                  icon: LucideIcons.receiptText,
                  label: 'Tổng đơn hàng',
                  value: '${controller.totalCount}',
                  caption: 'Trong khoảng thời gian đã chọn',
                ),
                OrderReportMetricCard(
                  icon: LucideIcons.shoppingCart,
                  label: 'Khối lượng đặt',
                  value:
                      '${formatOrderReportVolume(controller.totalOrderedVolume)} m³',
                  caption: 'Tính trên toàn bộ kết quả',
                  accentColor: context.palette.warning,
                ),
                OrderReportMetricCard(
                  icon: LucideIcons.factory,
                  label: 'Khối lượng sản xuất',
                  value:
                      '${formatOrderReportVolume(controller.totalProducedVolume)} m³',
                  caption: 'Tính trên toàn bộ kết quả',
                  accentColor: context.palette.success,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        AppSectionHeader(
          title: 'Danh sách đơn hàng',
          subtitle: controller.totalCount == 0
              ? 'Không có dữ liệu trong kỳ đã chọn'
              : 'Đã hiển thị ${controller.items.length}/${controller.totalCount} đơn',
        ),
        if (controller.items.isEmpty) ...[
          const SizedBox(height: 12),
          const Card(
            child: AppEmptyState(
              icon: LucideIcons.searchX,
              title: 'Không có đơn hàng',
              message: 'Thử đổi khoảng ngày hoặc bỏ lọc nhân viên kinh doanh.',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(OrderReportsController controller) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ErrorPanel(
              message: controller.loadMoreError!.message,
              onRetry: controller.loadMore,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Future<void> _pickDateRange(
    OrderReportsController controller, {
    bool reload = true,
  }) async {
    final selected = await showAppDateRangePicker(
      context: context,
      initialStart: controller.fromDate,
      initialEnd: controller.toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      title: 'Chọn khoảng thời gian',
      keyPrefix: 'order-report-date',
    );
    if (!mounted || selected == null) return;
    final range = DateTimeRangeValue(start: selected.start, end: selected.end);
    if (_isCompact) {
      await _applyChange(
        controller,
        () => controller.setDateRange(range),
        reload: reload,
      );
      return;
    }
    final hadResult = controller.hasLoadedReport;
    await controller.setDateRange(range);
    if (hadResult) await controller.loadReport();
  }
}

String _two(int number) => number.toString().padLeft(2, '0');

String _shortRange(DateTime start, DateTime end) =>
    '${_two(start.day)}/${_two(start.month)} – ${_two(end.day)}/${_two(end.month)}';

String _formatDate(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year}';

String _formatCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// One order of the phone list (Figma "03 Orders").
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.item, required this.showCompany});

  final OrderReportItem item;
  final bool showCompany;

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final orderedAt = item.orderedAtUtc?.toUtc().add(const Duration(hours: 7));
    final ordered = item.orderedVolume ?? 0;
    final produced = item.producedVolume ?? 0;
    final tags = <(IconData, String)>[
      if (showCompany && _text(item.companyName) != null)
        (LucideIcons.building, _text(item.companyName)!),
      (LucideIcons.mapPin, item.stationDisplayName),
      if (_text(item.projectName) != null)
        (LucideIcons.building, _text(item.projectName)!),
      if (_text(item.concreteGradeName) != null)
        (LucideIcons.flaskConical, _text(item.concreteGradeName)!),
      if (_text(item.employeeName) != null)
        (LucideIcons.idCard, _text(item.employeeName)!),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(
                icon: LucideIcons.receiptText,
                size: 42,
                radius: 13,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đơn #${item.orderId}',
                      style: TextStyle(
                        color: p.text1,
                        fontSize: 15,
                        height: 18 / 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _text(item.customerName) ?? 'Chưa có khách hàng',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text2,
                        fontSize: 13,
                        height: 16 / 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    orderedAt == null
                        ? 'Chưa có ngày'
                        : '${_two(orderedAt.day)}/${_two(orderedAt.month)}',
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 14,
                      height: 17 / 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (orderedAt != null)
                    Text(
                      '${_two(orderedAt.hour)}:${_two(orderedAt.minute)}',
                      style: TextStyle(
                        color: p.text2,
                        fontSize: 12,
                        height: 15 / 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (icon, label) in tags)
                _OrderTag(icon: icon, label: label),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: VolumeBox(
                  compact: true,
                  label: 'Khối lượng đặt',
                  value: '${formatOrderReportVolume(item.orderedVolume)} m³',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VolumeBox(
                  compact: true,
                  label: 'Đã sản xuất',
                  value: '${formatOrderReportVolume(item.producedVolume)} m³',
                  tone: AppTone.success,
                ),
              ),
            ],
          ),
          if (ordered > 0) ...[
            const SizedBox(height: 12),
            Semantics(
              label:
                  'Đã sản xuất ${(produced / ordered * 100).round()}% '
                  'khối lượng đặt',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (produced / ordered).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  color: p.success,
                  backgroundColor: p.surfaceMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grey 26px tag of the order card (station, project, grade, employee).
class _OrderTag extends StatelessWidget {
  const _OrderTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: p.text2),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.text2,
                fontSize: 12,
                height: 14 / 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma C17: every order filter in one sheet. Changes apply to the
/// controller at once (stations and employees depend on them); the list
/// reloads when the sheet closes.
class _OrderFiltersSheet extends StatelessWidget {
  const _OrderFiltersSheet({required this.host, required this.controller});

  final _OrderReportsScreenState host;
  final OrderReportsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final noStation = controller.selectedStationId == null;
        Widget field(Widget child) =>
            Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
        return AppSheetFrame(
          title: 'Bộ lọc đơn hàng',
          footer: Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const ValueKey<String>('order-report-filter-reset'),
                  label: 'Đặt lại',
                  variant: AppButtonVariant.ghost,
                  onPressed: controller.isLoadingScope
                      ? null
                      : controller.resetFilters,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  key: const ValueKey<String>('order-report-filter-search'),
                  label: 'Tìm kiếm',
                  icon: LucideIcons.search,
                  onPressed: controller.canSearch
                      ? () => Navigator.of(context).pop(true)
                      : null,
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.isLoadingScope ||
                  controller.isLoadingEmployees) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
              ],
              if (controller.isAdmin)
                field(
                  SelectFieldButton(
                    key: const ValueKey<String>('order-report-filter-company'),
                    label: 'CÔNG TY',
                    placeholder: 'Tất cả công ty',
                    value: controller.selectedCompany?.displayName,
                    enabled: !controller.isLoadingScope,
                    onTap: () => host._pickCompany(controller, reload: false),
                    onClear: controller.selectedCompanyId == null
                        ? null
                        : () => host._applyCompany(
                            controller,
                            null,
                            reload: false,
                          ),
                  ),
                ),
              field(
                SelectFieldButton(
                  key: const ValueKey<String>('order-report-filter-station'),
                  label: 'TRẠM',
                  placeholder: controller.stations.isEmpty
                      ? 'Không có dữ liệu'
                      : controller.isAdmin
                      ? 'Tất cả trạm'
                      : 'Chọn trạm',
                  value: controller.selectedStation?.displayName,
                  enabled:
                      !controller.isLoadingScope &&
                      controller.stations.isNotEmpty,
                  onTap: () => host._pickStation(controller, reload: false),
                  onClear: controller.isAdmin && !noStation
                      ? () =>
                            host._applyStation(controller, null, reload: false)
                      : null,
                ),
              ),
              field(
                SelectFieldButton(
                  key: const ValueKey<String>('order-report-filter-employee'),
                  label: 'NHÂN VIÊN',
                  placeholder: noStation
                      ? 'Chọn trạm trước'
                      : controller.employees.isEmpty &&
                            !controller.isLoadingEmployees
                      ? 'Không có dữ liệu'
                      : 'Tất cả nhân viên',
                  value: controller.selectedEmployeeName,
                  enabled: host._canPickEmployee(controller),
                  onTap: () => host._pickEmployee(controller, reload: false),
                  onClear: controller.selectedEmployeeName == null
                      ? null
                      : () => host._applyEmployee(
                          controller,
                          null,
                          reload: false,
                        ),
                ),
              ),
              field(
                SelectFieldButton(
                  key: const ValueKey<String>('order-report-filter-date'),
                  label: 'THỜI GIAN',
                  placeholder: 'Chọn khoảng thời gian',
                  icon: LucideIcons.calendar,
                  trailingIcon: LucideIcons.chevronRight,
                  value:
                      '${_formatDate(controller.fromDate)} – '
                      '${_formatDate(controller.toDate)}',
                  onTap: () => host._pickDateRange(controller, reload: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderReportIntro extends StatelessWidget {
  const _OrderReportIntro();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Đơn hàng',
        style: TextStyle(
          color: context.palette.text1,
          fontSize: 19,
          height: 24 / 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        'Tổng hợp đơn đặt và khối lượng sản xuất theo từng trạm',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.palette.text2,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );
}

class _OrderReportFilters extends StatelessWidget {
  const _OrderReportFilters({
    required this.controller,
    required this.onPickDateRange,
  });

  final OrderReportsController controller;
  final VoidCallback onPickDateRange;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      if (controller.isAdmin) _companyField(context),
      _stationField(context),
      _dateRangeField(context),
      _employeeField(context),
    ];
    return Card(
      key: const ValueKey('order-report-filters'),
      margin: EdgeInsets.zero,
      color: context.palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 720) return _wideFilterRows(fields);
                final children = <Widget>[];
                for (var index = 0; index < fields.length; index++) {
                  if (index > 0) children.add(const SizedBox(height: 8));
                  children.add(fields[index]);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                );
              },
            ),
            if (controller.isLoadingScope || controller.isLoadingEmployees) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 10),
            _filterActions(context),
          ],
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

  Widget _filterActions(BuildContext context) {
    final searchButton = SizedBox(
      height: 38,
      child: FilledButton.icon(
        key: const ValueKey('order-report-submit'),
        onPressed: !controller.canSearch || controller.isLoadingReport
            ? null
            : controller.loadReport,
        style: FilledButton.styleFrom(
          backgroundColor: context.palette.primary,
          foregroundColor: context.palette.onPrimary,
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
        icon: controller.isLoadingReport
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.palette.onPrimary,
                ),
              )
            : const Icon(LucideIcons.search, size: 16),
        label: const Text('Tìm kiếm'),
      ),
    );
    final resetButton = SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        key: const ValueKey('order-report-reset'),
        onPressed: controller.isLoadingScope || controller.isLoadingReport
            ? null
            : controller.resetFilters,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.palette.primary,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: context.palette.border),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        icon: const Icon(LucideIcons.refreshCw, size: 16),
        label: const Text('Đặt lại'),
      ),
    );
    return Row(
      children: [
        Expanded(flex: 5, child: searchButton),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: resetButton),
      ],
    );
  }

  Widget _companyField(BuildContext context) => SizedBox(
    height: 38,
    child: CompanyAutocompleteField(
      key: ValueKey(
        'order-report-company-${controller.selectedCompanyId}-'
        '${controller.companies.length}',
      ),
      companies: controller.companies,
      selectedCompanyId: controller.selectedCompanyId,
      enabled: !controller.isLoadingScope,
      hintText: 'Tất cả công ty',
      labelText: 'Công ty',
      compact: true,
      borderColor: context.palette.fieldBorder,
      borderWidth: 1.25,
      onSelected: (company) async {
        final hadResult = controller.hasLoadedReport;
        await controller.selectCompany(company.id);
        if (hadResult) await controller.loadReport();
      },
      onCleared: () async {
        final hadResult = controller.hasLoadedReport;
        await controller.selectCompany(null);
        if (hadResult) await controller.loadReport();
      },
    ),
  );

  Widget _stationField(BuildContext context) => SizedBox(
    height: 38,
    child: SearchableAutocompleteField<OrderReportStation>(
      key: ValueKey(
        'order-report-station-${controller.selectedStationId}-'
        '${controller.stations.length}',
      ),
      options: controller.stations,
      selectedOption: controller.selectedStation,
      displayStringForOption: (station) => station.displayName,
      searchStringForOption: (station) => station.scopedDisplayName,
      optionSubtitle: controller.isAdmin
          ? (station) => station.companyName?.trim()
          : null,
      onSelected: (station) async {
        final hadResult = controller.hasLoadedReport;
        await controller.selectStation(station.id);
        if (hadResult) await controller.loadReport();
      },
      onCleared: controller.isAdmin
          ? () async {
              final hadResult = controller.hasLoadedReport;
              await controller.selectStation(null);
              if (hadResult) await controller.loadReport();
            }
          : null,
      enabled: !controller.isLoadingScope && controller.stations.isNotEmpty,
      loading: controller.isLoadingScope,
      hintText: controller.stations.isEmpty
          ? 'Không có dữ liệu'
          : controller.isAdmin
          ? 'Tất cả trạm'
          : 'Chọn trạm',
      labelText: 'Trạm',
      prefixIcon: LucideIcons.factory,
      compact: true,
      borderColor: context.palette.fieldBorder,
      borderWidth: 1.25,
    ),
  );

  Widget _employeeField(BuildContext context) {
    final employeeNames = controller.employees
        .map((employee) => employee.name)
        .toList(growable: false);
    final selectedEmployee =
        employeeNames.contains(controller.selectedEmployeeName)
        ? controller.selectedEmployeeName
        : null;
    return SizedBox(
      height: 38,
      child: SearchableAutocompleteField<String>(
        key: ValueKey(
          'order-report-employee-${controller.selectedEmployeeName}-'
          '${controller.employees.length}',
        ),
        options: employeeNames,
        selectedOption: selectedEmployee,
        displayStringForOption: (employee) => employee,
        onSelected: (employee) {
          final hadResult = controller.hasLoadedReport;
          controller.setEmployeeName(employee);
          if (hadResult) unawaited(controller.loadReport());
        },
        onCleared: () {
          final hadResult = controller.hasLoadedReport;
          controller.setEmployeeName(null);
          if (hadResult) unawaited(controller.loadReport());
        },
        enabled:
            controller.selectedStationId != null &&
            !controller.isLoadingEmployees &&
            employeeNames.isNotEmpty,
        loading: controller.isLoadingEmployees,
        hintText: employeeNames.isEmpty
            ? 'Không có dữ liệu'
            : 'Tất cả nhân viên',
        labelText: 'Nhân viên',
        prefixIcon: LucideIcons.idCard,
        compact: true,
        borderColor: context.palette.fieldBorder,
        borderWidth: 1.25,
      ),
    );
  }

  Widget _dateRangeField(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Semantics(
        button: true,
        label: 'Chọn khoảng ngày đơn hàng',
        child: InkWell(
          key: const ValueKey('order-report-date-range'),
          borderRadius: BorderRadius.circular(10),
          onTap: onPickDateRange,
          child: InputDecorator(
            decoration: _compactDecoration(
              context,
              label: 'Thời gian',
              icon: LucideIcons.calendar,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatDateTime(controller.fromDate)} - '
                    '${_formatDateTime(controller.toDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.text1,
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
  }

  InputDecoration _compactDecoration(
    BuildContext context, {
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
    fillColor: context.palette.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.palette.fieldBorder, width: 1.25),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.palette.fieldBorder, width: 1.25),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.palette.primary, width: 1.5),
    ),
    hintStyle: TextStyle(
      color: context.palette.text3,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400,
    ),
    labelStyle: TextStyle(
      color: context.palette.text1,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: TextStyle(
      color: context.palette.text1,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    ),
  );

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _ScopeBannerV2 extends StatelessWidget {
  const _ScopeBannerV2({required this.controller});

  final OrderReportsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final company = controller.selectedCompany;
    final station = controller.selectedStation;
    final scope = station != null
        ? '${company?.displayName ?? 'Tất cả công ty'} • ${station.displayName}'
        : company == null
        ? 'Tất cả công ty • tất cả trạm'
        : '${company.displayName} • tất cả trạm';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.shield, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Phạm vi: $scope',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({required this.controller});

  final OrderReportsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final station = controller.selectedStation;
    final company = controller.selectedCompany;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.shield, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              company == null
                  ? 'Phạm vi: ${station?.displayName ?? 'Chưa chọn trạm'}'
                  : 'Phạm vi: ${company.displayName} • '
                        '${station?.displayName ?? 'Chưa chọn trạm'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
