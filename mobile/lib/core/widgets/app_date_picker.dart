import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ui/app_ui.dart';

enum AppDateRangePreset { today, yesterday, sevenDays, thirtyDays, custom }

class AppDateRangeSelection {
  const AppDateRangeSelection({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class AppDatePickerResult {
  const AppDatePickerResult({this.date, this.cleared = false});

  final DateTime? date;
  final bool cleared;
}

Future<AppDateRangeSelection?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime initialStart,
  required DateTime initialEnd,
  DateTime? now,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'Chọn khoảng thời gian',
  String keyPrefix = 'app-date-range',
}) {
  final current = now ?? DateTime.now();
  final minimum = _dateOnly(firstDate ?? DateTime(2000));
  final maximum = _dateOnly(lastDate ?? DateTime(current.year + 20, 12, 31));
  return showAppModalSheet<AppDateRangeSelection>(
    context: context,
    builder: (_) => AppDateRangePickerSheet(
      initialStart: initialStart,
      initialEnd: initialEnd,
      now: current,
      firstDate: minimum,
      lastDate: maximum,
      title: title,
      keyPrefix: keyPrefix,
    ),
  );
}

Future<AppDatePickerResult?> showAppDatePicker({
  required BuildContext context,
  required DateTime? initialDate,
  DateTime? now,
  DateTime? firstDate,
  DateTime? lastDate,
  required String title,
  String keyPrefix = 'app-date-picker',
  bool allowClear = false,
  bool showTime = false,
}) {
  final current = now ?? DateTime.now();
  final minimum = _dateOnly(firstDate ?? DateTime(current.year - 1));
  final maximum = _dateOnly(lastDate ?? DateTime(current.year + 20, 12, 31));
  return showAppModalSheet<AppDatePickerResult>(
    context: context,
    builder: (_) => AppDatePickerSheet(
      initialDate: initialDate,
      firstDate: minimum,
      lastDate: maximum,
      title: title,
      keyPrefix: keyPrefix,
      allowClear: allowClear,
      showTime: showTime,
    ),
  );
}

/// Figma C15: presets, Từ/Đến fields, month calendar with the range band,
/// time of the active field, Hủy / Áp dụng.
class AppDateRangePickerSheet extends StatefulWidget {
  const AppDateRangePickerSheet({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    required this.now,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.keyPrefix,
  });

  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime now;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String keyPrefix;

  @override
  State<AppDateRangePickerSheet> createState() =>
      _AppDateRangePickerSheetState();
}

class _AppDateRangePickerSheetState extends State<AppDateRangePickerSheet> {
  late DateTime _start;
  late DateTime _end;
  var _activeField = _AppDateField.start;

  @override
  void initState() {
    super.initState();
    _start = _clampDateTime(
      widget.initialStart,
      widget.firstDate,
      widget.lastDate,
    );
    _end = _clampDateTime(widget.initialEnd, widget.firstDate, widget.lastDate);
    if (_end.isBefore(_start)) _end = _start;
  }

