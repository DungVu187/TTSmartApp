import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/theme/app_theme.dart';
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

abstract final class _OrderReportDesign {
  static const blue = Color(0xFF2563EB);
  static const border = Color(0xFFE5E7EB);
  static const fieldBorder = Color(0xFFCBD5E1);
  static const fieldBorderWidth = 1.25;
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const label = Color(0xFF374151);
}

class OrderReportsScreen extends StatefulWidget {
  const OrderReportsScreen({
    super.key,
    required this.repository,
    required this.companyRepository,
    this.now,
  });

  final OrderReportRepository repository;
  final CompanyRepository companyRepository;
  final DateTime Function()? now;

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
      now: widget.now,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller?.initialize();
    });
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
      AccessFunctionCodes.orderReports,
      AccessPermission.dSach,
    );
    if (!canList) {
      return ListView(
        padding: EdgeInsets.zero,
        children: const [
          AppContent(
            child: AppEmptyState(
              icon: Icons.lock_outline,
              title: 'Không có quyền xem đơn hàng',
              message:
                  'Tài khoản chưa được cấp quyền BCDH - D.Sách để xem đơn hàng.',
            ),
          ),
        ],
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 360) controller.loadMore();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: controller.refresh,
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
      ),
    );
  }

  Widget _buildHeader(OrderReportsController controller) {
    return AppContent(
      maxWidth: 960,
      topPadding: 12,
      horizontalPadding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OrderReportIntro(),
          const SizedBox(height: 12),
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
        icon: Icons.factory_outlined,
        title: 'Không có trạm trộn phù hợp',
        message: 'Phạm vi hiện tại chưa có trạm trộn đang hoạt động.',
      );
    }
    if (!controller.isAdmin && controller.selectedStationId == null) {
      return const AppEmptyState(
        icon: Icons.factory_outlined,
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
                  icon: Icons.receipt_long_outlined,
                  label: 'Tổng đơn hàng',
                  value: '${controller.totalCount}',
                  caption: 'Trong khoảng thời gian đã chọn',
                ),
                OrderReportMetricCard(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Khối lượng đặt',
                  value:
                      '${formatOrderReportVolume(controller.totalOrderedVolume)} m³',
                  caption: 'Tính trên toàn bộ kết quả',
                  accentColor: AppColors.warning,
                ),
                OrderReportMetricCard(
                  icon: Icons.precision_manufacturing_outlined,
                  label: 'Khối lượng sản xuất',
                  value:
                      '${formatOrderReportVolume(controller.totalProducedVolume)} m³',
                  caption: 'Tính trên toàn bộ kết quả',
                  accentColor: AppColors.success,
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
              icon: Icons.search_off_outlined,
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

  Future<void> _pickDateRange(OrderReportsController controller) async {
    final selected = await showAppDateRangePicker(
      context: context,
      initialStart: controller.fromDate,
      initialEnd: controller.toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      title: 'Chọn khoảng thời gian',
      keyPrefix: 'order-report-date',
    );
    if (selected == null) return;
    await controller.setDateRange(
      DateTimeRangeValue(start: selected.start, end: selected.end),
    );
  }
}

class _OrderReportIntro extends StatelessWidget {
  const _OrderReportIntro();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Đơn hàng',
        style: TextStyle(
          color: _OrderReportDesign.textPrimary,
          fontSize: 19,
          height: 24 / 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        'Tổng hợp đơn đặt và khối lượng sản xuất theo từng trạm',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _OrderReportDesign.textSecondary,
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
      if (controller.isAdmin) _companyField(),
      _stationField(),
      _dateRangeField(context),
      _employeeField(),
    ];
    return Card(
      key: const ValueKey('order-report-filters'),
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _OrderReportDesign.border),
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
            _filterActions(),
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

  Widget _filterActions() {
    final searchButton = SizedBox(
      height: 38,
      child: FilledButton.icon(
        key: const ValueKey('order-report-submit'),
        onPressed: !controller.canSearch || controller.isLoadingReport
            ? null
            : controller.loadReport,
        style: FilledButton.styleFrom(
          backgroundColor: _OrderReportDesign.blue,
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
        icon: controller.isLoadingReport
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.search_outlined, size: 16),
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
          foregroundColor: _OrderReportDesign.blue,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: _OrderReportDesign.border),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        icon: const Icon(Icons.refresh_rounded, size: 16),
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

  Widget _companyField() => SizedBox(
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
      borderColor: _OrderReportDesign.fieldBorder,
      borderWidth: _OrderReportDesign.fieldBorderWidth,
      onSelected: (company) => controller.selectCompany(company.id),
      onCleared: () => controller.selectCompany(null),
    ),
  );

  Widget _stationField() => SizedBox(
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
      onSelected: (station) => controller.selectStation(station.id),
      onCleared: controller.isAdmin
          ? () => controller.selectStation(null)
          : null,
      enabled: !controller.isLoadingScope && controller.stations.isNotEmpty,
      loading: controller.isLoadingScope,
      hintText: controller.stations.isEmpty
          ? 'Không có dữ liệu'
          : controller.isAdmin
          ? 'Tất cả trạm'
          : 'Chọn trạm',
      labelText: 'Trạm',
      prefixIcon: Icons.factory_outlined,
      compact: true,
      borderColor: _OrderReportDesign.fieldBorder,
      borderWidth: _OrderReportDesign.fieldBorderWidth,
    ),
  );

  Widget _employeeField() {
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
        onSelected: controller.setEmployeeName,
        onCleared: () => controller.setEmployeeName(null),
        enabled:
            controller.selectedStationId != null &&
            !controller.isLoadingEmployees &&
            employeeNames.isNotEmpty,
        loading: controller.isLoadingEmployees,
        hintText: employeeNames.isEmpty
            ? 'Không có dữ liệu'
            : 'Tất cả nhân viên',
        labelText: 'Nhân viên',
        prefixIcon: Icons.badge_outlined,
        compact: true,
        borderColor: _OrderReportDesign.fieldBorder,
        borderWidth: _OrderReportDesign.fieldBorderWidth,
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
              label: 'Thời gian',
              icon: Icons.calendar_month_outlined,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatDateTime(controller.fromDate)} - '
                    '${_formatDateTime(controller.toDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _OrderReportDesign.textPrimary,
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
        color: _OrderReportDesign.fieldBorder,
        width: _OrderReportDesign.fieldBorderWidth,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: _OrderReportDesign.fieldBorder,
        width: _OrderReportDesign.fieldBorderWidth,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _OrderReportDesign.blue, width: 1.5),
    ),
    hintStyle: const TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400,
    ),
    labelStyle: const TextStyle(
      color: _OrderReportDesign.label,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      color: _OrderReportDesign.label,
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
          Icon(
            Icons.shield_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
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
          Icon(
            Icons.shield_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
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
