import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
  return showModalBottomSheet<AppDateRangeSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
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
  return showModalBottomSheet<AppDatePickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
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
    return _SheetFrame(
      keyPrefix: widget.keyPrefix,
      title: widget.title,
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
          const SizedBox(height: 4),
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
          const SizedBox(height: 4),
          _TimeSelector(
            keyPrefix: widget.keyPrefix,
            value: activeDate,
            onHourChanged: (hour) => _updateActiveTime(hour: hour),
            onMinuteChanged: (minute) => _updateActiveTime(minute: minute),
          ),
          const SizedBox(height: 8),
          _SheetActions(
            keyPrefix: widget.keyPrefix,
            enabled: _end.isAfter(_start),
            onApply: () => Navigator.pop(
              context,
              AppDateRangeSelection(start: _start, end: _end),
            ),
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
    return _SheetFrame(
      keyPrefix: widget.keyPrefix,
      title: widget.title,
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
          const SizedBox(height: 4),
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
          if (widget.allowClear)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey<String>('${widget.keyPrefix}-clear'),
                onPressed: () => Navigator.pop(
                  context,
                  const AppDatePickerResult(cleared: true),
                ),
                icon: const Icon(Icons.clear),
                label: const Text('Bỏ giới hạn thời gian'),
              ),
            ),
          const SizedBox(height: 8),
          _SheetActions(
            keyPrefix: widget.keyPrefix,
            onApply: () =>
                Navigator.pop(context, AppDatePickerResult(date: _date)),
          ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.keyPrefix,
    required this.title,
    required this.child,
  });

  final String keyPrefix;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: ValueKey<String>('$keyPrefix-sheet'),
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey<String>('$keyPrefix-close'),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in AppDateRangePreset.values) ...[
            ChoiceChip(
              key: ValueKey<String>('$keyPrefix-preset-${preset.name}'),
              label: Text(_presetLabel(preset)),
              selected: selected == preset,
              showCheckmark: false,
              selectedColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                color: selected == preset
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onSelected(preset),
            ),
            if (preset != AppDateRangePreset.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final borderColor = active ? theme.colorScheme.primary : AppColors.border;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: active ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 10,
                  height: 14 / 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: borderColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatDate(value),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              if (showTime) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      size: 16,
                      color: borderColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(value),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.keyPrefix,
    required this.value,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final String keyPrefix;
  final DateTime value;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn giờ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TimeDropdown(
              key: ValueKey<String>('$keyPrefix-hour'),
              value: value.hour,
              max: 23,
              onChanged: onHourChanged,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(':', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            _TimeDropdown(
              key: ValueKey<String>('$keyPrefix-minute'),
              value: value.minute,
              max: 59,
              onChanged: onMinuteChanged,
            ),
          ],
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
    return Container(
      height: 38,
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 13,
            height: 18 / 13,
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
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.activeDate.year, widget.activeDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final gridStart = monthStart.subtract(
      Duration(days: monthStart.weekday - DateTime.monday),
    );
    final canGoPrevious = _monthAfter(
      _visibleMonth,
      DateTime(widget.firstDate.year, widget.firstDate.month),
    );
    final canGoNext = _monthBefore(
      _visibleMonth,
      DateTime(widget.lastDate.year, widget.lastDate.month),
    );
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: ValueKey<String>('${widget.keyPrefix}-month-previous'),
              onPressed: canGoPrevious ? _previousMonth : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Tháng ${_visibleMonth.month}, ${_visibleMonth.year}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            IconButton(
              key: ValueKey<String>('${widget.keyPrefix}-month-next'),
              onPressed: canGoNext ? _nextMonth : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 190,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 30,
            ),
            itemBuilder: (context, index) {
              final date = gridStart.add(Duration(days: index));
              return _buildDay(context, date, monthStart.month);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDay(BuildContext context, DateTime date, int month) {
    final inMonth = date.month == month;
    final selectable =
        !_dateOnly(date).isBefore(widget.firstDate) &&
        !_dateOnly(date).isAfter(widget.lastDate);
    final isStart = _sameDay(date, widget.startDate);
    final isEnd = _sameDay(date, widget.endDate);
    final inRange =
        !date.isBefore(_dateOnly(widget.startDate)) &&
        !date.isAfter(_dateOnly(widget.endDate));
    final theme = Theme.of(context);
    final background = isStart
        ? theme.colorScheme.primary
        : isEnd || inRange
        ? theme.colorScheme.primaryContainer
        : Colors.transparent;
    final foreground = isStart
        ? theme.colorScheme.onPrimary
        : !inMonth || !selectable
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : theme.colorScheme.onSurface;
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: selectable ? () => widget.onDateSelected(date) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '${date.day}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: isStart || isEnd ? FontWeight.w800 : null,
            ),
          ),
        ),
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
          child: SizedBox(
            height: 38,
            child: OutlinedButton(
              key: ValueKey<String>('$keyPrefix-cancel'),
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Hủy'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 38,
            child: FilledButton(
              key: ValueKey<String>('$keyPrefix-apply'),
              onPressed: enabled ? onApply : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Áp dụng'),
            ),
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
