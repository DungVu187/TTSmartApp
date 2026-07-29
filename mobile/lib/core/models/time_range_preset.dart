enum TimeRangePreset { today, sevenDays, thisMonth }

extension TimeRangePresetLabel on TimeRangePreset {
  String get label => switch (this) {
    TimeRangePreset.today => 'Hôm nay',
    TimeRangePreset.sevenDays => '7 ngày',
    TimeRangePreset.thisMonth => 'Tháng này',
  };
}
