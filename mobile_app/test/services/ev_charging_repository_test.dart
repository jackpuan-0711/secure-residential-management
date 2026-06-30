import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/models/ev_session.dart';
import 'package:mobile_app/models/ev_station.dart';
import 'package:mobile_app/services/ev_charging_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late EvChargingRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = EvChargingRepository(firestore: firestore);
  });

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<String> seedStation({String name = 'Station 1'}) async {
    await repository.addStation(name: name, location: 'Basement 2');
    final snap = await firestore
        .collection('ev_stations')
        .where('name', isEqualTo: name)
        .get();
    return snap.docs.first.id;
  }

  Future<Map<String, dynamic>> stationData(String id) async {
    final s = await firestore.collection('ev_stations').doc(id).get();
    return s.data()!;
  }

  // ═══════════════════════════════════════════════════════════════
  // addStation / watchStations
  // ═══════════════════════════════════════════════════════════════

  group('stations', () {
    test('addStation creates an available, idle bay', () async {
      final id = await seedStation();
      final data = await stationData(id);
      expect(data['status'], 'available');
      expect(data['currentSessionId'], isNull);
      expect(data['name'], 'Station 1');
    });

    test('setStationOffline toggles status', () async {
      final id = await seedStation();
      await repository.setStationOffline(stationId: id, offline: true);
      expect((await stationData(id))['status'], 'offline');
      await repository.setStationOffline(stationId: id, offline: false);
      expect((await stationData(id))['status'], 'available');
    });

    test('admin update normalizes a legacy station document', () async {
      const id = 'legacy';
      await firestore.collection('ev_stations').doc(id).set({
        'name': 'Old station',
        'location': 'Old location',
        'status': 'outOfService',
        'legacyOnline': false,
      });

      await repository.updateStationDetails(
        stationId: id,
        name: 'Station Alpha',
        location: 'Basement 1',
      );
      await repository.setStationOffline(stationId: id, offline: false);

      expect(await stationData(id), {
        'name': 'Station Alpha',
        'location': 'Basement 1',
        'status': 'available',
        'currentSessionId': null,
      });
    });

    test('watchStations emits seeded bays', () async {
      await seedStation(name: 'A');
      await seedStation(name: 'B');
      final emissions = <List<EvStation>>[];
      final sub = repository.watchStations().listen(emissions.add);
      await settle();
      await sub.cancel();
      expect(emissions.last.map((s) => s.name).toSet(), {'A', 'B'});
    });
    test('configured station ignores unrelated station documents', () async {
      const configuredId = 'configured-charger';
      final fixedRepository = EvChargingRepository(
        firestore: firestore,
        stationId: configuredId,
      );
      await firestore.collection('ev_stations').doc(configuredId).set({
        'name': 'Configured charger',
        'location': 'Parking A1',
        'status': 'available',
        'currentSessionId': null,
      });
      await firestore.collection('ev_stations').doc('old-random-id').set({
        'name': 'Old station',
        'location': 'Parking B1',
        'status': 'available',
        'currentSessionId': null,
      });

      final stations = await fixedRepository.watchConfiguredStation().first;

      expect(stations, hasLength(1));
      expect(stations.single.id, configuredId);
    });
    test(
      'missing configured station is shown and restored at the fixed id',
      () async {
        const configuredId = 'configured-charger';
        final fixedRepository = EvChargingRepository(
          firestore: firestore,
          stationId: configuredId,
        );

        final fallback = await fixedRepository.watchConfiguredStation().first;
        expect(fallback, hasLength(1));
        expect(fallback.single.id, configuredId);
        expect(fallback.single.status, EvStationStatus.offline);

        await fixedRepository.ensureConfiguredStation();

        final snapshot = await firestore
            .collection('ev_stations')
            .doc(configuredId)
            .get();
        expect(snapshot.data(), {
          'name': 'Charger 1',
          'location': 'Parking A1',
          'status': 'available',
          'currentSessionId': null,
        });
      },
    );
  });

  group('ESP32 device status', () {
    test('emits null before the device has reported', () async {
      expect(await repository.watchDeviceStatus('st1').first, isNull);
    });

    test('emits charging and idle updates for a station', () async {
      await firestore.collection('ev_device_status').doc('st1').set({
        'state': 'charging',
        'adc': 4095,
        'online': true,
        'lastSeenAt': Timestamp.now(),
      });
      final charging = await repository
          .watchDeviceStatus('st1')
          .firstWhere((status) => status != null);
      expect(charging!.state, EvDeviceState.charging);
      expect(charging.adc, 4095);
      expect(charging.online, isTrue);

      await firestore.collection('ev_device_status').doc('st1').set({
        'state': 'idle',
        'adc': 0,
        'online': true,
        'lastSeenAt': Timestamp.now(),
      });
      final idle = await repository
          .watchDeviceStatus('st1')
          .firstWhere((status) => status?.state == EvDeviceState.idle);
      expect(idle!.state, EvDeviceState.idle);
      expect(idle.isConnectedAt(DateTime.now()), isTrue);
    });

    test('stale telemetry is treated as disconnected', () async {
      await firestore.collection('ev_device_status').doc('st1').set({
        'state': 'charging',
        'adc': 4095,
        'online': true,
        'lastSeenAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      });
      final status = await repository
          .watchDeviceStatus('st1')
          .firstWhere((value) => value != null);
      expect(status!.isConnectedAt(DateTime.now()), isFalse);
    });

    test('30-second firmware heartbeat stays connected between reports', () {
      final lastSeen = DateTime.utc(2026, 7, 1, 2, 14);
      final status = EvDeviceStatus(
        stationId: 'st1',
        state: EvDeviceState.charging,
        adc: 2243,
        online: true,
        lastSeenAt: lastSeen,
      );

      expect(
        status.isConnectedAt(lastSeen.add(const Duration(seconds: 45))),
        isTrue,
      );
      expect(
        status.isConnectedAt(lastSeen.add(const Duration(seconds: 76))),
        isFalse,
      );
    });

    test('telemetry without a heartbeat is treated as disconnected', () async {
      await firestore.collection('ev_device_status').doc('st1').set({
        'state': 'available',
        'adc': 0,
        'online': true,
      });
      final status = await repository.watchDeviceStatus('st1').first;
      expect(status!.state, EvDeviceState.idle);
      expect(status.isConnectedAt(DateTime.now()), isFalse);
    });

    test('unknown device state fails closed in the model', () {
      expect(
        EvDeviceState.fromFirestoreValue('unexpected'),
        EvDeviceState.unknown,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // startCharging
  // ═══════════════════════════════════════════════════════════════

  group('startCharging', () {
    test('opens an active session and flips the bay to inUse', () async {
      final id = await seedStation();
      final sessionId = await repository.startCharging(
        stationId: id,
        userId: 'resident-1',
        unitNumber: 'A-12-5',
      );

      final station = await stationData(id);
      expect(station['status'], 'inUse');
      expect(station['currentSessionId'], sessionId);

      final session = await firestore
          .collection('ev_sessions')
          .doc(sessionId)
          .get();
      expect(session.data()!['userId'], 'resident-1');
      expect(session.data()!['unitNumber'], 'A-12-5');
      expect(session.data()!['status'], 'active');
      expect(session.data()!['startedAt'], isA<Timestamp>());
      expect(session.data()!['endedAt'], isNull);
    });

    test('rejects starting on a bay that is not available', () async {
      final id = await seedStation();
      await repository.startCharging(
        stationId: id,
        userId: 'resident-1',
        unitNumber: 'A-12-5',
      );
      // Second start (now inUse) must fail.
      await expectLater(
        repository.startCharging(
          stationId: id,
          userId: 'resident-2',
          unitNumber: 'B-1-1',
        ),
        throwsA(isA<EvChargingException>()),
      );
    });

    test('rejects starting on a missing bay', () async {
      await expectLater(
        repository.startCharging(
          stationId: 'nope',
          userId: 'resident-1',
          unitNumber: 'A-12-5',
        ),
        throwsA(isA<EvChargingException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // stopCharging
  // ═══════════════════════════════════════════════════════════════

  group('stopCharging', () {
    test('completes the session and frees the bay', () async {
      final id = await seedStation();
      final sessionId = await repository.startCharging(
        stationId: id,
        userId: 'resident-1',
        unitNumber: 'A-12-5',
      );

      await repository.stopCharging(stationId: id, userId: 'resident-1');

      final station = await stationData(id);
      expect(station['status'], 'available');
      expect(station['currentSessionId'], isNull);

      final session = await firestore
          .collection('ev_sessions')
          .doc(sessionId)
          .get();
      expect(session.data()!['status'], 'completed');
      expect(session.data()!['endedAt'], isA<Timestamp>());
    });

    test('rejects stopping a session you do not own', () async {
      final id = await seedStation();
      await repository.startCharging(
        stationId: id,
        userId: 'resident-1',
        unitNumber: 'A-12-5',
      );

      await expectLater(
        repository.stopCharging(stationId: id, userId: 'attacker'),
        throwsA(isA<EvChargingException>()),
      );
      // Bay stays occupied by the real user.
      expect((await stationData(id))['status'], 'inUse');
    });

    test('rejects stopping a bay that is not in use', () async {
      final id = await seedStation();
      await expectLater(
        repository.stopCharging(stationId: id, userId: 'resident-1'),
        throwsA(isA<EvChargingException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // watchMySessions
  // ═══════════════════════════════════════════════════════════════

  group('watchMySessions', () {
    test('returns only the caller\'s sessions', () async {
      final a = await seedStation(name: 'A');
      final b = await seedStation(name: 'B');
      await repository.startCharging(
        stationId: a,
        userId: 'resident-1',
        unitNumber: 'A-12-5',
      );
      await repository.startCharging(
        stationId: b,
        userId: 'resident-2',
        unitNumber: 'B-1-1',
      );

      final emissions = <List<EvSession>>[];
      final sub = repository
          .watchMySessions('resident-1')
          .listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions.last.length, 1);
      expect(emissions.last.single.userId, 'resident-1');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Model defensive parsing
  // ═══════════════════════════════════════════════════════════════

  group('model fail-safe parsing', () {
    test('unknown station status → offline (never chargeable)', () {
      expect(
        EvStationStatus.fromFirestoreValue('melted'),
        EvStationStatus.offline,
      );
      expect(EvStationStatus.fromFirestoreValue(null), EvStationStatus.offline);
    });

    test('unknown session status → completed (never a phantom active)', () {
      expect(
        EvSessionStatus.fromFirestoreValue('vibing'),
        EvSessionStatus.completed,
      );
    });

    test('missing display strings keep a valid station status', () async {
      final ref = firestore.collection('ev_stations').doc('broken');
      await ref.set({
        'name': null,
        'status': 'available',
        'currentSessionId': null,
      });

      final station = EvStation.fromFirestore(await ref.get(), null);

      expect(station.name, 'Charging station');
      expect(station.location, 'Location unavailable');
      expect(station.status, EvStationStatus.available);
    });
  });
}
