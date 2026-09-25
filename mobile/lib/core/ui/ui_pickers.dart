import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_palette.dart';
import 'ui_controls.dart';
import 'ui_list.dart';

class PickerOption<T> {
  const PickerOption({required this.value, required this.title, this.subtitle});

  final T value;
  final String title;
  final String? subtitle;
}

/// Result of [showPickerSheet]. `null` from the future means the sheet was
/// dismissed; a selection whose [value] is `null` means "clear".
class PickerSelection<T> {
  const PickerSelection(this.value);

  final T? value;
}

/// Accent-insensitive lower-case form so "tram ha nam" finds "Trạm Hà Nam".
String foldVietnamese(String input) {
  const groups = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().characters) {
    var replaced = char;
    for (final entry in groups.entries) {
      if (entry.value.contains(char)) {
        replaced = entry.key;
        break;
      }
    }
    buffer.write(replaced);
  }
  return buffer.toString();
}

/// Searchable single-choice list in a bottom sheet (station, company, plate…).
Future<PickerSelection<T>?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
  String searchHint = 'Tìm kiếm',
  String? clearLabel,
  IconData? icon,
  AppTone tone = AppTone.primary,
  String emptyMessage = 'Không có dữ liệu phù hợp.',
}) {
  return showModalBottomSheet<PickerSelection<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PickerSheet<T>(
      title: title,
      options: options,
      selected: selected,
      searchHint: searchHint,
      clearLabel: clearLabel,
      icon: icon,
      tone: tone,
      emptyMessage: emptyMessage,
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchHint,
    required this.clearLabel,
    required this.icon,
    required this.tone,
    required this.emptyMessage,
  });

  final String title;
  final List<PickerOption<T>> options;
  final T? selected;
  final String searchHint;
  final String? clearLabel;
  final IconData? icon;
  final AppTone tone;
  final String emptyMessage;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PickerOption<T>> get _visible {
    if (_query.isEmpty) return widget.options;
    final needle = foldVietnamese(_query.trim());
    return widget.options
        .where(
          (option) => foldVietnamese(
            '${option.title} ${option.subtitle ?? ''}',
          ).contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final visible = _visible;
    final showSearch = widget.options.length > 4;
    final rows = <Widget>[
      if (widget.clearLabel != null && _query.isEmpty)
        _PickerRow(
          title: widget.clearLabel!,
          selected: widget.selected == null,
          onTap: () => Navigator.pop(context, PickerSelection<T>(null)),
        ),
      for (final option in visible)
        _PickerRow(
          title: option.title,
          subtitle: option.subtitle,
          icon: widget.icon,
          tone: widget.tone,
          selected: option.value == widget.selected,
          onTap: () => Navigator.pop(context, PickerSelection<T>(option.value)),
        ),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: p.text1,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: LucideIcons.x,
                    tooltip: 'Đóng',
                    color: p.text2,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: AppSearchField(
                  controller: _search,
                  hintText: widget.searchHint,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          widget.emptyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.text2, fontSize: 15),
                        ),
                      )
                    : Material(
                        color: p.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: p.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          shrinkWrap: true,
                          // No automatic safe-area inset inside the card.
                          padding: EdgeInsets.zero,
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: widget.icon == null
                                ? kTextDividerIndent
                                : kLeadingDividerIndent,
                          ),
                          itemBuilder: (_, index) => rows[index],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.tone = AppTone.primary,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: NavRow(
        title: title,
        titleMaxLines: 2,
        subtitle: subtitle,
        background: selected ? p.primaryContainer : null,
        titleStyle: TextStyle(
          color: p.text1,
          fontSize: 16,
          height: 21 / 16,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
        leading: icon == null
            ? null
            : IconTile(
                icon: icon!,
                tone: tone,
                background: selected ? p.surface : null,
              ),
        showChevron: false,
        trailing: selected
            ? Icon(LucideIcons.circleCheck, size: 22, color: p.primary)
            : Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.inputBorder, width: 1.5),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
