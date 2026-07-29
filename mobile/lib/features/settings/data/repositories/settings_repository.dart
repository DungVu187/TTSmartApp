abstract interface class SettingsRepository {
  Future<bool> getNotificationsEnabled();

  Future<void> setNotificationsEnabled(bool value);
}

class MemorySettingsRepository implements SettingsRepository {
  bool _notificationsEnabled = true;

  @override
  Future<bool> getNotificationsEnabled() async => _notificationsEnabled;

  @override
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
  }
}
