import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/features/visitor/domain/visitor_invitation.dart';
import 'package:mobile_app/services/visitor_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late VisitorRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = VisitorRepository(firestore: firestore);
  });

  // Lets a stream subscription pump its microtasks before we assert.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<VisitorInvitation> createOne({
    String residentId = 'resident-1',
    String unitNumber = 'A-12-5',
    String visitorName = 'Jane Tan',
    String visitorContact = '012-345 6789',
    int guestCount = 1,
    String? vehiclePlate,
    DateTime? visitDate,
    String eta = '6:00 PM',
  }) {
    return repository.createInvitation(
      residentId: residentId,
      unitNumber: unitNumber,
      visitorName: visitorName,
      visitorContact: visitorContact,
      guestCount: guestCount,
      vehiclePlate: vehiclePlate,
      visitDate: visitDate ?? DateTime.now(),
      eta: eta,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // createInvitation
  // ═══════════════════════════════════════════════════════════════

  group('createInvitation', () {
    test(
      'persists at the token doc id with all fields + server createdAt',
      () async {
        final inv = await createOne(vehiclePlate: 'WXY 1234');

        // The returned token IS the document id.
        expect(inv.invitationId, isNotEmpty);
        final snap = await firestore
            .collection('visitor_invitations')
            .doc(inv.invitationId)
            .get();
        expect(snap.exists, isTrue);

        final data = snap.data()!;
        expect(data['residentId'], 'resident-1');
        expect(data['unitNumber'], 'A-12-5');
        expect(data['visitorName'], 'Jane Tan');
        expect(data['visitorContact'], '012-345 6789');
        expect(data['guestCount'], 1);
        expect(data['vehiclePlate'], 'WXY 1234');
        expect(data['eta'], '6:00 PM');
        expect(data['status'], 'active');
        expect(
          data['createdAt'],
          isA<Timestamp>(),
          reason: 'createdAt must be a server timestamp, not a client clock',
        );
        expect(data['visitDate'], isA<Timestamp>());
        expect(data['expiresAt'], isA<Timestamp>());
        expect(data['checkedInAt'], isNull);
        expect(data['checkedInBy'], isNull);
        expect(data['checkedOutAt'], isNull);
        expect(data['checkedOutBy'], isNull);
        expect(data['cancelledAt'], isNull);
        expect(data['cancelledBy'], isNull);

        // The token must never be duplicated as a field inside the payload.
        expect(data.containsKey('invitationId'), isFalse);
      },
    );

    test('expiresAt is the end of the visit day', () async {
      final inv = await createOne(visitDate: DateTime(2026, 7, 1));
      expect(inv.expiresAt, DateTime(2026, 7, 1, 23, 59, 59));
    });

    test('normalises an empty / whitespace vehicle plate to null', () async {
      final inv = await createOne(vehiclePlate: '   ');
      expect(inv.vehiclePlate, isNull);
      final data = await firestore
          .collection('visitor_invitations')
          .doc(inv.invitationId)
          .get();
      expect(data.data()!['vehiclePlate'], isNull);
    });

    test('persists a group visitor count', () async {
      final inv = await createOne(guestCount: 4);
      expect(inv.guestCount, 4);

      final data = await firestore
          .collection('visitor_invitations')
          .doc(inv.invitationId)
          .get();
      expect(data.data()!['guestCount'], 4);
    });

    test('rejects an out-of-range visitor count', () async {
      expect(
        () => createOne(guestCount: 0),
        throwsA(isA<VisitorRepositoryException>()),
      );
      expect(
        () => createOne(guestCount: 21),
        throwsA(isA<VisitorRepositoryException>()),
      );
    });

    test('generates distinct, URL-safe tokens across calls', () async {
      final a = await createOne();
      final b = await createOne();
      expect(a.invitationId, isNot(b.invitationId));
      // base64url alphabet only (no padding) — a valid Firestore doc id.
      final urlSafe = RegExp(r'^[A-Za-z0-9_-]+$');
      expect(urlSafe.hasMatch(a.invitationId!), isTrue);
      expect(urlSafe.hasMatch(b.invitationId!), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // watchMyInvitations
  // ═══════════════════════════════════════════════════════════════

  group('watchMyInvitations', () {
    test('emits only the calling resident\'s passes, round-tripped', () async {
      await createOne(residentId: 'resident-1', visitorName: 'Mine');
      await createOne(residentId: 'resident-2', visitorName: 'Theirs');

      final emissions = <List<VisitorInvitation>>[];
      final sub = repository
          .watchMyInvitations('resident-1')
          .listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions, isNotEmpty);
      final mine = emissions.last;
      expect(mine.length, 1);
      expect(mine.single.visitorName, 'Mine');
      expect(mine.single.status, VisitorPassStatus.active);
    });

    test('reflects a newly issued pass live', () async {
      final emissions = <List<VisitorInvitation>>[];
      final sub = repository
          .watchMyInvitations('resident-1')
          .listen(emissions.add);
      await settle();

      await createOne(residentId: 'resident-1', visitorName: 'Live');
      await settle();
      await sub.cancel();

      expect(emissions.last.map((i) => i.visitorName), contains('Live'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // QR scan and gate transitions
  // ═══════════════════════════════════════════════════════════════

  group('QR scan and gate transitions', () {
    test('loads a pass from a visitor QR payload', () async {
      final inv = await createOne();

      expect(repository.tokenFromQrPayload(inv.qrPayload), inv.invitationId);

      final loaded = await repository.getInvitationByQrPayload(inv.qrPayload);
      expect(loaded.invitationId, inv.invitationId);
      expect(loaded.visitorName, inv.visitorName);
      expect(loaded.status, VisitorPassStatus.active);
    });

    test('rejects foreign and malformed QR payloads', () {
      expect(
        () => repository.tokenFromQrPayload('https://example.com/visitor'),
        throwsA(isA<VisitorRepositoryException>()),
      );
      expect(
        () => repository.tokenFromQrPayload(
          '${VisitorRepository.qrPayloadPrefix}bad token',
        ),
        throwsA(isA<VisitorRepositoryException>()),
      );
    });

    test('checks a valid active pass in and then out', () async {
      final inv = await createOne();

      await repository.checkInInvitation(
        token: inv.invitationId!,
        staffId: 'guard-1',
      );
      var data = await firestore
          .collection('visitor_invitations')
          .doc(inv.invitationId)
          .get();
      expect(data.data()!['status'], 'checkedIn');
      expect(data.data()!['checkedInAt'], isA<Timestamp>());
      expect(data.data()!['checkedInBy'], 'guard-1');

      final checkedIn = await repository.getInvitationByToken(
        inv.invitationId!,
      );
      expect(checkedIn.status, VisitorPassStatus.checkedIn);

      await repository.checkOutInvitation(
        token: inv.invitationId!,
        staffId: 'guard-1',
      );
      data = await firestore
          .collection('visitor_invitations')
          .doc(inv.invitationId)
          .get();
      expect(data.data()!['status'], 'checkedOut');
      expect(data.data()!['checkedOutAt'], isA<Timestamp>());
      expect(data.data()!['checkedOutBy'], 'guard-1');
    });

    test('rejects check-in for an expired active pass', () async {
      final inv = await createOne(
        visitDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await expectLater(
        repository.checkInInvitation(
          token: inv.invitationId!,
          staffId: 'guard-1',
        ),
        throwsA(isA<VisitorRepositoryException>()),
      );
    });

    test('rejects check-in before the scheduled visit day', () async {
      final inv = await createOne(
        visitDate: DateTime.now().add(const Duration(days: 1)),
      );

      await expectLater(
        repository.checkInInvitation(
          token: inv.invitationId!,
          staffId: 'guard-1',
        ),
        throwsA(isA<VisitorRepositoryException>()),
      );
    });
  });

  // cancelInvitation

  group('cancelInvitation', () {
    test('transitions an active pass to cancelled', () async {
      final inv = await createOne(residentId: 'resident-1');
      await repository.cancelInvitation(
        token: inv.invitationId!,
        residentId: 'resident-1',
      );

      final data = await firestore
          .collection('visitor_invitations')
          .doc(inv.invitationId)
          .get();
      expect(data.data()!['status'], 'cancelled');
      expect(data.data()!['cancelledAt'], isA<Timestamp>());
      expect(data.data()!['cancelledBy'], 'resident-1');
    });

    test('rejects cancelling someone else\'s pass', () async {
      final inv = await createOne(residentId: 'resident-1');
      await expectLater(
        repository.cancelInvitation(
          token: inv.invitationId!,
          residentId: 'attacker',
        ),
        throwsA(isA<VisitorRepositoryException>()),
      );
      // Untouched.
      final data = await firestore
          .collection('visitor_invitations')
          .doc(inv.invitationId)
          .get();
      expect(data.data()!['status'], 'active');
    });

    test('rejects cancelling a non-active pass', () async {
      final inv = await createOne(residentId: 'resident-1');
      await repository.cancelInvitation(
        token: inv.invitationId!,
        residentId: 'resident-1',
      );
      // Second cancel: already cancelled, not active.
      await expectLater(
        repository.cancelInvitation(
          token: inv.invitationId!,
          residentId: 'resident-1',
        ),
        throwsA(isA<VisitorRepositoryException>()),
      );
    });

    test('rejects cancelling a non-existent pass', () async {
      await expectLater(
        repository.cancelInvitation(
          token: 'does-not-exist',
          residentId: 'resident-1',
        ),
        throwsA(isA<VisitorRepositoryException>()),
      );
    });
  });
}
