import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ev_session.dart';
import '../models/ev_station.dart';
import 'management_backend_service.dart';

/// Thrown when a charging operation violates a domain invariant (claiming a
/// busy bay, stopping someone else's session, …). Bugs or attacks, not ordinary
/// user errors — mirrors [VisitorRepositoryException].
class EvChargingException implements Exception {
  final String message;
  const EvChargingException(this.message);

  @override
  String toString() => 'EvChargingException: $message';
}

/// The single chokepoint for /ev_stations/{id} and /ev_sessions/{id}.
///
/// THREAT MODEL NOTE:
///   A convenience API over Firestore; authorization is enforced SERVER-SIDE
///   by firestore.rules. Two collections, two trust models:
///     • ev_stations — admin/superadmin CLAIM seeds & disables bays; a resident
///       may ONLY flip available→inUse (claim) or inUse→available (release of a
///       session they own). status is authoritative and server-mutated.
///     • ev_sessions — owner-scoped audit log; a resident creates / completes
///       only their own.
///   Claim and release are TRANSACTIONS so the bay's status and the session
///   move atomically and two residents can't claim the same bay in a race.
class EvChargingRepository {
  static const defaultStationId = 'q0mfxs4doqGSBxlAJVU3';

  static const defaultStationName = 'Charger 1';
  static const defaultStationLocation = 'Parking A1';
  final FirebaseFirestore _firestore;
  final ManagementBackendService? _backend;
  final String stationId;

  EvChargingRepository({
    FirebaseFirestore? firestore,
    ManagementBackendService? backend,
    this.stationId = defaultStationId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _backend = backend;

  CollectionReference<Map<String, dynamic>> get _stations =>
      _firestore.collection('ev_stations');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('ev_sessions');
  CollectionReference<Map<String, dynamic>> get _deviceStatuses =>
      _firestore.collection('ev_device_status');

  // ═══════════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════════

  /// All charging bays, ordered by name. Readable by any verified user.
  Stream<List<EvStation>> watchStations() {
    return _stations
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => EvStation.fromFirestore(d, null)).toList(),
        );
  }