  @override
  Widget build(BuildContext context) {
    final activeDate = _activeField == _AppDateField.start ? _start : _end;
    return AppSheetFrame(
      title: widget.title,
      closeKey: ValueKey<String>('${widget.keyPrefix}-close'),
      scrollKey: ValueKey<String>('${widget.keyPrefix}-sheet'),
      footer: _SheetActions(
        keyPrefix: widget.keyPrefix,
        enabled: _end.isAfter(_start),
        onApply: () => Navigator.pop(
          context,
          AppDateRangeSelection(start: _start, end: _end),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PresetRow(
            keyPrefix: widget.keyPrefix,
            selected: _presetForSelection(),
            onSelected: _selectPreset,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  key: ValueKey<String>('${widget.keyPrefix}-from-field'),
                  label: 'Từ ngày',
                  value: _start,
                  active: _activeField == _AppDateField.start,
                  showTime: true,
                  onTap: () =>
                      setState(() => _activeField = _AppDateField.start),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  key: ValueKey<String>('${widget.keyPrefix}-to-field'),
                  label: 'Đến ngày',
                  value: _end,
                  active: _activeField == _AppDateField.end,
                  showTime: true,
                  onTap: () => setState(() => _activeField = _AppDateField.end),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MonthRangeCalendar(
            key: ValueKey<String>(
              '${widget.keyPrefix}-calendar-${activeDate.year}-'
              '${activeDate.month}-${activeDate.day}',
            ),
            keyPrefix: widget.keyPrefix,
            activeDate: activeDate,
            startDate: _start,
            endDate: _end,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            onDateSelected: _selectDate,
          ),
          const SizedBox(height: 12),
          _TimeSelector(
            keyPrefix: widget.keyPrefix,
            fieldLabel: _activeField == _AppDateField.start
                ? 'Từ ngày'
                : 'Đến ngày',
            value: activeDate,
            onHourChanged: (hour) => _updateActiveTime(hour: hour),
            onMinuteChanged: (minute) => _updateActiveTime(minute: minute),
          ),
        ],
      ),
    );
  }

  void _selectDate(DateTime value) {
    final date = _dateOnly(value);
    setState(() {
      if (_activeField == _AppDateField.start) {
        _start = _withDate(_start, date);
        if (_end.isBefore(_start)) _end = _start;
        _activeField = _AppDateField.end;
      } else {
        _end = _withDate(_end, date);
        if (_end.isBefore(_start)) _start = _end;
      }
    });
  }

  void _updateActiveTime({int? hour, int? minute}) {
    final active = _activeField == _AppDateField.start ? _start : _end;
    final next = _withTime(
      active,
      hour ?? active.hour,
      minute ?? active.minute,
      isEnd: _activeField == _AppDateField.end,
    );
    setState(() {
      if (_activeField == _AppDateField.start) {
        _start = next;
      } else {
        _end = next;
      }
    });
  }

  void _selectPreset(AppDateRangePreset value) {
    if (value == AppDateRangePreset.custom) {
      setState(() => _activeField = _AppDateField.start);
      return;
    }
    final today = _dateOnly(widget.now);
    final values = switch (value) {
      AppDateRangePreset.today => (_startOfDay(today), widget.now),
      AppDateRangePreset.yesterday => (
        _startOfDay(today.subtract(const Duration(days: 1))),
        _endOfDay(today.subtract(const Duration(days: 1))),
      ),
      AppDateRangePreset.sevenDays => (
        _startOfDay(today.subtract(const Duration(days: 6))),
        widget.now,
      ),
      AppDateRangePreset.thirtyDays => (
        _startOfDay(today.subtract(const Duration(days: 29))),
        widget.now,
      ),
      AppDateRangePreset.custom => (widget.now, widget.now),
    };
    setState(() {
      _start = _clampDateTime(values.$1, widget.firstDate, widget.lastDate);
      _end = _clampDateTime(values.$2, widget.firstDate, widget.lastDate);
      _activeField = _AppDateField.end;
    });
  }

  AppDateRangePreset _presetForSelection() {
    final today = _dateOnly(widget.now);
    if (_sameDay(_start, today) && _start.hour == 0 && _start.minute == 0) {
      return AppDateRangePreset.today;
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (_sameDay(_start, yesterday) &&
        _sameDay(_end, yesterday) &&
        _start.hour == 0 &&
        _start.minute == 0) {
      return AppDateRangePreset.yesterday;
    }
    if (_sameDay(_start, today.subtract(const Duration(days: 6))) &&
        _sameDay(_end, today) &&
        _start.hour == 0 &&
        _start.minute == 0) {
      return AppDateRangePreset.sevenDays;
    }
    if (_sameDay(_start, today.subtract(const Duration(days: 29))) &&
        _sameDay(_end, today) &&
        _start.hour == 0 &&
        _start.minute == 0) {
      return AppDateRangePreset.thirtyDays;
    }
    return AppDateRangePreset.custom;
  }
}

class AppDatePickerSheet extends StatefulWidget {
  const AppDatePickerSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.keyPrefix,
    required this.allowClear,
    required this.showTime,
  });

  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String keyPrefix;
  final bool allowClear;
  final bool showTime;

