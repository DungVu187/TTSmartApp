import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../data/models/weigh_station_result_models.dart';
import '../widgets/weigh_station_result_widgets.dart';

/// Read-only detail of one weigh ticket (Figma C12).
class WeighTicketDetailScreen extends StatelessWidget {
  const WeighTicketDetailScreen({
    super.key,
    required this.item,
    required this.canViewMaterialValue,
  });

  final WeighStationItem item;
  final bool canViewMaterialValue;

  static String _text(String? value) =>
      value?.trim().isNotEmpty == true ? value!.trim() : 'Chưa cập nhật';

  String get _conversion {
    if (!item.hasConversionConfiguration) {
      return item.conversionMessage ?? 'Chưa cấu hình';
    }
    if (item.convertedQuantity == null) return '—';
    final unit = item.convertedUnit?.trim();
    return unit == null || unit.isEmpty
        ? formatWeighNumber(item.convertedQuantity)
        : '${formatWeighNumber(item.convertedQuantity)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final weighingType = item.weighingType?.trim();
    return Scaffold(
      appBar: AppBar(title: Text('Phiếu cân #${item.ticketNumber}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kPagePadding, 6, kPagePadding, 32),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _text(item.vehiclePlate),
                  style: TextStyle(
                    color: p.text1,
                    fontSize: 22,
                    height: 28 / 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (weighingType != null && weighingType.isNotEmpty)
                  AppTag(
                    label: weighingType,
                    tone: weighingTypeTone(weighingType),
                    compact: true,
                  ),
                if (item.weighedOutAt == null)
                  const AppTag(
                    label: 'Xe chưa ra',
                    tone: AppTone.warning,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _text(item.goodsName),
              style: TextStyle(
                color: p.text2,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: VolumeBox(
                    label: 'Khối lượng hàng',
                    value: '${formatWeighNumber(item.goodsWeightKg)} kg',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VolumeBox(
                    label: 'Quy đổi',
                    value: _conversion,
                    tone: AppTone.success,
                  ),
                ),
              ],
            ),
            if (canViewMaterialValue) ...[
              const SizedBox(height: 8),
              InsetCard(
                children: [
                  NavRow(
                    leading: Icon(
                      LucideIcons.banknote,
                      size: 20,
                      color: p.text2,
                    ),
                    title: 'Giá trị',
                    showChevron: false,
                    trailing: Text(
                      formatWeighCurrency(item.materialValueVnd),
                      style: TextStyle(
                        color: p.text1,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            InsetGroup(
              label: 'Lượt cân',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _WeightCell(
                        icon: LucideIcons.arrowDownLeft,
                        tone: AppTone.success,
                        label: 'Cân vào',
                        value: '${formatWeighNumber(item.inboundWeightKg)} kg',
                      ),
                    ),
                    Expanded(
                      child: _WeightCell(
                        icon: LucideIcons.arrowUpRight,
                        tone: AppTone.danger,
                        label: 'Cân ra',
                        value: '${formatWeighNumber(item.outboundWeightKg)} kg',
                      ),
                    ),
                  ],
                ),
                FieldRow(
                  label: 'Cân lần 1',
                  value:
                      '${_text(item.firstOperatorName)} · '
                      '${formatWeighShortDateTime(item.weighedInAt)}',
                ),
                FieldRow(
                  label: 'Cân lần 2',
                  value:
                      '${_text(item.secondOperatorName)} · '
                      '${formatWeighShortDateTime(item.weighedOutAt)}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            InsetGroup(
              label: 'Thông tin phiếu',
              children: [
                PairFieldRow(
                  first: ('Số phiếu', '${item.ticketNumber}'),
                  second: ('Ngày cân', formatWeighDateTime(item.weighingAt)),
                ),
                FieldRow(label: 'Lái xe', value: _text(item.driverName)),
                FieldRow(label: 'Đơn vị', value: _text(item.unitName)),
                FieldRow(
                  label: 'Mã phiếu / niêm chì',
                  value:
                      '${_text(item.ticketCode)} / ${_text(item.sealNumber)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightCell extends StatelessWidget {
  const _WeightCell({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final AppTone tone;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, _) = p.tone(tone);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: p.text3,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: p.text1,
              fontSize: 17,
              height: 22 / 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
