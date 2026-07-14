import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum BiometricFailureReason { unavailable, notConfigured, cancelled, failed }

class BiometricAuthResult {
  final bool success;
  final String? message;
  final BiometricFailureReason? failureReason;

  const BiometricAuthResult.success()
    : success = true,
      message = null,
      failureReason = null;

  const BiometricAuthResult.failure(
    this.message, {
    this.failureReason = BiometricFailureReason.failed,
  }) : success = false;

  bool get canFallbackToPin =>
      failureReason == BiometricFailureReason.unavailable ||
      failureReason == BiometricFailureReason.notConfigured;
}

class BiometricAuthService {
  static const MethodChannel _channel = MethodChannel(
    'secure_residential/local_auth',
  );
  static final Set<String> _runtimeVerifiedUids = <String>{};

  static bool isRuntimeVerified(String uid) {
    return _runtimeVerifiedUids.contains(uid);
  }

  static void markRuntimeVerified(String uid) {
    _runtimeVerifiedUids.add(uid);
  }

  static void clearRuntime() {
    _runtimeVerifiedUids.clear();
  }

  Future<BiometricAuthResult> authenticate({required String reason}) async {
    if (kIsWeb) {
      return const BiometricAuthResult.failure(
        'Biometric login is only available on a mobile device.',
        failureReason: BiometricFailureReason.unavailable,
      );
    }

    try {
      final ok = await _channel.invokeMethod<bool>('authenticate', {
        'reason': reason,
      });
      if (ok == true) return const BiometricAuthResult.success();
      return const BiometricAuthResult.failure(
        'Biometric verification was cancelled.',
        failureReason: BiometricFailureReason.cancelled,
      );
    } on MissingPluginException {
      return const BiometricAuthResult.failure(
        'Biometric login is not available on this platform.',
        failureReason: BiometricFailureReason.unavailable,
      );
    } on PlatformException catch (e) {
      return BiometricAuthResult.failure(
        e.message ?? 'Biometric verification failed.',
        failureReason: _failureReasonFromPlatformException(e),
      );
    }
  }

  BiometricFailureReason _failureReasonFromPlatformException(
    PlatformException e,
  ) {
    switch (e.code) {
      case 'unavailable':
        return BiometricFailureReason.unavailable;
      case 'not_configured':
        return BiometricFailureReason.notConfigured;
      case 'cancelled':
        return BiometricFailureReason.cancelled;
    }

    final message = (e.message ?? '').toLowerCase();
    if (message.contains('cancel')) return BiometricFailureReason.cancelled;
    if (message.contains('not enrolled') ||
        message.contains('no biometric') ||
        message.contains('set up')) {
      return BiometricFailureReason.notConfigured;
    }

    // Some Android devices/emulators report startup problems as
    // "unknown". Treat that as a platform availability problem so the app
    // can continue to the 6-digit app lock instead of trapping the user.
    if (message.contains('unknown') ||
        message.contains('unavailable') ||
        message.contains('unable')) {
      return BiometricFailureReason.unavailable;
    }

    final details = e.details;
    if (details is int) {
      switch (details) {
        case 1: // HW unavailable
        case 2: // Unable to process
        case 3: // Timeout
        case 8: // Vendor/platform error
        case 12: // No biometric hardware
          return BiometricFailureReason.unavailable;
        case 11: // No biometrics enrolled
          return BiometricFailureReason.notConfigured;
        case 5: // System cancelled
        case 10: // User cancelled
        case 13: // Negative button
          return BiometricFailureReason.cancelled;
      }
    }

    return BiometricFailureReason.unavailable;
  }
}
