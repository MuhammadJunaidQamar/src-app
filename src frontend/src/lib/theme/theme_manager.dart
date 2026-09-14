import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Owns the app's [ThemeMode].
///
/// Starts on [ThemeMode.system] so a fresh launch matches the phone/desktop
/// setting; the first flip of the in-app switch pins an explicit mode.
class ThemeManager with ChangeNotifier {
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

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  /// Pins an explicit mode — used by the switch in the side menu.
  void toggleTheme(bool isDark) =>
      setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);

  /// Flips whatever is on screen right now, even while following the system.
  void toggle() => toggleTheme(!isDark);

  /// Hands control back to the platform setting.
  void useSystemTheme() => setThemeMode(ThemeMode.system);
}
