import 'package:flutter/material.dart';

import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/simple_line_chart.dart';
import '../../data/models/report_models.dart';
import '../controllers/reports_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.controller});

  final ReportsController controller;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final snapshot = widget.controller.snapshot;
        return RefreshIndicator(
          onRefresh: widget.controller.refresh,
          child: ListView(
            key: const PageStorageKey<String>('reports-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionHeader(
                      title: 'Báo cáo',
                      subtitle: 'Theo dõi sản lượng và hiệu quả vận hành',
                    ),
                    const SizedBox(height: 18),
                    if (widget.controller.scopes.isNotEmpty)
                      _ReportFilters(controller: widget.controller),
                    if (widget.controller.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      ErrorPanel(
                        message: widget.controller.errorMessage!,
                        onRetry: widget.controller.refresh,
                      ),
                    ],
                    if (snapshot == null && widget.controller.isLoading)
                      const SizedBox(
                        height: 360,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot != null) ...[
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 780 ? 4 : 2;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.metrics.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 148,
                                ),
                            itemBuilder: (context, index) => _ReportMetricCard(
                              metric: snapshot.metrics[index],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Xu hướng sản lượng',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${snapshot.scope.label} · '
                                          '${snapshot.timeRange.label}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Cập nhật ${_time(snapshot.updatedAt)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SimpleLineChart(
                                values: snapshot.chartValues,
                                labels: snapshot.chartLabels,
                                height: 230,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const AppSectionHeader(
                        title: 'Theo trạm',
                        subtitle: 'So sánh nhanh trong phạm vi báo cáo',
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < snapshot.stationRows.length;
                              index++
                            ) ...[
                              if (index > 0) const Divider(),
                              _StationReportTile(
                                row: snapshot.stationRows[index],
                              ),
                            ],
                          ],
                        ),
                      ),
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

  String _time(DateTime value) {
    final formatted = formatLocalDateTime(value);
    return formatted.substring(formatted.length - 5);
  }
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scope = DropdownButtonFormField<DataScopeOption>(
              initialValue: controller.selectedScope,
              decoration: const InputDecoration(
                labelText: 'Phạm vi',
                prefixIcon: Icon(Icons.factory_outlined),
              ),
              items: controller.scopes
                  .map(
                    (item) => DropdownMenuItem<DataScopeOption>(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  controller.updateFilters(
                    scope: value,
                    timeRange: controller.timeRange,
                  );
                }
              },
            );
            final period = DropdownButtonFormField<TimeRangePreset>(
              initialValue: controller.timeRange,
              decoration: const InputDecoration(
                labelText: 'Thời gian',
                prefixIcon: Icon(Icons.date_range_outlined),
              ),
              items: TimeRangePreset.values
                  .map(
                    (item) => DropdownMenuItem<TimeRangePreset>(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                final selectedScope = controller.selectedScope;
                if (value != null && selectedScope != null) {
                  controller.updateFilters(
                    scope: selectedScope,
                    timeRange: value,
                  );
                }
              },
            );
            if (constraints.maxWidth >= 680) {
              return Row(
                children: [
                  Expanded(child: scope),
                  const SizedBox(width: 12),
                  Expanded(child: period),
                ],
              );
            }
            return Column(
              children: [scope, const SizedBox(height: 12), period],
            );
          },
        ),
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({required this.metric});

  final ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: theme.colorScheme.primary),
            const Spacer(),
            Text(
              metric.value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              metric.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (metric.type) {
    ReportMetricType.orders => Icons.receipt_long_outlined,
    ReportMetricType.mixedVolume => Icons.monitor_weight_outlined,
    ReportMetricType.completionRate => Icons.task_alt_outlined,
    ReportMetricType.activeStations => Icons.factory_outlined,
  };
}

class _StationReportTile extends StatelessWidget {
  const _StationReportTile({required this.row});

  final StationReportRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.stationName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(row.completionRate * 100).round()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: row.completionRate >= 0.9
                      ? AppColors.success
                      : AppColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: row.completionRate,
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 9),
          Text(
            '${row.orderCount} đơn · ${row.mixedVolume.round()} m³',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
