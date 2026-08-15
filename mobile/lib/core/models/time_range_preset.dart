enum TimeRangePreset {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
}

extension TimeRangePresetLabel on TimeRangePreset {
  String get label => switch (this) {
    TimeRangePreset.today => 'Hôm nay',
    TimeRangePreset.yesterday => 'Hôm qua',
    TimeRangePreset.thisWeek => 'Tuần này',
    TimeRangePreset.lastWeek => 'Tuần trước',
    TimeRangePreset.thisMonth => 'Tháng này',
    TimeRangePreset.lastMonth => 'Tháng trước',
  };

  bool get usesHourlyBuckets =>
      this == TimeRangePreset.today || this == TimeRangePreset.yesterday;
}
