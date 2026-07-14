import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppLockService', () {
    test(
      'stores and verifies a six digit PIN without storing raw PIN',
      () async {
        SharedPreferences.setMockInitialValues({});
        const service = AppLockService(iterations: 2);

        await service.setPin('user-1', '123456');

        expect(await service.hasPin('user-1'), isTrue);
        expect(await service.verifyPin('user-1', '123456'), isTrue);
        expect(await service.verifyPin('user-1', '654321'), isFalse);

        final prefs = await SharedPreferences.getInstance();
        final rawValues = prefs.getKeys().map(prefs.get).toList();
        expect(rawValues, isNot(contains('123456')));
      },
    );

    test('rejects non six digit PIN values', () async {
      SharedPreferences.setMockInitialValues({});
      const service = AppLockService(iterations: 2);

      expect(
        () => service.setPin('user-1', '12345'),
        throwsA(isA<AppLockException>()),
      );
      expect(
        () => service.setPin('user-1', '12345a'),
        throwsA(isA<AppLockException>()),
      );
    });
  });
}
