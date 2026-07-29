import 'package:flutter/foundation.dart';

import '../../data/repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repository);

  final SettingsRepository _repository;

  bool _notificationsEnabled = true;
  bool _isLoading = false;
  bool _initialized = false;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();
    _notificationsEnabled = await _repository.getNotificationsEnabled();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    await _repository.setNotificationsEnabled(value);
  }
}
