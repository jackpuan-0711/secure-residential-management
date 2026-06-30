import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/ev_charging_repository.dart';
import 'package:mobile_app/widgets/ev_device_status_line.dart';

void main() {
  testWidgets('device line follows idle and charging snapshots in real time', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = EvChargingRepository(firestore: firestore);
    final statusRef = firestore.collection('ev_device_status').doc('station-1');

    await statusRef.set({
      'state': 'idle',
      'adc': 0,
      'online': true,
      'lastSeenAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(seconds: 45)),
      ),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvDeviceStatusLine(
            stream: repository.watchDeviceStatus('station-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Device: Idle'), findsOneWidget);
    expect(find.text('Device: Not connected'), findsNothing);

    await statusRef.set({
      'state': 'charging',
      'adc': 2243,
      'online': true,
      'lastSeenAt': Timestamp.now(),
    });
    await tester.pumpAndSettle();

    expect(find.text('Device: Charging'), findsOneWidget);
    expect(find.text('Device: Idle'), findsNothing);
  });
}
