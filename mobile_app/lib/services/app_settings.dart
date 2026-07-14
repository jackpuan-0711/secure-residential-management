import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local app preferences.
///
/// Presentation preferences live in [SharedPreferences] because they must be
/// available before sign-in and while offline. Security-relevant state stays
/// in Firebase Auth / Firestore and is never duplicated here.
class AppSettings extends ChangeNotifier {
  static const _kLocaleCode = 'settings.localeCode';
  static const List<Locale> supportedLocales = [Locale('en')];

  final SharedPreferences _prefs;

  AppSettings(this._prefs);

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(prefs);
  }

  Locale get locale => const Locale('en');

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == 'en') {
      await _prefs.setString(_kLocaleCode, 'en');
      return;
    }
    await _prefs.remove(_kLocaleCode);
  }
}

/// Exposes the single [AppSettings] instance to the widget tree.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in the widget tree.');
    return scope!.notifier!;
  }
}
