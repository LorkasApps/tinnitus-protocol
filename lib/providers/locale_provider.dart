import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

/// User-selected locale override, or null to follow the system locale.
///
/// The initial value is provided in `main()` via [ProviderScope.overrides]
/// after reading [loadSavedLocale] from persistent storage.
final localeProvider = StateProvider<Locale?>((ref) => null);

Future<Locale?> loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kLocaleKey);
  return code == null ? null : Locale(code);
}

Future<void> persistLocale(Locale? locale) async {
  final prefs = await SharedPreferences.getInstance();
  if (locale == null) {
    await prefs.remove(_kLocaleKey);
  } else {
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}