  /// The single physical charger registered to this application.
  Stream<List<EvStation>> watchConfiguredStation() {
    return _stations.doc(stationId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return <EvStation>[
          EvStation(
            id: stationId,
            name: defaultStationName,
            location: defaultStationLocation,
            status: EvStationStatus.offline,
          ),
        ];
      }
      return <EvStation>[EvStation.fromFirestore(snapshot, null)];
    });
  }

  /// Creates the one configured station at its deterministic document ID.
  /// Existing station data is left untouched.
  Future<void> ensureConfiguredStation() async {
    final reference = _stations.doc(stationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) return;

      transaction.set(reference, {
        'name': defaultStationName,
        'location': defaultStationLocation,
        'status': EvStationStatus.available.toFirestoreValue(),
        'currentSessionId': null,
      });
    });
  }

  /// Physical state reported by the ESP32 assigned to [stationId].
  Stream<EvDeviceStatus?> watchDeviceStatus(String stationId) {
    return _deviceStatuses.doc(stationId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return EvDeviceStatus.fromFirestore(snapshot);
    });
  }

  /// The calling resident's own charging history, newest first.
  ///
  /// COMPOSITE INDEX: where('userId') + orderBy('startedAt', desc) needs an
  /// (userId ASC, startedAt DESC) index (firestore.indexes.json).
  Stream<List<EvSession>> watchMySessions(String userId) {
    return _sessions
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => EvSession.fromFirestore(d, null)).toList(),
        );
  }

  // ═══════════════════════════════════════════════════════════════
  // RESIDENT — claim / release (atomic, rule-gated transitions)
  // ═══════════════════════════════════════════════════════════════

  /// Starts a charging session: atomically opens an active /ev_sessions doc and
  /// flips the bay available→inUse, pointing it at that session. Returns the new
  /// session id.
  ///
  /// Throws [EvChargingException] if the bay is not currently available (e.g.
  /// claimed by someone else a moment earlier) — the transaction re-reads the
  /// authoritative status, so the loser of a race fails cleanly.
  Future<String> startCharging({
    required String stationId,
    required String userId,
    required String unitNumber,
  }) async {
    final backend = _backend;
    if (backend != null) {
      return backend.startEvCharging(stationId: stationId);
    }

    final stationRef = _stations.doc(stationId);
    final sessionRef = _sessions.doc(); // pre-allocate id (no write yet)

    await _firestore.runTransaction((tx) async {
      final stationSnap = await tx.get(stationRef);
      if (!stationSnap.exists) {
        throw const EvChargingException('Charging station not found.');
      }
      if (stationSnap.data()!['status'] !=
          EvStationStatus.available.toFirestoreValue()) {
        throw const EvChargingException(
          'This station is not available right now.',
        );
      }

      tx.set(sessionRef, {
        'stationId': stationId,
        'userId': userId,
        'unitNumber': unitNumber,
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'status': EvSessionStatus.active.toFirestoreValue(),
      });
      tx.update(stationRef, {
        'status': EvStationStatus.inUse.toFirestoreValue(),
        'currentSessionId': sessionRef.id,
      });
    });

    return sessionRef.id;
  }

  /// Stops the caller's charging session: atomically completes the session and
  /// frees the bay. Re-reads the bay's current session and asserts the caller
  /// OWNS it, so one resident can never end another's charge (the rule enforces
  /// the same via a get() on the session's userId).
  Future<void> stopCharging({
    required String stationId,
    required String userId,
  }) async {
    final backend = _backend;
    if (backend != null) {
      await backend.stopEvCharging(stationId: stationId);
      return;
    }

    final stationRef = _stations.doc(stationId);

    await _firestore.runTransaction((tx) async {
      final stationSnap = await tx.get(stationRef);
      if (!stationSnap.exists) {
        throw const EvChargingException('Charging station not found.');
      }
      final stationData = stationSnap.data()!;
      final sessionId = stationData['currentSessionId'] as String?;
      if (stationData['status'] != EvStationStatus.inUse.toFirestoreValue() ||
          sessionId == null) {
        throw const EvChargingException('This station is not in use.');
      }

      final sessionRef = _sessions.doc(sessionId);
      final sessionSnap = await tx.get(sessionRef); // read before any write
      if (!sessionSnap.exists || sessionSnap.data()!['userId'] != userId) {
        throw const EvChargingException(
          'You can only stop a session you started.',
        );
      }

      tx.update(sessionRef, {
        'status': EvSessionStatus.completed.toFirestoreValue(),
        'endedAt': FieldValue.serverTimestamp(),
      });
      tx.update(stationRef, {
        'status': EvStationStatus.available.toFirestoreValue(),
        'currentSessionId': null,
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ADMIN — station management (claim-gated by the rule)
  // ═══════════════════════════════════════════════════════════════

  /// Seeds a new bay (admin/superadmin only — the rule rejects others). Starts
  /// available and idle.
  Future<void> addStation({
    required String name,
    required String location,
  }) async {
    await _stations.add({
      'name': name.trim(),
      'location': location.trim(),
      'status': EvStationStatus.available.toFirestoreValue(),
      'currentSessionId': null,
    });
  }

  /// Admin toggles a bay between available and offline (out of service). Only
  /// meaningful when the bay is not mid-session; the UI hides the toggle while
  /// inUse, and the rule additionally constrains resident transitions so this
  /// admin path cannot be reached by a resident.
  Future<void> setStationOffline({
    required String stationId,
    required bool offline,
  }) async {
    final ref = _stations.doc(stationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw const EvChargingException('Charging station not found.');
      }
      final data = snapshot.data()!;
      if (data['status'] == EvStationStatus.inUse.toFirestoreValue()) {
        throw const EvChargingException(
          'End the active charging session before changing service status.',
        );
      }
      transaction.set(ref, {
        'name': _validStationName(data['name']),
        'location': _validStationLocation(data['location']),
        'status': offline
            ? EvStationStatus.offline.toFirestoreValue()
            : EvStationStatus.available.toFirestoreValue(),
        'currentSessionId': null,
      });
    });
  }

  /// Admin updates display details for a charging bay.
  Future<void> updateStationDetails({
    required String stationId,
    required String name,
    required String location,
  }) async {
    final ref = _stations.doc(stationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw const EvChargingException('Charging station not found.');
      }
      final data = snapshot.data()!;
      final status = EvStationStatus.fromFirestoreValue(data['status']);
      final sessionId = data['currentSessionId'];
      final hasActiveSession =
          status == EvStationStatus.inUse &&
          sessionId is String &&
          sessionId.isNotEmpty;
      transaction.set(ref, {
        'name': name.trim(),
        'location': location.trim(),
        'status': hasActiveSession
            ? EvStationStatus.inUse.toFirestoreValue()
            : status == EvStationStatus.available
            ? EvStationStatus.available.toFirestoreValue()
            : EvStationStatus.offline.toFirestoreValue(),
        'currentSessionId': hasActiveSession ? sessionId : null,
      });
    });
  }

  String _validStationName(Object? value) {
    final name = value is String ? value.trim() : '';
    return name.isEmpty ? 'Charging station' : name;
  }

  String _validStationLocation(Object? value) {
    return value is String ? value.trim() : '';
  }

  /// Admin/superadmin closes the active session on a bay.
  ///
  /// Direct Firestore transaction path is used by the app. A backend may still
  /// be injected for deployments that want to proxy EV control through callable
  /// functions.
  Future<void> stopStationByAdmin({required String stationId}) async {
    final backend = _backend;
    if (backend != null) {
      await backend.stopEvCharging(stationId: stationId);
      return;
    }

    final stationRef = _stations.doc(stationId);

    await _firestore.runTransaction((tx) async {
      final stationSnap = await tx.get(stationRef);
      if (!stationSnap.exists) {
        throw const EvChargingException('Charging station not found.');
      }
      final stationData = stationSnap.data()!;
      final sessionId = stationData['currentSessionId'] as String?;
      if (stationData['status'] != EvStationStatus.inUse.toFirestoreValue() ||
          sessionId == null) {
        throw const EvChargingException('This station is not in use.');
      }

      final sessionRef = _sessions.doc(sessionId);
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) {
        throw const EvChargingException('Charging session not found.');
      }

      tx.update(sessionRef, {
        'status': EvSessionStatus.completed.toFirestoreValue(),
        'endedAt': FieldValue.serverTimestamp(),
      });
      tx.update(stationRef, {
        'status': EvStationStatus.available.toFirestoreValue(),
        'currentSessionId': null,
      });
    });
  }

  /// Removes a bay (admin/superadmin only).
  Future<void> removeStation(String stationId) async {
    await _stations.doc(stationId).delete();
  }
}
