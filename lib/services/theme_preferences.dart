import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_style.dart';

class ThemePreferences extends ChangeNotifier {
  static const _darkModeKey = 'howbuddy_dark_mode';

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _isDarkMode = preferences.getBool(_darkModeKey) ?? false;
    AppColors.isDarkMode = _isDarkMode;
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_isDarkMode == enabled) return;
    _isDarkMode = enabled;
    AppColors.isDarkMode = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_darkModeKey, enabled);
    } catch (_) {
      // Keep the selected theme for this session if device storage is unavailable.
    }
  }
}

class ThemePreferencesScope extends InheritedNotifier<ThemePreferences> {
  const ThemePreferencesScope({
    required this.preferences,
    required super.child,
    super.key,
  }) : super(notifier: preferences);

  final ThemePreferences preferences;

  static ThemePreferences of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemePreferencesScope>();
    assert(
      scope != null,
      'ThemePreferencesScope is missing above this context.',
    );
    return scope!.notifier!;
  }

  static void watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<ThemePreferencesScope>();
  }
}
