import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../data/models/report_models.dart';
import '../widgets/statistics_tables.dart';

/// Material totals of the current statistics result (Figma C03), the phone
/// version of the "Thống kê tổng" table.
class StatisticsSummaryScreen extends StatelessWidget {
  const StatisticsSummaryScreen({
    super.key,
    required this.page,
    required this.stationName,
    this.rangeLabel,
  });

  final OrderStatisticsPage page;
  final String stationName;
  final String? rangeLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final groups = <String, List<OrderStatisticsMaterialSummaryCell>>{};
    for (final row in page.materialSummaryRows) {
      for (final cell in row.cells) {
        if (cell.actualQuantity == 0) continue;
        groups
            .putIfAbsent(
              statisticsCategoryLabel(cell.categoryCode, cell.category),
              () => [],
            )
            .add(cell);
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê tổng')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kPagePadding, 6, kPagePadding, 32),
          children: [
            Text(
              rangeLabel == null ? stationName : '$stationName · $rangeLabel',
              style: TextStyle(
                color: p.text2,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            StatRow(
              children: [
                StatTile(
                  label: 'Tổng bê tông',
                  value: formatStatisticsTotal(
                    page.totalConcreteVolume,
                    digits: 3,
                  ),
                  unit: 'm³',
                  valueColor: p.success,
                ),
                StatTile(
                  label: 'Tổng vật liệu',
                  value: formatStatisticsTotal(page.totalMaterialQuantity),
                  unit: 'kg',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (groups.isEmpty)
              const StateView(
                icon: LucideIcons.package,
                title: 'Chưa có tổng vật liệu',
                message:
                    'Khoảng thời gian đang chọn không có dữ liệu tổng hợp.',
              )
            else
              for (final group in groups.entries) ...[
                InsetGroup(
                  label: group.key,
                  children: [
                    for (final cell in group.value)
                      NavRow(
                        title: cell.materialName?.trim().isNotEmpty == true
                            ? cell.materialName!
                            : statisticsCategoryLabel(
                                cell.categoryCode,
                                cell.category,
                              ),
                        subtitle: cell.slotNumber == null
                            ? null
                            : 'Cửa ${cell.slotNumber}',
                        showChevron: false,
                        trailing: Text(
                          '${formatStatisticsSummaryMaterial(cell.actualQuantity, cell.categoryCode)} '
                          '${cell.unit?.trim().isNotEmpty == true ? cell.unit!.trim().toLowerCase() : statisticsCategoryUnit(cell.categoryCode)}',
                          style: TextStyle(
                            color: p.text1,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
          ],
        ),
      ),
    );
  }
}
