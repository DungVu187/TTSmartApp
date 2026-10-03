import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_palette.dart';

/// Horizontal page padding of the redesign.
const double kPagePadding = 16;

/// Divider indent for rows that start with a 40px tile/avatar
/// (13 row padding + 40 tile + 12 gap) so the rule lines up with the title.
const double kLeadingDividerIndent = 65;

/// Divider indent for plain text rows.
const double kTextDividerIndent = 13;

/// Uppercase caption above a group of rows ("THÔNG TIN LIÊN HỆ").
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        color: p.text3,
        fontSize: 12,
        height: 15 / 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
    if (trailing == null) return label;
    return Row(
      children: [
        Expanded(child: label),
        trailing!,
      ],
    );
  }
}

/// White rounded card that stacks rows with hairline dividers between them.
class InsetCard extends StatelessWidget {
  const InsetCard({
    super.key,
    required this.children,
    this.dividerIndent = kTextDividerIndent,
    this.color,
  });

  final List<Widget> children;
  final double dividerIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        items.add(Divider(height: 1, thickness: 1, indent: dividerIndent));
      }
      items.add(children[index]);
    }
    return Material(
      color: color ?? p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

/// [GroupLabel] + [InsetCard], the building block of every detail screen.
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    this.label,
    this.labelTrailing,
    required this.children,
    this.dividerIndent = kTextDividerIndent,
  });

  final String? label;
  final Widget? labelTrailing;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          GroupLabel(label!, trailing: labelTrailing),
          const SizedBox(height: 8),
        ],
        InsetCard(dividerIndent: dividerIndent, children: children),
      ],
    );
  }
}

class AppChevron extends StatelessWidget {
  const AppChevron({super.key});

  @override
  Widget build(BuildContext context) =>
      Icon(LucideIcons.chevronRight, size: 22, color: context.palette.text3);
}

/// Tinted square with a centred icon (40px by default).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.tone = AppTone.primary,
    this.size = 40,
    this.radius = 12,
    this.iconSize,
    this.background,
  });

  final IconData icon;
  final AppTone tone;
  final double size;
  final double radius;
  final double? iconSize;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.palette.tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize ?? size * 0.5, color: fg),
    );
  }
}

/// Tinted squircle with initials, used for people.
/// Rounded tile with the initials of [text] (a person's name: "Nguyễn Hoàng
/// Nam" → "NN"). The tone defaults to one derived from the name so a list of
/// people is not all one colour.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.text,
    this.tone,
    this.size = 40,
    this.radius,
    this.fontSize,
    this.initials,
  });

  final String text;

  /// Overrides the two-letter initials (the signed-in user shows one).
  final String? initials;
  final AppTone? tone;
  final double size;
  final double? radius;
  final double? fontSize;

  /// Tone picked from the name so a list of people is not all one colour.
  static AppTone toneFor(String seed) {
    const tones = [
      AppTone.info,
      AppTone.violet,
      AppTone.success,
      AppTone.warning,
      AppTone.danger,
    ];
    final code = seed.runes.fold<int>(0, (sum, rune) => sum + rune);
    return tones[code % tones.length];
  }

  /// First letters of the first and last word ("Nguyễn Hoàng Nam" → "NN").
  static String initialsOf(String value) {
    final words = value.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.palette.tone(tone ?? toneFor(text));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius ?? size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(
        initials ?? initialsOf(text),
        style: TextStyle(
          color: fg,
          fontSize: fontSize ?? size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Tappable list row: [leading] · title / subtitle · value · trailing · chevron.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.showChevron,
    this.titleStyle,
    this.background,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
  });

  /// Data rows on narrow phones (360dp) wrap instead of hiding the time or
  /// the amount behind "…"; wide phones still show one line.
  final int titleMaxLines;
  final int subtitleMaxLines;

  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool? showChevron;
  final TextStyle? titleStyle;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chevron = (showChevron ?? onTap != null) && value == null;
    // Larger system fonts: wrap instead of cutting names with "…".
    final bigText = MediaQuery.textScalerOf(context).scale(10) > 11.5;
    final titleLines = bigText && titleMaxLines < 2 ? 2 : titleMaxLines;
    final subtitleLines = bigText && subtitleMaxLines < 2
        ? 2
        : subtitleMaxLines;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(13, 13, chevron ? 9 : 13, 13),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: titleLines,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleStyle ??
                      TextStyle(
                        color: p.text1,
                        fontSize: 16,
                        height: 21 / 16,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subtitleWidget != null) ...[
                  const SizedBox(height: 2),
                  subtitleWidget!,
                ] else if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: subtitleLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtitleColor ?? p.text2,
                      fontSize: 13,
                      height: 17 / 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            Text(
              value!,
              style: TextStyle(
                color: p.text2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          if (chevron) ...[const SizedBox(width: 4), const AppChevron()],
        ],
      ),
    );
    final row = background == null
        ? content
        : ColoredBox(color: background!, child: content);
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Read-only label-over-value row; the value wraps instead of truncating.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight? valueWeight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: p.text3,
              fontSize: 12,
              height: 15 / 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? p.text1,
              fontSize: 16,
              height: 21 / 16,
              fontWeight: valueWeight ?? FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two [FieldRow]s side by side for short paired values (Bắt đầu / Kết thúc).
class PairFieldRow extends StatelessWidget {
  const PairFieldRow({super.key, required this.first, required this.second});

  final (String, String) first;
  final (String, String) second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FieldRow(label: first.$1, value: first.$2),
        ),
        Expanded(
          child: FieldRow(label: second.$1, value: second.$2),
        ),
      ],
    );
  }
}

/// Icon + label action row (Sửa thông tin / Xóa người dùng).
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = destructive ? p.danger : p.text1;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width switch row; tapping anywhere on the row toggles it.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.emphasized = false,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: p.text1,
                        fontSize: 16,
                        height: 21 / 16,
                        fontWeight: emphasized
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: p.text2,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
