import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the app's [ThemeMode].
///
/// Starts on [ThemeMode.system] until the user pins light/dark with the
/// in-app switch. That choice is written to [SharedPreferences] and restored
/// on the next launch; clearing it (long-press) returns to the platform.
class ThemeManager with ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get followsSystem => _themeMode == ThemeMode.system;

  /// The brightness the platform currently reports.
  Brightness get platformBrightness =>
      SchedulerBinding.instance.platformDispatcher.platformBrightness;

  /// The brightness that is actually painted right now, resolving
  /// [ThemeMode.system] against the platform.
  Brightness get resolvedBrightness => switch (_themeMode) {
        ThemeMode.dark => Brightness.dark,
        ThemeMode.light => Brightness.light,
        ThemeMode.system => platformBrightness,
      };

  bool get isDark => resolvedBrightness == Brightness.dark;

  /// Restore a previously pinned mode, or leave [ThemeMode.system] alone.
  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null) return;

    final mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
    if (mode == null || mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, mode.name);
    }
  }

  /// Pins an explicit mode — used by the switch in the side menu.
  Future<void> toggleTheme(bool isDark) =>
      setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);

  /// Flips whatever is on screen right now, even while following the system.
  Future<void> toggle() => toggleTheme(!isDark);

  /// Hands control back to the platform setting and clears the saved pin.
  Future<void> useSystemTheme() => setThemeMode(ThemeMode.system);
}
