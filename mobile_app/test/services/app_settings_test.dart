import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSettings — language', () {
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

      // A fresh load reads the persisted value.
      final reloaded = await AppSettings.load();
      expect(reloaded.locale.languageCode, 'ms');
    });

    test('setting the same locale does not notify', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();

      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setLocale(const Locale('en')); // already en
      expect(notified, 0);
    });

    test('falls back to English when the saved code is unsupported', () async {
      SharedPreferences.setMockInitialValues({
        'settings.localeCode': 'fr', // not shipped
      });
      final settings = await AppSettings.load();
      expect(settings.locale.languageCode, 'en');
    });
  });

  group('AppSettings — notification preferences', () {
    test('all channels default to enabled', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();

      expect(settings.pushNotifications, isTrue);
      expect(settings.emailNotifications, isTrue);
      expect(settings.announcementNotifications, isTrue);
    });

    test('toggles persist and notify', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();

      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setPushNotifications(false);
      await settings.setEmailNotifications(false);
      await settings.setAnnouncementNotifications(false);

      expect(notified, 3);

      final reloaded = await AppSettings.load();
      expect(reloaded.pushNotifications, isFalse);
      expect(reloaded.emailNotifications, isFalse);
      expect(reloaded.announcementNotifications, isFalse);
    });
  });
}
