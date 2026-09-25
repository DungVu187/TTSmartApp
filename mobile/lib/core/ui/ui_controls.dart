import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../utils/organization_name.dart';
import 'app_palette.dart';
import 'ui_list.dart';

/// Small tinted status pill ("Đang khóa", "Trạm trộn", "12 phiếu").
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.tone = AppTone.primary,
    this.icon,
    this.compact = false,
  });

  final String label;
  final AppTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.palette.tone(tone);
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
          : EdgeInsets.fromLTRB(icon == null ? 10 : 8, 5, 10, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 6 : 9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 12 : 13,
              height: 16 / 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS-style segmented control used to switch views on one screen.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          for (final (index, (value, label)) in segments.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (value != selected) onChanged(value);
                  },
                  // The track padding belongs to the segment, so the full
                  // 46pt height is tappable, not only the 38pt pill.
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      index == 0 ? 4 : 2,
                      4,
                      index == segments.length - 1 ? 4 : 2,
                      4,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: value == selected ? p.surface : null,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: value == selected
                            ? [
                                BoxShadow(
                                  color: p.scrim.withValues(alpha: 0.10),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      // Shrinks with a large phone font instead of "Kiể…".
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              color: value == selected ? p.text1 : p.text2,
                              fontSize: 15,
                              fontWeight: value == selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill sizes of the Figma frames: Home 32/12, Orders 36/13, v3 38/14.
enum FilterChipSize { small, medium, large }

/// Scope chip of report screens (date range, station).
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
    this.showChevron = false,
    this.size = FilterChipSize.large,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final bool showChevron;
  final FilterChipSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = active ? p.onPrimary : p.text1;
    final iconColor = active ? p.onPrimary : p.text2;
    final dense = size == FilterChipSize.small;
    final (height, fontSize, iconSize) = switch (size) {
      FilterChipSize.small => (32.0, 12.0, 15.0),
      FilterChipSize.medium => (36.0, 13.0, 18.0),
      FilterChipSize.large => (38.0, 14.0, 17.0),
    };
    // "Công ty CP Xây dựng Hòa Bình" → "Xây dựng Hòa Bình": the legal form
    // is the same for every company and pushed the distinctive part behind
    // the "…". Long-press shows the full name; screen readers read it.
    final shown = compactOrganizationName(label);
    final chip = Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: math.max(4, (44 - height) / 2),
          ),
          child: Opacity(
            opacity: onTap == null ? 0.55 : 1,
            child: Material(
              color: active ? p.primary : p.surface,
              shape: StadiumBorder(
                side: active ? BorderSide.none : BorderSide(color: p.border),
              ),
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    dense ? 10 : 12,
                    0,
                    showChevron ? (dense ? 10 : 11) : (dense ? 11 : 13),
                    0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: iconSize, color: iconColor),
                        SizedBox(width: dense ? 5 : 6),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          shown,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontSize: fontSize,
                            height: (fontSize + 3) / fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (showChevron) ...[
                        SizedBox(width: dense ? 5 : 6),
                        Icon(
                          LucideIcons.chevronDown,
                          size: size == FilterChipSize.medium ? 18 : 16,
                          color: active ? p.onPrimary : p.text2,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return shown == label ? chip : Tooltip(message: label, child: chip);
  }
}

/// Horizontal scroller of [FilterChipButton]s.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({super.key, required this.children, this.spacing = 8});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(width: spacing),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Selectable option (single or multi) shown in filter sheets. 46px tall.
class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.primaryContainer : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? p.primary : p.inputBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(selected ? 13 : 15, 13, 15, 13),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(
                    LucideIcons.check,
                    size: 16,
                    color: p.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? p.onPrimaryContainer : p.text1,
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrap of [OptionChip]s for a single-choice value.
class OptionChipGroup<T> extends StatelessWidget {
  const OptionChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          OptionChip(
            label: label,
            selected: value == selected,
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}

/// Label + tappable field that opens a picker. When [value] is set and
/// [onClear] is provided, a clear button replaces the chevron.
class SelectFieldButton extends StatelessWidget {
  const SelectFieldButton({
    super.key,
    required this.label,
    required this.placeholder,
    required this.onTap,
    this.value,
    this.onClear,
    this.icon,
    this.enabled = true,
    this.errorText,
    this.trailingIcon = LucideIcons.chevronDown,
  });

  final String label;
  final String placeholder;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final IconData? icon;
  final bool enabled;
  final String? errorText;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasValue = value != null && value!.isNotEmpty;
    final highlighted = hasValue && onClear != null;
    final borderColor = errorText != null
        ? p.danger
        : highlighted
        ? p.primary
        : p.inputBorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label),
        const SizedBox(height: 6),
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: borderColor,
                width: highlighted || errorText != null ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? onTap : null,
              // At least 48pt; long values ("Công ty Cổ phần …") wrap to a
              // second line instead of hiding the distinctive part.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: p.text3),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          hasValue ? value! : placeholder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasValue ? p.text1 : p.text3,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (highlighted)
                      IconButton(
                        tooltip: 'Bỏ chọn',
                        onPressed: enabled ? onClear : null,
                        icon: Icon(LucideIcons.x, size: 18, color: p.text2),
                      )
                    else ...[
                      Icon(trailingIcon, size: 20, color: p.text3),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          FieldError(errorText!),
        ],
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.palette.text3,
      fontSize: 12,
      height: 15 / 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );
}

class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.triangleAlert, size: 15, color: p.danger),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: p.danger,
              fontSize: 13,
              height: 17 / 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Form text input with its label above the box (Figma S08/S11). Mark
/// required fields by ending [label] with " *".
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.validator,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: minLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          style: TextStyle(
            color: p.text1,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            helperMaxLines: 3,
            helperStyle: TextStyle(color: p.text3, fontSize: 13),
            errorText: errorText,
            errorMaxLines: 3,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Uppercase group label followed by its fields, 14px apart (form screens).
class FormFieldGroup extends StatelessWidget {
  const FormFieldGroup({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel(label),
        const SizedBox(height: 10),
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          children[index],
        ],
      ],
    );
  }
}

enum AppButtonVariant { primary, ghost, danger, outline, text, tonal }

/// 46px button used across the redesign.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = switch (variant) {
      AppButtonVariant.primary => (p.primary, p.onPrimary),
      AppButtonVariant.ghost => (p.surfaceMuted, p.text1),
      AppButtonVariant.danger => (p.danger, p.onPrimary),
      AppButtonVariant.tonal => (p.primaryContainer, p.onPrimaryContainer),
      AppButtonVariant.outline => (Colors.transparent, p.text1),
      AppButtonVariant.text => (Colors.transparent, p.text2),
    };
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        // A button label is never cut: it shrinks to fit (large fonts).
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                height: 20 / 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
    final enabled = onPressed != null && !loading;
    final outlined = variant == AppButtonVariant.outline;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: variant == AppButtonVariant.outline
              ? BorderSide(color: p.border, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: outlined ? 49 : 46),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: outlined ? 14.5 : 13,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 44×44 flat icon button (app bars, row actions).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22, color: color ?? p.text1),
    );
    if (badgeCount == null || badgeCount == 0) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(top: 3, right: 3, child: CountBadge(count: badgeCount!)),
      ],
    );
  }
}

