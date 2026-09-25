import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Summary tile of report screens: caption over a large value + unit.
/// [compact] = the 11/16 tiles of the Orders frame (v3 frames: 12/17).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.onTap,
    this.compact = false,
    this.valueFontSize,
  });

  final String label;
  final String value;

  /// Overrides the value size (Figma B02 uses 12/16 on the regular tile).
  final double? valueFontSize;
  final String? unit;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(13, 11, 10, 11)
              : const EdgeInsets.fromLTRB(13, 11, 10, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text2,
                        fontSize: compact ? 11 : 12,
                        height: compact ? 13 / 11 : 15 / 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded, size: 16, color: p.text3),
                ],
              ),
              const SizedBox(height: 3),
              // A number is never cut with "…": it shrinks to fit instead.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: valueColor ?? p.text1,
                          fontSize: valueFontSize ?? (compact ? 16 : 17),
                          height: compact ? 19 / 16 : 21 / 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (unit != null)
                        TextSpan(
                          text: ' $unit',
                          style: TextStyle(
                            color: p.text2,
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width row of [StatTile]s.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(child: children[index]),
          ],
        ],
      ),
    );
  }
}

/// Tinted quantity box ("Thể tích đặt 8 m³").
class VolumeBox extends StatelessWidget {
  const VolumeBox({
    super.key,
    required this.label,
    required this.value,
    this.tone = AppTone.info,
    this.compact = false,
  });

  final String label;
  final String value;
  final AppTone tone;

  /// 11/17 text of the Orders cards (v3 frames: 12/18).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.palette.tone(tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11 : 12,
              height: compact ? 13 / 11 : 15 / 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 17 : 18,
              height: compact ? 21 / 17 : 22 / 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Labelled horizontal bar with the value printed next to it.
class ComparisonBar extends StatelessWidget {
  const ComparisonBar({
    super.key,
    required this.label,
    required this.ratio,
    required this.displayValue,
    required this.tone,
  });

  final String label;
  final double ratio;
  final String displayValue;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, bg) = p.tone(tone);
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: TextStyle(
              color: p.text2,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              color: fg,
              backgroundColor: bg,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 104,
          child: Text(
            displayValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
