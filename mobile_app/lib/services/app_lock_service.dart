import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockException implements Exception {
  final String message;

  const AppLockException(this.message);

  @override
  String toString() => message;
}

class AppLockService {
  static const int pinLength = 6;
  static const int maxAttempts = 5;
  static const Duration failedAttemptCooldown = Duration(seconds: 30);
  static const Duration autoLogoutTimeout = Duration(minutes: 15);
  static const int _defaultIterations = 120000;

  static final Set<String> _runtimeUnlockedUids = <String>{};

  final int iterations;

  const AppLockService({this.iterations = _defaultIterations});

  static bool isRuntimeUnlocked(String uid) {
    return _runtimeUnlockedUids.contains(uid);
  }

  static void unlockRuntime(String uid) {
    _runtimeUnlockedUids.add(uid);
  }

  static void lockRuntime(String uid) {
    _runtimeUnlockedUids.remove(uid);
  }

  static void clearRuntime() {
    _runtimeUnlockedUids.clear();
  }

  Future<bool> hasPin(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hashKey(uid)) != null &&
        prefs.getString(_saltKey(uid)) != null;
  }

  Future<void> setPin(String uid, String pin) async {
    _validatePin(pin);
    final salt = _randomBytes(16);
    final hash = _derivePinHash(pin, salt, iterations);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_saltKey(uid), base64UrlEncode(salt));
    await prefs.setString(_hashKey(uid), base64UrlEncode(hash));
    await prefs.setInt(_iterationsKey(uid), iterations);
    await prefs.remove(_failedCountKey(uid));
    await prefs.remove(_cooldownUntilKey(uid));
  }

  Future<bool> verifyPin(String uid, String pin) async {
    _validatePin(pin);
    final prefs = await SharedPreferences.getInstance();
    final cooldownUntil = prefs.getInt(_cooldownUntilKey(uid));
    final now = DateTime.now().millisecondsSinceEpoch;
    if (cooldownUntil != null && now < cooldownUntil) {
      final seconds = ((cooldownUntil - now) / 1000).ceil();
      throw AppLockException(
        'Too many attempts. Try again in $seconds seconds.',
      );
    }

    final storedSalt = prefs.getString(_saltKey(uid));
    final storedHash = prefs.getString(_hashKey(uid));
    if (storedSalt == null || storedHash == null) {
      throw const AppLockException('Set up your 6-digit PIN first.');
    }

    final salt = base64Url.decode(storedSalt);
    final expected = base64Url.decode(storedHash);
    final savedIterations = prefs.getInt(_iterationsKey(uid)) ?? iterations;
    final actual = _derivePinHash(pin, salt, savedIterations);

    if (_constantTimeEquals(expected, actual)) {
      await prefs.remove(_failedCountKey(uid));
      await prefs.remove(_cooldownUntilKey(uid));
      return true;
    }

    final failedCount = (prefs.getInt(_failedCountKey(uid)) ?? 0) + 1;
    if (failedCount >= maxAttempts) {
      await prefs.remove(_failedCountKey(uid));
      await prefs.setInt(
        _cooldownUntilKey(uid),
        DateTime.now().add(failedAttemptCooldown).millisecondsSinceEpoch,
      );
    } else {
      await prefs.setInt(_failedCountKey(uid), failedCount);
    }
    return false;
  }

  Future<void> recordLastActivity(String uid, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActivityKey(uid), timestamp.millisecondsSinceEpoch);
  }

  Future<DateTime?> lastActivity(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastActivityKey(uid));
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const AppLockException('PIN must be exactly 6 digits.');
    }
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  List<int> _derivePinHash(String pin, List<int> salt, int rounds) {
    const outputLength = 32;
    final hmac = Hmac(sha256, utf8.encode(pin));
    final blockCount = (outputLength / hmac.convert(<int>[]).bytes.length)
        .ceil();
    final output = <int>[];

    for (var block = 1; block <= blockCount; block++) {
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      var u = hmac.convert([...salt, ...blockBytes.buffer.asUint8List()]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < rounds; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.addAll(t);
    }

    return output.take(outputLength).toList(growable: false);
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String _prefix(String uid) => 'app_lock.$uid';
  static String _saltKey(String uid) => '${_prefix(uid)}.salt';
  static String _hashKey(String uid) => '${_prefix(uid)}.hash';
  static String _iterationsKey(String uid) => '${_prefix(uid)}.iterations';
  static String _failedCountKey(String uid) => '${_prefix(uid)}.failedCount';
  static String _cooldownUntilKey(String uid) =>
      '${_prefix(uid)}.cooldownUntil';
  static String _lastActivityKey(String uid) => '${_prefix(uid)}.lastActivity';
}
