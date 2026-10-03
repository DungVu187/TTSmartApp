import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the Light / Dark / System choice is kept between launches.
abstract interface class ThemePreferenceStore {
  Future<String?> read();

  Future<void> write(String value);
}

class SecureThemePreferenceStore implements ThemePreferenceStore {
  SecureThemePreferenceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ui.themeMode';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

/// In-memory store for tests and previews.
class MemoryThemePreferenceStore implements ThemePreferenceStore {
  MemoryThemePreferenceStore([this._value]);

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;
}

/// Light / Dark / follow the phone (Figma A03 "Giao diện").
class ThemeController extends ChangeNotifier {
  ThemeController({
    ThemePreferenceStore? store,
    ThemeMode initialMode = ThemeMode.system,
  }) : _store = store ?? MemoryThemePreferenceStore(),
       _mode = initialMode;

  final ThemePreferenceStore _store;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  /// Reads the saved choice; unreadable storage keeps "Theo hệ thống".
  Future<void> load() async {
    try {
      _mode = _parse(await _store.read());
    } on Object {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _store.write(mode.name);
    } on Object {
      // The choice still applies for this session.
    }
  }

  static ThemeMode _parse(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
