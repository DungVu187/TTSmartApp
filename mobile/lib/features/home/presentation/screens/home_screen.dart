import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../data/models/dashboard_models.dart';
import '../controllers/home_controller.dart';
import '../widgets/dashboard_widgets.dart';

/// Figma "02 Home": greeting, scope chips, four KPI cards, mixed-volume
/// chart and the unavailable-station notice.
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

  HomeController get _controller => widget.controller;

  Future<void> _pickTimeRange() async {
    final picked = await showPickerSheet<TimeRangePreset>(
      context: context,
      title: 'Khoảng thời gian',
      icon: LucideIcons.calendar,
      selected: _controller.timeRange,
      options: [
        for (final value in TimeRangePreset.values)
          PickerOption(value: value, title: value.label),
      ],
    );
    final value = picked?.value;
    if (!mounted || value == null) return;
    await _controller.selectTimeRange(value);
  }

  Future<void> _pickCompany() async {
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Chọn công ty',
      searchHint: 'Tìm công ty',
      icon: LucideIcons.building,
      clearLabel: 'Tất cả công ty',
      selected: _controller.selectedCompany?.keyName,
      options: [
        for (final company in _controller.companyScopes)
          PickerOption(value: company.keyName, title: company.label),
      ],
    );
    if (!mounted || picked == null) return;
    final keyName = picked.value;
    if (keyName == null) {
      await _controller.clearCompany();
      return;
    }
    await _controller.selectCompany(
      _controller.companyScopes.firstWhere((scope) => scope.keyName == keyName),
    );
  }

  Future<void> _pickStation() async {
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Chọn trạm',
      searchHint: 'Tìm trạm',
      icon: LucideIcons.factory,
      clearLabel: 'Tất cả trạm',
      selected: _controller.selectedStation?.keyName,
      emptyMessage: 'Không có trạm trong phạm vi được cấp.',
      options: [
        for (final station in _controller.stationScopes)
          PickerOption(
            value: station.keyName,
            title: station.label,
            subtitle: station.description,
          ),
      ],
    );
    if (!mounted || picked == null) return;
    final keyName = picked.value;
    if (keyName == null) {
      await _controller.clearStation();
      return;
    }
    await _controller.selectStation(
      _controller.stationScopes.firstWhere((scope) => scope.keyName == keyName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final displayName = app.session!.user.displayName;
    final canSelectCompany = app.hasRole('ADMIN');
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final snapshot = _controller.snapshot;
        final busy = _controller.isLoading;
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView(
            key: const PageStorageKey<String>('home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _Greeting(displayName: displayName),
              const SizedBox(height: 6),
              FilterChipBar(
                key: const ValueKey<String>('dashboard-filters'),
                spacing: 6,
                children: [
                  FilterChipButton(
                    key: ValueKey<String>(
                      'dashboard-time-range-${_controller.timeRange.name}',
                    ),
                    size: FilterChipSize.small,
                    active: true,
                    icon: LucideIcons.calendar,
                    label: _controller.timeRange.label,
                    onTap: busy ? null : _pickTimeRange,
                  ),
                  if (canSelectCompany)
                    FilterChipButton(
                      key: const ValueKey<String>('dashboard-company-filter'),
                      size: FilterChipSize.small,
                      showChevron: true,
                      icon: LucideIcons.building,
                      label:
                          _controller.selectedCompany?.label ??
                          'Tất cả công ty',
                      onTap: busy || _controller.companyScopes.isEmpty
                          ? null
                          : _pickCompany,
                    ),
                  FilterChipButton(
                    key: ValueKey<String>(
                      'dashboard-station-filter-'
                      '${_controller.selectedCompany?.companyId ?? 'all'}',
                    ),
                    size: FilterChipSize.small,
                    showChevron: true,
                    icon: LucideIcons.factory,
                    label: _controller.selectedStation?.label ?? 'Tất cả trạm',
                    onTap: busy || _controller.stationScopes.isEmpty
                        ? null
                        : _pickStation,
                  ),
                ],
              ),
              if (_controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(
                  message: _controller.errorMessage!,
                  onRetry: _controller.retry,
                ),
              ],
              if (snapshot == null && busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 96),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot != null) ...[
                _SectionTitle(
                  title: 'Tổng quan',
                  trailing: Semantics(
                    button: true,
                    label: 'Cập nhật lại',
                    child: GestureDetector(
                      onTap: busy ? null : _controller.refresh,
                      child: Text(
                        'Cập nhật ${_updatedLabel(snapshot.updatedAt)}',
                        style: TextStyle(
                          color: context.palette.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                _MetricGrid(
                  metrics: snapshot.metrics,
                  onOpenOrders: widget.onOpenOrders,
                  onOpenStatistics: widget.onOpenStatistics,
                ),
                _SectionTitle(
                  title: 'Khối lượng đã trộn',
                  topSpacing: 18,
                  trailing: _Pill(label: snapshot.timeRange.label),
                ),
                ProductionChartCard(snapshot: snapshot),
                if (snapshot.unavailableStationCount > 0) ...[
                  const SizedBox(height: 10),
                  UnavailableStationNotice(
                    count: snapshot.unavailableStationCount,
                    stationNames: [
                      for (final station in snapshot.stations)
                        if (!station.isAvailable) station.name,
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  /// "09:40" today, "20/09 09:40" otherwise (Vietnam time).
  static String _updatedLabel(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    final local = utcToVietnamTime(value.toUtc());
    final today = utcToVietnamTime(DateTime.now().toUtc());
    final time = '${two(local.hour)}:${two(local.minute)}';
    final sameDay =
        local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    return sameDay ? time : '${two(local.day)}/${two(local.month)} $time';
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text.rich(
      TextSpan(
        style: TextStyle(color: p.text2, fontSize: 13, height: 16 / 13),
        children: [
          const TextSpan(
            text: 'Xin chào, ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: displayName,
            style: TextStyle(color: p.text1, fontWeight: FontWeight.w800),
          ),
          const TextSpan(text: ' 👋'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.trailing,
    this.topSpacing = 16,
  });

  final String title;
  final Widget? trailing;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: context.palette.text1,
                fontSize: 15,
                height: 18 / 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: p.text2,
          fontSize: 11,
          height: 13 / 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.metrics,
    this.onOpenOrders,
    this.onOpenStatistics,
  });

  final List<DashboardMetric> metrics;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenStatistics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 64,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return DashboardMetricCard(
              metric: metric,
              onTap: switch (metric.type) {
                DashboardMetricType.orders ||
                DashboardMetricType.salesWithOrders => onOpenOrders,
                DashboardMetricType.concreteGrades ||
                DashboardMetricType.mixerTrucks => onOpenStatistics,
              },
            );
          },
        );
      },
    );
  }
}
