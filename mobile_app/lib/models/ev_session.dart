import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle of a single charging session.
///
/// Parses DEFENSIVELY and FAILS SAFE to [completed]: an unknown / missing value
/// must never read as an ongoing charge (which could wrongly keep a bay shown
/// as occupied), so the safe degrade is the terminal state.
enum EvSessionStatus {
  active,
  completed;

  String toFirestoreValue() => name;

  static EvSessionStatus fromFirestoreValue(Object? value) {
    return EvSessionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => EvSessionStatus.completed,
    );
  }
}

/// A charging session at /ev_sessions/{id} — the per-charge audit log.
///
/// ─── READ-SHAPED ────────────────────────────────────────────────────────
/// Like the other domain models, this never emits the server-authoritative
/// timestamps; [EvChargingRepository] stamps startedAt / endedAt with
/// [FieldValue.serverTimestamp] inside the claim / release transaction.
class EvSession {
  final String id;
  final String stationId;

  /// Owner: the charging resident's uid. The rule pins it to `request.auth.uid`.
  final String userId;

  /// The resident's verified unit at start time (pinned to the profile).
  final String unitNumber;

  final DateTime startedAt;
  final DateTime? endedAt;
  final EvSessionStatus status;

  const EvSession({
    required this.id,
    required this.stationId,
    required this.userId,
    required this.unitNumber,
    required this.startedAt,
    required this.status,
    this.endedAt,
  });

  /// Elapsed time: live for an active session, final for a completed one.
  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  factory EvSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('EvSession document "${snapshot.id}" has no data');
    }
    return EvSession(
      id: snapshot.id,
      stationId: data['stationId'] as String,
      userId: data['userId'] as String,
      unitNumber: data['unitNumber'] as String,
      // startedAt tolerates the transient null of Firestore's pending-write
      // window (mirrors Announcement.postedAt); endedAt is genuinely optional.
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      status: EvSessionStatus.fromFirestoreValue(data['status']),
    );
  }

  @override
  String toString() =>
      'EvSession(id: $id, stationId: $stationId, status: ${status.name})';
}
