import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui.dart';
import '../../data/models/report_models.dart';
import '../widgets/statistics_tables.dart';

/// Detail of one mixing batch (Figma C02): every column of the statistics
/// table for that row, including ĐM / T / Thực tế / SS per material.
class MixBatchDetailScreen extends StatelessWidget {
  const MixBatchDetailScreen({super.key, required this.item});

  final OrderStatisticsItem item;

  static String _value(String? text) =>
      text?.trim().isNotEmpty == true ? text!.trim() : 'Chưa cập nhật';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết mẻ trộn')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kPagePadding, 6, kPagePadding, 32),
          children: [
            Text(
              _value(item.customerName),
              style: TextStyle(
                color: p.text1,
                fontSize: 19,
                height: 24 / 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${item.stationDisplayName} · ${formatStatisticsDate(item.mixingDate)}',
              style: TextStyle(
                color: p.text2,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: VolumeBox(
                    label: 'Thể tích đặt',
                    value: '${formatStatisticsVolume(item.requestedVolume)} m³',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VolumeBox(
                    label: 'Thể tích trộn',
                    value: '${formatStatisticsVolume(item.mixedVolume)} m³',
                    tone: AppTone.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            InsetGroup(
              label: 'Thời gian',
              children: [
                PairFieldRow(
                  first: ('Bắt đầu', formatStatisticsTime(item.startedAt)),
                  second: ('Kết thúc', formatStatisticsTime(item.finishedAt)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InsetGroup(
              label: 'Công trình',
              children: [
                FieldRow(label: 'Tên dự án', value: _value(item.projectName)),
                FieldRow(
                  label: 'Tên hạng mục',
                  value: _value(item.workItemName),
                ),
                FieldRow(
                  label: 'Tên địa điểm',
                  value: _value(item.locationName),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InsetGroup(
              label: 'Bê tông',
              children: [
                PairFieldRow(
                  first: ('Mác bê tông', _value(item.concreteGradeName)),
                  second: ('Độ sụt', _value(item.slump)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InsetGroup(
              label: 'Vận chuyển',
              children: [
                PairFieldRow(
                  first: ('Xe', _value(item.vehiclePlate)),
                  second: ('Tên lái xe', _value(item.driverName)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InsetGroup(
              label: 'Nhân sự',
              children: [
                FieldRow(
                  label: 'NV kinh doanh',
                  value: _value(item.salesEmployeeName),
                ),
                FieldRow(
                  label: 'Tên nhân viên',
                  value: _value(item.employeeName),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const GroupLabel('Định lượng vật liệu'),
            const SizedBox(height: 8),
            if (item.materials.isEmpty)
              const StateView(
                icon: Icons.science_outlined,
                title: 'Chưa có định lượng',
                message: 'Mẻ trộn này không có dòng vật liệu.',
              )
            else ...[
              _MaterialTable(materials: item.materials),
              const SizedBox(height: 8),
              Text(
                'SS = Thực tế + T − ĐM. Đơn vị kg, riêng nước tính theo lít.',
                style: TextStyle(
                  color: p.text3,
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact 5-column table: material · ĐM · T · Thực tế · SS.
class _MaterialTable extends StatelessWidget {
  const _MaterialTable({required this.materials});

  final List<OrderStatisticsMaterial> materials;

  static const _numberWidths = <double>[56, 48, 60, 52];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget cell(String text, {bool header = false, bool first = false}) {
      final style = TextStyle(
        color: header ? p.text3 : p.text1,
        fontSize: header ? 12 : 14,
        height: 18 / 14,
        fontWeight: header
            ? FontWeight.w700
            : first
            ? FontWeight.w600
            : FontWeight.w500,
        letterSpacing: header ? 0.4 : 0,
      );
      return Text(
        text,
        textAlign: first ? TextAlign.left : TextAlign.right,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    Widget row(List<String> values, {bool header = false}) {
      return Container(
        color: header ? p.surfaceMuted : null,
        padding: EdgeInsets.fromLTRB(13, header ? 10 : 11, 9, header ? 10 : 11),
        child: Row(
          children: [
            Expanded(child: cell(values[0], header: header, first: true)),
            for (var index = 1; index < values.length; index++)
              SizedBox(
                width: _numberWidths[index - 1],
                child: cell(values[index], header: header),
              ),
          ],
        ),
      );
    }

    String signed(double value, String code) {
      final text = formatStatisticsMaterial(value, code);
      return value > 0 ? '+$text' : text;
    }

    return InsetCard(
      children: [
        row(const ['VẬT LIỆU', 'ĐM', 'T', 'THỰC TẾ', 'SS'], header: true),
        for (final material in materials)
          row([
            material.materialName?.trim().isNotEmpty == true
                ? material.materialName!.trim()
                : statisticsCategoryLabel(
                    material.categoryCode,
                    material.category,
                  ),
            formatStatisticsMaterial(
              material.designQuantity,
              material.categoryCode,
            ),
            formatStatisticsMaterial(material.tQuantity, material.categoryCode),
            formatStatisticsMaterial(
              material.actualQuantity,
              material.categoryCode,
            ),
            signed(material.variance, material.categoryCode),
          ]),
      ],
    );
  }
}
