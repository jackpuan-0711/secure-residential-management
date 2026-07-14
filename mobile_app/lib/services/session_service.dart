import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_service.dart';

class SessionException implements Exception {
  final String message;

  const SessionException(this.message);

  @override
  String toString() => message;
}

class SessionSnapshot {
  final bool exists;
  final bool isCurrentDevice;
  final bool isExpired;

  const SessionSnapshot({
    required this.exists,
    required this.isCurrentDevice,
    required this.isExpired,
  });
}

class SessionService {
  static const Duration touchThrottle = Duration(minutes: 1);

  final FirebaseFirestore _firestore;
  DateTime? _lastTouch;

  SessionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _sessionRef(String uid) {
    return _firestore.collection('auth_sessions').doc(uid);
  }

  Future<String> startNewSession(String uid) async {
    final sessionId = _newSessionId();
    await _storeLocalSessionId(uid, sessionId);
    await _sessionRef(uid).set({
      'activeSessionId': sessionId,
      'issuedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(_newExpiry()),
    });
    _lastTouch = DateTime.now();
    return sessionId;
  }

  Future<String> ensureActiveSession(String uid) async {
    final localId = await localSessionId(uid);
    if (localId == null) {
      return startNewSession(uid);
    }

    final snapshot = await _sessionRef(uid).get();
    if (!snapshot.exists) {
      await _sessionRef(uid).set({
        'activeSessionId': localId,
        'issuedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(_newExpiry()),
      });
      return localId;
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    if (data['activeSessionId'] != localId) {
      throw const SessionException('This account is active on another device.');
    }
    if (_isExpired(data['expiresAt'])) {
      throw const SessionException('Your session has expired.');
    }

    await touch(uid, force: true);
    return localId;
  }

  Stream<SessionSnapshot> watchSession(String uid) {
    return _sessionRef(uid).snapshots().asyncMap((snapshot) async {
      final localId = await localSessionId(uid);
      final data = snapshot.data();
      if (!snapshot.exists || data == null || localId == null) {
        return const SessionSnapshot(
          exists: false,
          isCurrentDevice: false,
          isExpired: true,
        );
      }
      return SessionSnapshot(
        exists: true,
        isCurrentDevice: data['activeSessionId'] == localId,
        isExpired: _isExpired(data['expiresAt']),
      );
    });
  }

  Future<void> touch(String uid, {bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastTouch != null &&
        now.difference(_lastTouch!) < touchThrottle) {
      return;
    }
    final localId = await localSessionId(uid);
    if (localId == null) return;
    await _sessionRef(uid).update({
      'lastSeenAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(_newExpiry()),
    });
    _lastTouch = now;
  }

  Future<String?> localSessionId(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localSessionKey(uid));
  }

  Future<void> clearLocalSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localSessionKey(uid));
    AppLockService.lockRuntime(uid);
  }

  DateTime _newExpiry() {
    return DateTime.now().add(AppLockService.autoLogoutTimeout);
  }

  bool _isExpired(Object? value) {
    if (value is! Timestamp) return true;
    return !value.toDate().isAfter(DateTime.now());
  }

  Future<void> _storeLocalSessionId(String uid, String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localSessionKey(uid), sessionId);
  }

  String _newSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _localSessionKey(String uid) => 'active_session.$uid';
}
