String formatVietnamIsoOffset(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  String threeDigits(int number) => number.toString().padLeft(3, '0');
  final date =
      '${value.year.toString().padLeft(4, '0')}-'
      '${twoDigits(value.month)}-${twoDigits(value.day)}';
  final time =
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}:'
      '${twoDigits(value.second)}';
  return value.millisecond == 0
      ? '${date}T$time+07:00'
      : '${date}T$time.${threeDigits(value.millisecond)}+07:00';
}

DateTime vietnamDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime vietnamExclusiveDayAfter(DateTime inclusiveDate) =>
    DateTime(inclusiveDate.year, inclusiveDate.month, inclusiveDate.day + 1);

DateTime utcToVietnamTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 7));
