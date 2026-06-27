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

    test('setLocale persists the choice and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setLocale(const Locale('ms'));

      expect(settings.locale.languageCode, 'ms');
      expect(notified, 1);
      expect((await AppSettings.load()).locale.languageCode, 'ms');
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
