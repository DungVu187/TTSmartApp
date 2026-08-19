import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/searchable_autocomplete_field.dart';
import '../../data/models/dashboard_models.dart';
import '../controllers/home_controller.dart';
import '../widgets/dashboard_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.onOpenOrders,
    this.onOpenStatistics,
  });

  final HomeController controller;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenStatistics;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayName = AppScope.of(context).session!.user.displayName;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final snapshot = widget.controller.snapshot;
        return RefreshIndicator(
          onRefresh: widget.controller.refresh,
          child: ListView(
            key: const PageStorageKey<String>('home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              AppContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHeading(
                      displayName: displayName,
                      updatedAt: snapshot?.updatedAt,
                    ),
                    const SizedBox(height: 16),
                    _DashboardFilters(controller: widget.controller),
                    const SizedBox(height: 16),
                    if (widget.controller.errorMessage != null) ...[
                      ErrorPanel(
                        message: widget.controller.errorMessage!,
                        onRetry: widget.controller.retry,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (snapshot == null && widget.controller.isLoading)
                      const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot != null) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 780;
                          final columns = isWide ? 4 : 2;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.metrics.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: isWide ? 92 : 96,
                                ),
                            itemBuilder: (context, index) {
                              final metric = snapshot.metrics[index];
                              final onTap = switch (metric.type) {
                                DashboardMetricType.orders ||
                                DashboardMetricType.salesWithOrders =>
                                  widget.onOpenOrders,
                                DashboardMetricType.concreteGrades ||
                                DashboardMetricType.mixerTrucks =>
                                  widget.onOpenStatistics,
                              };
                              return DashboardMetricCard(
                                metric: metric,
                                onTap: onTap,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      ProductionChartCard(snapshot: snapshot),
                      if (snapshot.unavailableStationCount > 0) ...[
                        const SizedBox(height: 16),
                        _UnavailableStationNotice(
                          count: snapshot.unavailableStationCount,
                        ),
                      ],
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
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading({required this.displayName, required this.updatedAt});

  final String displayName;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trang tổng quan',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Xin chào, $displayName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (updatedAt != null)
          Text(
            formatLocalDateTime(updatedAt!),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _DashboardFilters extends StatelessWidget {
  const _DashboardFilters({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCompany = controller.selectedCompany;
    final selectedStation = controller.selectedStation;
    final companyField = SearchableAutocompleteField<DashboardScope>(
      key: const ValueKey<String>('dashboard-company-filter'),
      options: controller.companyScopes,
      selectedOption: selectedCompany,
      displayStringForOption: (option) => option.label,
      searchStringForOption: (option) => [
        option.label,
        if (option.description != null) option.description!,
        'công ty',
      ].join(' '),
      optionSubtitle: (option) {
        final description = option.description?.trim();
        return description == null || description.isEmpty
            ? 'Công ty'
            : description;
      },
      onSelected: controller.selectCompany,
      onCleared: selectedCompany == null ? null : controller.clearCompany,
      enabled: controller.companyScopes.isNotEmpty && !controller.isLoading,
      loading: controller.scopes.isEmpty && controller.isLoading,
      hintText: 'Tất cả công ty',
      labelText: 'Công ty (tùy chọn)',
      prefixIcon: Icons.apartment_outlined,
      compact: true,
      showDropdownIcon: true,
    );
    final stationField = SearchableAutocompleteField<DashboardScope>(
      key: ValueKey<String>(
        'dashboard-station-filter-${selectedCompany?.companyId ?? 'all'}',
      ),
      options: controller.stationScopes,
      selectedOption: selectedStation,
      displayStringForOption: (option) => option.label,
      searchStringForOption: (option) => [
        option.label,
        if (option.description != null) option.description!,
        'trạm',
      ].join(' '),
      optionSubtitle: (option) => option.description,
      onSelected: controller.selectStation,
      onCleared: selectedStation == null ? null : controller.clearStation,
      enabled: controller.stationScopes.isNotEmpty && !controller.isLoading,
      hintText: 'Tất cả trạm',
      labelText: 'Trạm (tùy chọn)',
      prefixIcon: Icons.factory_outlined,
      compact: true,
      showDropdownIcon: true,
    );
    final timeRangeField = DropdownButtonFormField<TimeRangePreset>(
      key: ValueKey<String>(
        'dashboard-time-range-${controller.timeRange.name}',
      ),
      initialValue: controller.timeRange,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: const InputDecoration(
        labelText: 'Thời gian',
        prefixIcon: Icon(Icons.calendar_month_outlined, size: 18),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10),
      ),
      items: [
        for (final value in TimeRangePreset.values)
          DropdownMenuItem<TimeRangePreset>(
            key: ValueKey<String>('dashboard-range-${value.name}'),
            value: value,
            child: Text(value.label),
          ),
      ],
      onChanged: controller.isLoading
          ? null
          : (value) {
              if (value != null) controller.selectTimeRange(value);
            },
    );
    return Container(
      key: const ValueKey<String>('dashboard-filters'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 840) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: companyField),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: stationField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: timeRangeField),
              ],
            );
          }
          return Column(
            children: [
              companyField,
              const SizedBox(height: 10),
              stationField,
              const SizedBox(height: 10),
              timeRangeField,
            ],
          );
        },
      ),
    );
  }
}

class _UnavailableStationNotice extends StatelessWidget {
  const _UnavailableStationNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFC2410C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count trạm chưa thể truy cập nên chưa được tính vào tổng hợp.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9A3412),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
