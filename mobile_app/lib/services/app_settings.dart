import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local user preferences: chosen UI language and notification
/// toggles.
///
/// ─── WHY THIS IS NOT IN FIRESTORE ──────────────────────────────────
/// These are presentation/device preferences, not security or domain
/// state. They must work before sign-in (the login screen is localized)
/// and offline, so they live in [SharedPreferences], not the user's
/// Firestore profile. Security-relevant state (role, status, MFA) stays
/// in Firebase Auth / Firestore and is never duplicated here.
/// ────────────────────────────────────────────────────────────────────
///
/// A [ChangeNotifier] so the root [MaterialApp] rebuilds when the locale
/// changes, applying the new language immediately without a restart.
/// Read it anywhere via [SettingsScope.of].
class AppSettings extends ChangeNotifier {
  static const _kLocaleCode = 'settings.localeCode';
  static const _kPushNotifications = 'settings.notifications.push';
  static const _kEmailNotifications = 'settings.notifications.email';
  static const _kAnnouncementNotifications =
      'settings.notifications.announcements';

  /// Languages the app ships translations for. Keep in lockstep with the
  /// .arb files in lib/l10n and AppLocalizations.supportedLocales.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ms'),
  ];

  final SharedPreferences _prefs;

  AppSettings(this._prefs);

  /// Loads persisted preferences. Call once during app startup, before
  /// `runApp`, so the first frame already reflects the saved language.
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(prefs);
  }

  // ── Language ───────────────────────────────────────────────────────

  /// The active locale, defaulting to English when nothing is saved or the
  /// saved code is no longer supported (e.g. a translation was removed).
  Locale get locale {
    final code = _prefs.getString(_kLocaleCode);
    for (final supported in supportedLocales) {
      if (supported.languageCode == code) return supported;
    }
    return const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == this.locale.languageCode) return;
    await _prefs.setString(_kLocaleCode, locale.languageCode);
    notifyListeners();
  }

  // ── Notification preferences ────────────────────────────────────────
  // Default to on: a resident who never opens this screen still gets the
  // alerts they'd reasonably expect.

  bool get pushNotifications => _prefs.getBool(_kPushNotifications) ?? true;
  bool get emailNotifications => _prefs.getBool(_kEmailNotifications) ?? true;
  bool get announcementNotifications =>
      _prefs.getBool(_kAnnouncementNotifications) ?? true;

  Future<void> setPushNotifications(bool value) async {
    await _prefs.setBool(_kPushNotifications, value);
    notifyListeners();
  }

  Future<void> setEmailNotifications(bool value) async {
    await _prefs.setBool(_kEmailNotifications, value);
    notifyListeners();
  }

  Future<void> setAnnouncementNotifications(bool value) async {
    await _prefs.setBool(_kAnnouncementNotifications, value);
    notifyListeners();
  }
}

/// Exposes the single [AppSettings] instance to the widget tree.
///
/// Usage:
///   final settings = SettingsScope.of(context);
///   settings.setLocale(const Locale('ms'));
///
/// Backed by [InheritedNotifier], so widgets that call [of] rebuild when
/// any preference changes.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in the widget tree.');
    return scope!.notifier!;
  }
}
