import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSettings language', () {
    test('defaults to English when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      expect(settings.locale.languageCode, 'en');
    });

    test('setLocale keeps English as the only supported language', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setLocale(const Locale('fr'));

      expect(settings.locale.languageCode, 'en');
      expect(notified, 0);
      expect((await AppSettings.load()).locale.languageCode, 'en');
    });

    test('setting the same locale does not notify', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setLocale(const Locale('en'));

      expect(notified, 0);
    });

    test('falls back to English for an unsupported saved code', () async {
      SharedPreferences.setMockInitialValues({'settings.localeCode': 'fr'});
      final settings = await AppSettings.load();
      expect(settings.locale.languageCode, 'en');
    });
  });
}