  @override
  State<AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<AppDatePickerSheet> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final clamped = _clampDateTime(
      widget.initialDate ?? DateTime.now(),
      widget.firstDate,
      widget.lastDate,
    );
    _date = widget.showTime ? clamped : _dateOnly(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetFrame(
      title: widget.title,
      closeKey: ValueKey<String>('${widget.keyPrefix}-close'),
      scrollKey: ValueKey<String>('${widget.keyPrefix}-sheet'),
      footer: _SheetActions(
        keyPrefix: widget.keyPrefix,
        onApply: () => Navigator.pop(context, AppDatePickerResult(date: _date)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateField(
            key: ValueKey<String>('${widget.keyPrefix}-field'),
            label: 'Ngày',
            value: _date,
            active: true,
            showTime: widget.showTime,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _MonthRangeCalendar(
            key: ValueKey<String>(
              '${widget.keyPrefix}-calendar-${_date.year}-'
              '${_date.month}-${_date.day}',
            ),
            keyPrefix: widget.keyPrefix,
            activeDate: _date,
            startDate: _date,
            endDate: _date,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            onDateSelected: (value) => setState(
              () => _date = widget.showTime
                  ? _withDate(_date, value)
                  : _dateOnly(value),
            ),
          ),
          if (widget.allowClear) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                key: ValueKey<String>('${widget.keyPrefix}-clear'),
                label: 'Bỏ giới hạn thời gian',
                icon: LucideIcons.x,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () => Navigator.pop(
                  context,
                  const AppDatePickerResult(cleared: true),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Five equal cells: Hôm nay / Hôm qua / 7 ngày / 30 ngày / Tùy chọn.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.keyPrefix,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
  final AppDateRangePreset selected;
  final ValueChanged<AppDateRangePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (final preset in AppDateRangePreset.values) ...[
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == preset,
              child: Material(
                key: ValueKey<String>('$keyPrefix-preset-${preset.name}'),
                color: selected == preset ? p.primary : p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected == preset ? p.primary : p.border,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(preset),
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _presetLabel(preset),
                            maxLines: 1,
                            style: TextStyle(
                              color: selected == preset ? p.onPrimary : p.text1,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (preset != AppDateRangePreset.values.last)
            const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// Label above a 48px box; the active field (which the calendar and the
/// time row edit) gets the primary border.
class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.active,
    required this.showTime,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final bool active;
  final bool showTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The label is part of the tap target too.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: double.infinity,
                child: FieldLabel(label.toUpperCase()),
              ),
            ),
          ),
          Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: active ? p.primary : p.border,
                width: active ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        showTime
                            ? '${_formatDate(value)} ${_formatTime(value)}'
                            : _formatDate(value),
                        maxLines: 1,
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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

/// Hour : minute of the active field.
class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.keyPrefix,
    required this.fieldLabel,
    required this.value,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final String keyPrefix;
  final String fieldLabel;
  final DateTime value;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(LucideIcons.clock, size: 20, color: p.text2),
        const SizedBox(width: 8),
        Text(
          'Chọn giờ',
          style: TextStyle(
            color: p.text1,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '· $fieldLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.text3,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _TimeDropdown(
          key: ValueKey<String>('$keyPrefix-hour'),
          value: value.hour,
          max: 23,
          onChanged: onHourChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            ':',
            style: TextStyle(color: p.text1, fontWeight: FontWeight.w800),
          ),
        ),
        _TimeDropdown(
          key: ValueKey<String>('$keyPrefix-minute'),
          value: value.minute,
          max: 59,
          onChanged: onMinuteChanged,
        ),
      ],
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 44,
      width: 76,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          dropdownColor: p.surface,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(LucideIcons.chevronDown, size: 18, color: p.text3),
          // Merged with the theme so the app font family applies.
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: p.text1,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (var item = 0; item <= max; item++)
              DropdownMenuItem<int>(
                value: item,
                child: Text(item.toString().padLeft(2, '0')),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

/// Month grid in a card. Days between start and end sit on a continuous
/// band; the start and end days are filled circles.
class _MonthRangeCalendar extends StatefulWidget {
  const _MonthRangeCalendar({
    super.key,
    required this.keyPrefix,
    required this.activeDate,
    required this.startDate,
    required this.endDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  });

  final String keyPrefix;
  final DateTime activeDate;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<_MonthRangeCalendar> createState() => _MonthRangeCalendarState();
}

class _MonthRangeCalendarState extends State<_MonthRangeCalendar> {
  static const _rowHeight = 42.0;
  static const _dayExtent = 38.0;

  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.activeDate.year, widget.activeDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final leading = monthStart.weekday - DateTime.monday;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final weeks = ((leading + daysInMonth) / 7).ceil();
    final canGoPrevious = _monthAfter(
      _visibleMonth,
      DateTime(widget.firstDate.year, widget.firstDate.month),
    );
    final canGoNext = _monthBefore(
      _visibleMonth,
      DateTime(widget.lastDate.year, widget.lastDate.month),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: ValueKey<String>('${widget.keyPrefix}-month-previous'),
                tooltip: 'Tháng trước',
                onPressed: canGoPrevious ? _previousMonth : null,
                color: p.text1,
                disabledColor: p.text3,
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Tháng ${_visibleMonth.month}, ${_visibleMonth.year}',
                    style: TextStyle(
                      color: p.text1,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey<String>('${widget.keyPrefix}-month-next'),
                tooltip: 'Tháng sau',
                onPressed: canGoNext ? _nextMonth : null,
                color: p.text1,
                disabledColor: p.text3,
                icon: const Icon(LucideIcons.chevronRight),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (final label in const [
                'T2',
                'T3',
                'T4',
                'T5',
                'T6',
                'T7',
                'CN',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: p.text3,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var week = 0; week < weeks; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: _buildDay(
                      context,
                      week * 7 + weekday - leading + 1,
                      daysInMonth,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDay(BuildContext context, int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: _rowHeight);
    }
    final p = context.palette;
    final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
    final selectable =
        !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
    final start = _dateOnly(widget.startDate);
    final end = _dateOnly(widget.endDate);
    final isStart = _sameDay(date, start);
    final isEnd = _sameDay(date, end);
    final inRange = !date.isBefore(start) && !date.isAfter(end);
    final hasBand = inRange && !_sameDay(start, end);
    final bandColor = p.primaryContainer;
    final selected = isStart || isEnd;
    return SizedBox(
      height: _rowHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasBand)
            Positioned.fill(
              top: (_rowHeight - _dayExtent) / 2,
              bottom: (_rowHeight - _dayExtent) / 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: isStart ? Colors.transparent : bandColor,
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: isEnd ? Colors.transparent : bandColor,
                    ),
                  ),
                ],
              ),
            ),
          InkResponse(
            radius: _dayExtent / 2 + 2,
            onTap: selectable ? () => widget.onDateSelected(date) : null,
            child: Container(
              width: _dayExtent,
              height: _dayExtent,
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(color: p.primary, shape: BoxShape.circle)
                  : null,
              child: Text(
                '$day',
                style: TextStyle(
                  color: selected
                      ? p.onPrimary
                      : selectable
                      ? p.text1
                      : p.text3,
                  fontSize: 15,
                  fontWeight: selected || inRange
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousMonth() => setState(
    () => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1),
  );

  void _nextMonth() => setState(
    () => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1),
  );
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.keyPrefix,
    required this.onApply,
    this.enabled = true,
  });

  final String keyPrefix;
  final VoidCallback onApply;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            key: ValueKey<String>('$keyPrefix-cancel'),
            label: 'Hủy',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppButton(
            key: ValueKey<String>('$keyPrefix-apply'),
            label: 'Áp dụng',
            icon: LucideIcons.check,
            onPressed: enabled ? onApply : null,
          ),
        ),
      ],
    );
  }
}

enum _AppDateField { start, end }

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _startOfDay(DateTime value) => _dateOnly(value);

DateTime _endOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

DateTime _withDate(DateTime value, DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
);

DateTime _withTime(
  DateTime value,
  int hour,
  int minute, {
  required bool isEnd,
}) => DateTime(
  value.year,
  value.month,
  value.day,
  hour,
  minute,
  isEnd ? 59 : 0,
  isEnd ? 999 : 0,
);

DateTime _clampDateTime(DateTime value, DateTime firstDate, DateTime lastDate) {
  final date = _dateOnly(value);
  if (date.isBefore(firstDate)) return _withDate(value, firstDate);
  if (date.isAfter(lastDate)) return _withDate(value, lastDate);
  return value;
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

bool _monthAfter(DateTime value, DateTime minimum) =>
    value.year > minimum.year ||
    (value.year == minimum.year && value.month > minimum.month);

bool _monthBefore(DateTime value, DateTime maximum) =>
    value.year < maximum.year ||
    (value.year == maximum.year && value.month < maximum.month);

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _presetLabel(AppDateRangePreset preset) => switch (preset) {
  AppDateRangePreset.today => 'Hôm nay',
  AppDateRangePreset.yesterday => 'Hôm qua',
  AppDateRangePreset.sevenDays => '7 ngày',
  AppDateRangePreset.thirtyDays => '30 ngày',
  AppDateRangePreset.custom => 'Tùy chọn',
};
