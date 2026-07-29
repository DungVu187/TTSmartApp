import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/dashboard_models.dart';
import '../controllers/home_controller.dart';
import '../widgets/dashboard_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenOrders,
    required this.onOpenReports,
    required this.onOpenMore,
  });

  final HomeController controller;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenMore;

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

  Future<void> _chooseScope() async {
    final selected = await showModalBottomSheet<DataScopeOption>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phạm vi dữ liệu',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Chỉ hiển thị công ty và trạm tài khoản được cấp quyền.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              RadioGroup<DataScopeOption>(
                groupValue: widget.controller.selectedScope,
                onChanged: (scope) {
                  if (scope != null) Navigator.pop(context, scope);
                },
                child: Column(
                  children: [
                    for (final scope in widget.controller.scopes)
                      RadioListTile<DataScopeOption>(
                        value: scope,
                        contentPadding: EdgeInsets.zero,
                        title: Text(scope.label),
                        subtitle: scope.description == null
                            ? null
                            : Text(scope.description!),
                        secondary: Icon(
                          scope.type == DataScopeType.company
                              ? Icons.apartment_outlined
                              : Icons.factory_outlined,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await widget.controller.selectScope(selected);
    }
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
            children: [
              AppContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeBlock(
                      displayName: displayName,
                      selectedScope: widget.controller.selectedScope,
                      updatedAt: snapshot?.updatedAt,
                      onChooseScope: widget.controller.scopes.isEmpty
                          ? null
                          : _chooseScope,
                    ),
                    const SizedBox(height: 20),
                    _TimeRangeSelector(controller: widget.controller),
                    const SizedBox(height: 24),
                    if (widget.controller.errorMessage != null) ...[
                      ErrorPanel(
                        message: widget.controller.errorMessage!,
                        onRetry: widget.controller.refresh,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (snapshot == null && widget.controller.isLoading)
                      const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot != null) ...[
                      const AppSectionHeader(
                        title: 'Tổng quan',
                        subtitle: 'Các chỉ số theo phạm vi đang xem',
                      ),
                      const SizedBox(height: 14),
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
                                  mainAxisExtent: 164,
                                ),
                            itemBuilder: (context, index) =>
                                DashboardMetricCard(
                                  metric: snapshot.metrics[index],
                                ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const AppSectionHeader(
                        title: 'Hành động nhanh',
                        subtitle: 'Đi thẳng đến công việc thường dùng',
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 700;
                          final children = <Widget>[
                            QuickActionButton(
                              icon: Icons.search,
                              label: 'Tra cứu đơn hàng',
                              onTap: widget.onOpenOrders,
                            ),
                            QuickActionButton(
                              icon: Icons.query_stats_outlined,
                              label: 'Xem báo cáo',
                              onTap: widget.onOpenReports,
                            ),
                            QuickActionButton(
                              icon: Icons.factory_outlined,
                              label: 'Danh sách trạm',
                              onTap: widget.onOpenMore,
                            ),
                          ];
                          if (wide) {
                            return Row(
                              children: [
                                for (
                                  var index = 0;
                                  index < children.length;
                                  index++
                                ) ...[
                                  if (index > 0) const SizedBox(width: 12),
                                  Expanded(child: children[index]),
                                ],
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (
                                var index = 0;
                                index < children.length;
                                index++
                              ) ...[
                                if (index > 0) const SizedBox(height: 10),
                                children[index],
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      ProductionChartCard(snapshot: snapshot),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stationSection = _StationSection(
                            stations: snapshot.stations,
                            onOpenMore: widget.onOpenMore,
                          );
                          final activitySection = _ActivitySection(
                            activities: snapshot.activities,
                          );
                          if (constraints.maxWidth >= 900) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: stationSection),
                                const SizedBox(width: 16),
                                Expanded(child: activitySection),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              stationSection,
                              const SizedBox(height: 24),
                              activitySection,
                            ],
                          );
                        },
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
}

class _WelcomeBlock extends StatelessWidget {
  const _WelcomeBlock({
    required this.displayName,
    required this.selectedScope,
    required this.updatedAt,
    required this.onChooseScope,
  });

  final String displayName;
  final DataScopeOption? selectedScope;
  final DateTime? updatedAt;
  final VoidCallback? onChooseScope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào, $displayName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Theo dõi nhanh hoạt động sản xuất và đơn hàng.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.78,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onChooseScope,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedScope?.type == DataScopeType.station
                          ? Icons.factory_outlined
                          : Icons.apartment_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedScope?.label ?? 'Đang tải phạm vi...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            updatedAt == null
                                ? 'Đang cập nhật dữ liệu'
                                : 'Cập nhật ${formatLocalDateTime(updatedAt!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in TimeRangePreset.values) ...[
            ChoiceChip(
              label: Text(value.label),
              selected: controller.timeRange == value,
              onSelected: (_) => controller.selectTimeRange(value),
            ),
            if (value != TimeRangePreset.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StationSection extends StatelessWidget {
  const _StationSection({required this.stations, required this.onOpenMore});

  final List<StationOverview> stations;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Trạng thái trạm',
          subtitle: 'Theo dõi phạm vi được cấp quyền',
          trailing: TextButton(
            onPressed: onOpenMore,
            child: const Text('Xem tất cả'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < stations.length; index++) ...[
                if (index > 0) const Divider(),
                StationOverviewCard(station: stations[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.activities});

  final List<DashboardActivity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Hoạt động gần đây',
          subtitle: 'Các thay đổi mới nhất trong phạm vi',
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < activities.length; index++) ...[
                if (index > 0) const Divider(),
                DashboardActivityTile(activity: activities[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
