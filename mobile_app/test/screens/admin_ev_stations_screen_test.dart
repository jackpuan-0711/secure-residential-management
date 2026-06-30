import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/admin_ev_stations_screen.dart';
import 'package:mobile_app/services/ev_charging_repository.dart';

void main() {
  testWidgets('fixed station keeps live status and online controls', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = EvChargingRepository(
      firestore: firestore,
      stationId: 'station-1',
    );

    await firestore.collection('ev_stations').doc('station-1').set({
      'name': 'Station 1',
      'location': 'Taman Universiti UTM',
      'status': 'available',
      'currentSessionId': null,
    });
    await firestore.collection('ev_device_status').doc('station-1').set({
      'state': 'charging',
      'adc': 2243,
      'online': true,
      'lastSeenAt': Timestamp.now(),
    });

    await tester.pumpWidget(
      MaterialApp(home: AdminEvStationsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Device: Charging'), findsOneWidget);
    expect(find.text('Add station'), findsNothing);
    expect(find.text('Add first station'), findsNothing);
    expect(find.text('Remove'), findsNothing);

    await tester.tap(find.text('Set offline'));
    await tester.pumpAndSettle();
    var station = await firestore
        .collection('ev_stations')
        .doc('station-1')
        .get();
    expect(station.data()!['status'], 'offline');
    expect(find.text('Set online'), findsOneWidget);
    expect(find.text('Device: Charging'), findsOneWidget);

    await tester.tap(find.text('Set online'));
    await tester.pumpAndSettle();
    station = await firestore.collection('ev_stations').doc('station-1').get();
    expect(station.data()!['status'], 'available');
  });
}
