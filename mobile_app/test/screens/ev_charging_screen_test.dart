import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/app_user.dart';
import 'package:mobile_app/screens/ev_charging_screen.dart';
import 'package:mobile_app/services/ev_charging_repository.dart';

void main() {
  testWidgets('resident can start only when the station is online', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = EvChargingRepository(
      firestore: firestore,
      stationId: 'station-1',
    );
    final stationRef = firestore.collection('ev_stations').doc('station-1');

    final deviceRef = firestore.collection('ev_device_status').doc('station-1');
    await stationRef.set({
      'name': 'Station 1',
      'location': 'Taman Universiti UTM',
      'status': 'offline',
      'currentSessionId': null,
    });

    await deviceRef.set({
      'state': 'idle',
      'adc': 0,
      'online': true,
      'lastSeenAt': Timestamp.now(),
    });
    final now = DateTime.now();
    final resident = AppUser(
      uid: 'resident-1',
      email: 'resident@example.com',
      name: 'Resident',
      role: UserRole.resident,
      status: UserStatus.active,
      unitNumber: 'A-1-1',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EvChargingScreen(user: resident, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsNothing);
    expect(find.text('Out of service'), findsNothing);

    expect(find.text('Device: Idle'), findsOneWidget);

    await deviceRef.update({
      'state': 'charging',
      'adc': 2243,
      'lastSeenAt': Timestamp.now(),
    });
    await tester.pumpAndSettle();

    expect(find.text('Device: Charging'), findsOneWidget);
    expect(find.text('Start'), findsNothing);

    await stationRef.update({'status': 'available'});
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Out of service'), findsNothing);
  });
}
