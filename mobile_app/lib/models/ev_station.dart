import 'package:cloud_firestore/cloud_firestore.dart';

/// Live state of a charging bay.
///
/// Parses DEFENSIVELY but FAILS SAFE: an unknown / missing / wrong-typed value
/// maps to [offline], NOT [available]. A malformed station doc must never read
/// as chargeable — the safe degrade is "out of service", mirroring the
/// fail-closed discipline of VisitorPassStatus (contrast AnnouncementPriority,
/// whose safe degrade is the benign 'info').
enum EvStationStatus {
  /// Free to claim. The only state from which a resident may start a session.
  available,

  /// A session is in progress (a resident has claimed it).
  inUse,

  /// Taken out of service by an admin, or an unrecognised value. Not chargeable.
  offline;

  String toFirestoreValue() => name;

  static EvStationStatus fromFirestoreValue(Object? value) {
    return EvStationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => EvStationStatus.offline,
    );
  }
}

/// Physical state reported by the ESP32 demo charger.
enum EvDeviceState {
  idle,
  charging,
  unknown;

  static EvDeviceState fromFirestoreValue(Object? value) {
    return switch (value) {
      'idle' => EvDeviceState.idle,
      'charging' => EvDeviceState.charging,
      _ => EvDeviceState.unknown,
    };
  }
}

/// Latest physical state at /ev_device_status/{stationId}.
class EvDeviceStatus {
  final String stationId;
  final EvDeviceState state;
  final int adc;
  final bool online;

  const EvDeviceStatus({
    required this.stationId,
    required this.state,
    required this.adc,
    required this.online,
  });

  factory EvDeviceStatus.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError(
        'EV device status document "${snapshot.id}" has no data',
      );
    }
    return EvDeviceStatus(
      stationId: snapshot.id,
      state: EvDeviceState.fromFirestoreValue(data['state']),
      adc: (data['adc'] as num?)?.toInt() ?? 0,
      online: data['online'] == true,
    );
  }
}

/// A charging station at /ev_stations/{id}.
///
/// `status` is AUTHORITATIVE and server-mutated: an admin seeds / disables a
/// station, and a resident's claim / release transaction (gated by
/// firestore.rules) is the ONLY way it flips available ⇄ inUse. So the resident
/// app reads `status` directly rather than inferring "busy" from other people's
/// sessions — no cross-resident session reads, no privacy leak.
class EvStation {
  final String id;
  final String name;
  final String location;
  final EvStationStatus status;

  /// The /ev_sessions doc id of the in-progress session, when [status] is
  /// [EvStationStatus.inUse]; null otherwise. An OPAQUE id (no PII) — the
  /// release rule get()s it to confirm the caller owns the session before
  /// freeing the bay, so it never has to store the charging resident's uid here.
  final String? currentSessionId;

  const EvStation({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    this.currentSessionId,
  });

  bool get isAvailable => status == EvStationStatus.available;

  factory EvStation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('EvStation document "${snapshot.id}" has no data');
    }
    final rawName = data['name'];
    final rawLocation = data['location'];
    final rawSessionId = data['currentSessionId'];
    final hasValidShape =
        rawName is String &&
        rawName.trim().isNotEmpty &&
        rawLocation is String &&
        (rawSessionId == null || rawSessionId is String);
    final parsedStatus = EvStationStatus.fromFirestoreValue(data['status']);

    return EvStation(
      id: snapshot.id,
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName
          : 'Charging station',
      location: rawLocation is String ? rawLocation : 'Location unavailable',
      status: hasValidShape ? parsedStatus : EvStationStatus.offline,
      currentSessionId: rawSessionId is String ? rawSessionId : null,
    );
  }

  @override
  String toString() =>
      'EvStation(id: $id, name: $name, status: ${status.name})';
}