/// 44×44 bordered icon button of tab title bars (Đơn hàng / Thống kê).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badgeCount,
    this.loading = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final int? badgeCount;
  final bool loading;

  /// 44 (v3 screens) or 40 (Orders / Notifications baseline frames).
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = size >= 44 ? 14.0 : 13.0;
    final button = Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: p.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: loading ? null : onPressed,
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: loading
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.primary,
                          ),
                        )
                      : Icon(
                          icon,
                          size: size >= 44 ? 21 : 22,
                          color: onPressed == null ? p.text3 : p.text1,
                        ),
                ),
              ),
            ),
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(top: -4, right: -4, child: CountBadge(count: badgeCount!)),
      ],
    );
    // 40pt drawn, 44pt tappable.
    return size >= 44
        ? button
        : TapArea(onTap: loading ? null : onPressed, child: button);
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(minWidth: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: p.primary,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: p.canvas, width: 2),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.onPrimary,
            fontSize: 11,
            height: 13 / 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Large title row of a bottom-tab root screen (22px + round buttons;
/// [large] = the 25px "Hệ thống" title of S01).
class TabTitleBar extends StatelessWidget {
  const TabTitleBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.large = false,
    this.horizontalPadding = 16,
  });

  final String title;
  final List<Widget> actions;

  /// Usually a [BackButton] when the screen is pushed outside the shell.
  final Widget? leading;
  final bool large;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        leading == null ? horizontalPadding : 4,
        large ? 11 : 6,
        horizontalPadding,
        large ? 18 : 8,
      ),
      child: SizedBox(
        height: large ? 30 : 44,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 2)],
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    color: p.text1,
                    fontSize: large ? 25 : 22,
                    height: large ? 30 / 25 : 27 / 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: 10),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// Filled search input (muted background, search icon, clear button).
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: p.inputBorder),
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: p.text1, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: p.surface,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: p.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          prefixIcon: Icon(LucideIcons.search, color: p.text3, size: 20),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xóa nội dung tìm kiếm',
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                  icon: Icon(LucideIcons.x, color: p.text2, size: 18),
                ),
        ),
      ),
    );
  }
}

/// Makes the area around a small control tappable up to [minSize] (44×44,
/// ui-ux-pro-max "Touch Target Size") without changing what is drawn: the
/// child stays centred and keeps its own ink; taps on the ring around it call
/// [onTap] too.
class TapArea extends StatelessWidget {
  const TapArea({
    super.key,
    required this.onTap,
    required this.child,
    this.minSize = 44,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double minSize;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTap: onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    ),
  );
}

/// Selected item with a remove button (stations of the user form). The pill
/// is 36pt; the ✕ gets a full 44×44 tap area (Flutter's InputChip only
/// reacts on its 18pt icon).
class RemovableChip extends StatelessWidget {
  const RemovableChip({
    super.key,
    required this.label,
    required this.onRemove,
    this.removeTooltip = 'Bỏ',
  });

  final String label;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.fromLTRB(12, 0, 38, 0),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.inputBorder),
            ),
            // Hug the label (an aligned Container would fill the row).
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.text1,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            top: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              label: '$removeTooltip $label',
              child: Tooltip(
                message: removeTooltip,
                child: InkResponse(
                  onTap: onRemove,
                  radius: 20,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(LucideIcons.x, size: 16, color: p.text2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
