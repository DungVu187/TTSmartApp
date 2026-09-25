import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui.dart';
import '../../data/models/order_report_models.dart';
import '../widgets/order_report_widgets.dart';

/// Detail of one order (Figma 03b): every column of the web "Báo cáo đơn
/// hàng" table for that row, with the production progress on top.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.item,
    this.showCompany = false,
  });

  final OrderReportItem item;

  /// Admins looking at every company also see which company the order is of.
  final bool showCompany;

  static String _value(String? text) =>
      text?.trim().isNotEmpty == true ? text!.trim() : 'Chưa cập nhật';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ordered = item.orderedVolume ?? 0;
    final produced = item.producedVolume ?? 0;
    final progress = orderProgressOf(ordered, produced);
    final orderedAt = formatOrderDateTime(item.orderedAtUtc);
    return Scaffold(
      appBar: AppBar(title: Text('Đơn #${item.orderId}')),
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
              [item.stationDisplayName, ?orderedAt].join(' · '),
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
                    label: 'Khối lượng đặt',
                    value: '${formatOrderReportVolume(item.orderedVolume)} m³',
                    tone: AppTone.info,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VolumeBox(
                    label: 'Đã sản xuất',
                    value: '${formatOrderReportVolume(item.producedVolume)} m³',
                    tone: AppTone.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.ratio,
                minHeight: 6,
                color: p.tone(progress.tone).$1,
                backgroundColor: p.surfaceMuted,
              ),
            ),
            const SizedBox(height: 6),
            // Progress in words, not only as a colour (ui-ux-pro-max).
            Text(
              progress.label,
              style: TextStyle(
                color: p.text2,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            InsetGroup(
              label: 'Đơn hàng',
              children: [
                FieldRow(label: 'Mã đơn', value: '#${item.orderId}'),
                FieldRow(
                  label: 'Ngày đặt',
                  value: orderedAt ?? 'Chưa cập nhật',
                ),
                FieldRow(
                  label: 'Số phiếu',
                  value: item.ticketCount?.toString() ?? 'Chưa cập nhật',
                ),
                FieldRow(label: 'Trạm', value: item.stationDisplayName),
                if (showCompany && item.companyName?.trim().isNotEmpty == true)
                  FieldRow(label: 'Công ty', value: item.companyName!.trim()),
              ],
            ),
            const SizedBox(height: 20),
            InsetGroup(
              label: 'Công trình',
              children: [
                FieldRow(label: 'Dự án', value: _value(item.projectName)),
                FieldRow(
                  label: 'Mác bê tông',
                  value: _value(item.concreteGradeName),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InsetGroup(
              label: 'Kinh doanh',
              children: [
                FieldRow(
                  label: 'Nhân viên kinh doanh',
                  value: _value(item.employeeName),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
