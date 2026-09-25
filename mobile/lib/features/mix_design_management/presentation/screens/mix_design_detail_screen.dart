import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../data/models/mix_design_models.dart';
import '../widgets/mix_design_widgets.dart';

class MixDesignDetailScreen extends StatelessWidget {
  const MixDesignDetailScreen({
    super.key,
    required this.item,
    required this.stationName,
    required this.columns,
  });

  final MixDesignItem item;
  final String stationName;
  final List<MixDesignMaterialColumn> columns;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final materials = columns
        .where((column) => item.quantityForColumn(column.columnKey) != 0)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết cấp phối')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          children: [
            Row(
              children: [
                const IconTile(
                  icon: LucideIcons.flaskConical,
                  tone: AppTone.violet,
                  size: 60,
                  radius: 18,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayConcreteGradeName,
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$stationName · STT ${item.stt}',
                        style: TextStyle(color: p.text2, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StatTile(label: 'Cường độ', value: '${item.strength}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Cốt liệu max',
                    value: '${item.maxAggregate}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(label: 'Độ sụt', value: item.slump),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const GroupLabel('Định lượng vật liệu'),
            const SizedBox(height: 8),
            if (materials.isEmpty)
              const StateView(
                icon: LucideIcons.flaskConical,
                title: 'Chưa có định lượng',
                message:
                    'Cấp phối này không có vật liệu khác 0 trong dữ liệu trả về.',
              )
            else
              InsetCard(
                children: [
                  for (final column in materials)
                    NavRow(
                      title: column.materialName,
                      subtitle: '${column.category} · cửa ${column.slotNumber}',
                      showChevron: false,
                      trailing: Text(
                        formatMixDesignNumber(
                          item.quantityForColumn(column.columnKey),
                        ),
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
