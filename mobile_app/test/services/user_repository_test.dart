import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/models/app_user.dart';
import 'package:mobile_app/services/user_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = UserRepository(firestore: fakeFirestore);
  });

  /// Seeds an active admin so approve/reject tests have an attribute-to UID.
  /// Bypasses createUserProfile (which hard-codes pending_approval) because
  /// the first admin must always be out-of-band provisioned.
  Future<void> seedAdmin(String uid) async {
    await fakeFirestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': '$uid@example.com',
      'name': 'Admin $uid',
      'role': 'admin',
      'status': 'active',
      'requestedUnit': null,
      'unitNumber': null,
      'phoneNumber': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': 'system',
      'rejectedAt': null,
      'rejectedBy': null,
      'mfaEnrolled': false,
      'fcmTokens': <String>[],
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // createUserProfile
  // ═══════════════════════════════════════════════════════════════

  group('createUserProfile', () {
    test('writes a doc with pending resident defaults', () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
        requestedUnit: 'C-22-250',
      );

      final doc =
          await fakeFirestore.collection('users').doc('user-123').get();

      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['uid'], 'user-123');
      expect(data['email'], 'alice@example.com');
      expect(data['name'], 'Alice Tan');
      expect(data['role'], 'resident');
      expect(data['status'], 'pending_approval');
      expect(data['requestedUnit'], 'C-22-250');
      expect(data['unitNumber'], isNull,
          reason: 'unitNumber must not be set until admin approval');
      expect(data['phoneNumber'], isNull);
      expect(data['approvedAt'], isNull);
      expect(data['approvedBy'], isNull);
      expect(data['rejectedAt'], isNull);
      expect(data['rejectedBy'], isNull);
      expect(data['mfaEnrolled'], isFalse);
      expect(data['fcmTokens'], isEmpty);
    });

    test('allows signup without a requestedUnit (public-only user)',
        () async {
      // A user who signs up with no unit claim is implicitly a public
      // user from the start. Admin will reject their residency claim
      // (there isn't one) — the reject path handles this cleanly.
      await repository.createUserProfile(
        uid: 'user-456',
        email: 'bob@example.com',
        name: 'Bob Lee',
      );

      final doc =
          await fakeFirestore.collection('users').doc('user-456').get();
      expect(doc.data()!['requestedUnit'], isNull);
      expect(doc.data()!['status'], 'pending_approval');
    });

    test('stamps createdAt and updatedAt with server timestamps',
        () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
      );

      final doc =
          await fakeFirestore.collection('users').doc('user-123').get();
      expect(doc.data()!['createdAt'], isA<Timestamp>());
      expect(doc.data()!['updatedAt'], isA<Timestamp>());
    });

    test(
      'INVARIANT: has no role/status parameters — cannot self-elevate',
      () async {
        // Type-level assertion. Documents the security property for
        // anyone who reads the test later and is tempted to add a
        // role parameter to createUserProfile.
        await repository.createUserProfile(
          uid: 'attacker-123',
          email: 'attacker@example.com',
          name: 'Mallory',
          requestedUnit: 'C-22-250',
        );

        final doc = await fakeFirestore
            .collection('users')
            .doc('attacker-123')
            .get();
        expect(doc.data()!['role'], 'resident');
        expect(doc.data()!['status'], 'pending_approval');
        expect(doc.data()!['unitNumber'], isNull,
            reason: 'Self-signup must never populate verified unitNumber');
      },
    );

    test('throws if a profile already exists for the uid', () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
      );

      expect(
        () => repository.createUserProfile(
          uid: 'user-123',
          email: 'alice@example.com',
          name: 'Alice Tan',
        ),
        throwsA(isA<UserRepositoryException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // createPublicProfile
  // ═══════════════════════════════════════════════════════════════

  group('createPublicProfile', () {
    test('creates public profile with role=public and status=active',
        () async {
      await repository.createPublicProfile(
        uid: 'public-uid',
        email: 'public@example.com',
        name: 'Public User',
      );

      final profile = await repository.getUserProfile('public-uid');
      expect(profile, isNotNull);
      expect(profile!.role, UserRole.public);
      expect(profile.status, UserStatus.active);
      expect(profile.email, 'public@example.com');
      expect(profile.name, 'Public User');
    });

    test('SECURITY: public profile has null unit fields', () async {
      await repository.createPublicProfile(
        uid: 'public-uid',
        email: 'public@example.com',
        name: 'Public User',
      );

      final profile = await repository.getUserProfile('public-uid');
      expect(profile!.requestedUnit, isNull);
      expect(profile.unitNumber, isNull);
    });

    test(
        'SECURITY: rejects creation if profile already exists '
        '(no silent downgrade of existing resident to public)', () async {
      // Create a pending resident profile first
      await repository.createUserProfile(
        uid: 'existing-uid',
        email: 'resident@example.com',
        name: 'Resident User',
        requestedUnit: 'A-12-3',
      );

      // Attempting to overwrite with a public profile must fail
      expect(
        () => repository.createPublicProfile(
          uid: 'existing-uid',
          email: 'resident@example.com',
          name: 'Resident User',
        ),
        throwsA(isA<UserRepositoryException>()),
      );

      // Verify the resident profile is untouched
      final profile = await repository.getUserProfile('existing-uid');
      expect(profile!.role, UserRole.resident);
      expect(profile.status, UserStatus.pendingApproval);
      expect(profile.requestedUnit, 'A-12-3');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // getUserProfile
  // ═══════════════════════════════════════════════════════════════

  group('getUserProfile', () {
    test('returns null when the doc does not exist', () async {
      final user = await repository.getUserProfile('nonexistent');
      expect(user, isNull);
    });

    test('returns a hydrated AppUser when the doc exists', () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
        requestedUnit: 'C-22-250',
      );

      final user = await repository.getUserProfile('user-123');

      expect(user, isNotNull);
      expect(user!.uid, 'user-123');
      expect(user.email, 'alice@example.com');
      expect(user.role, UserRole.resident);
      expect(user.status, UserStatus.pendingApproval);
      expect(user.requestedUnit, 'C-22-250');
      expect(user.unitNumber, isNull);
      expect(user.isVerifiedResident, isFalse,
          reason:
              'Pending users are NOT verified residents, regardless of claim');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // watchUserProfile
  // ═══════════════════════════════════════════════════════════════

  group('watchUserProfile', () {
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('emits the user after the doc is created', () async {
      final emissions = <AppUser?>[];
      final subscription =
          repository.watchUserProfile('user-123').listen(emissions.add);

      await settle();

      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
        requestedUnit: 'C-22-250',
      );

      await settle();
      await subscription.cancel();

      final nonNullEmissions = emissions.whereType<AppUser>().toList();
      expect(nonNullEmissions, isNotEmpty);
      expect(nonNullEmissions.last.uid, 'user-123');
      expect(nonNullEmissions.last.status, UserStatus.pendingApproval);
    });

    test('emits an updated user when admin approves', () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
        requestedUnit: 'C-22-250',
      );
      await seedAdmin('admin-001');

      final emissions = <AppUser?>[];
      final subscription =
          repository.watchUserProfile('user-123').listen(emissions.add);

      await settle();

      await repository.approveResident(
        targetUid: 'user-123',
        approvedByUid: 'admin-001',
      );

      await settle();
      await subscription.cancel();

      final nonNullEmissions = emissions.whereType<AppUser>().toList();

      expect(nonNullEmissions, isNotEmpty);
      expect(nonNullEmissions.last.status, UserStatus.active);
      expect(nonNullEmissions.last.role, UserRole.resident);
      expect(nonNullEmissions.last.unitNumber, 'C-22-250',
          reason: 'Approval must promote requestedUnit to unitNumber');
      expect(nonNullEmissions.last.requestedUnit, isNull,
          reason: 'requestedUnit must be cleared after approval');
      expect(nonNullEmissions.last.approvedBy, 'admin-001');

      final sawPending = nonNullEmissions
          .any((u) => u.status == UserStatus.pendingApproval);
      expect(sawPending, isTrue,
          reason: 'Stream should have emitted the pre-approval state '
              'before the post-approval state');
    });

    test('emits an updated user when admin rejects to public', () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
        requestedUnit: 'C-22-250',
      );
      await seedAdmin('admin-001');

      final emissions = <AppUser?>[];
      final subscription =
          repository.watchUserProfile('user-123').listen(emissions.add);

      await settle();

      await repository.rejectAsPublic(
        targetUid: 'user-123',
        rejectedByUid: 'admin-001',
      );

      await settle();
      await subscription.cancel();

      final nonNullEmissions = emissions.whereType<AppUser>().toList();

      expect(nonNullEmissions, isNotEmpty);
      expect(nonNullEmissions.last.role, UserRole.public);
      expect(nonNullEmissions.last.status, UserStatus.active);
      expect(nonNullEmissions.last.unitNumber, isNull);
      expect(nonNullEmissions.last.requestedUnit, isNull);
      expect(nonNullEmissions.last.rejectedBy, 'admin-001');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // updateProfile
  // ═══════════════════════════════════════════════════════════════

  group('updateProfile', () {
    test('updates only the fields passed in', () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
        requestedUnit: 'C-22-250',
      );

      await repository.updateProfile(
        uid: 'user-123',
        phoneNumber: '+60123456789',
      );

      final user = await repository.getUserProfile('user-123');
      expect(user!.phoneNumber, '+60123456789');
      expect(user.name, 'Alice Tan',
          reason: 'Name must be untouched — we did not pass it');
    });

    test(
      'INVARIANT: cannot mutate role, status, unitNumber, or requestedUnit',
      () async {
        // Type-level assertion. These are the privilege-relevant fields
        // and have no parameters on updateProfile. The test documents
        // the property; the method signature enforces it.
        await repository.createUserProfile(
          uid: 'user-123',
          email: 'alice@example.com',
          name: 'Alice Tan',
          requestedUnit: 'C-22-250',
        );

        await repository.updateProfile(
          uid: 'user-123',
          name: 'Alice Renamed',
        );

        final user = await repository.getUserProfile('user-123');
        expect(user!.role, UserRole.resident);
        expect(user.status, UserStatus.pendingApproval);
        expect(user.unitNumber, isNull);
        expect(user.requestedUnit, 'C-22-250',
            reason:
                'Self-edit must not let users swap their requested unit');
      },
    );

    test('throws if called with no fields to update', () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'alice@example.com',
        name: 'Alice Tan',
      );

      expect(
        () => repository.updateProfile(uid: 'user-123'),
        throwsA(isA<UserRepositoryException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // approveResident
  // ═══════════════════════════════════════════════════════════════

  group('approveResident', () {
    test('promotes requestedUnit to unitNumber and stamps audit',
        () async {
      await repository.createUserProfile(
        uid: 'resident-001',
        email: 'r@example.com',
        name: 'Resident',
        requestedUnit: 'C-22-250',
      );

      await repository.approveResident(
        targetUid: 'resident-001',
        approvedByUid: 'admin-001',
      );

      final user = await repository.getUserProfile('resident-001');
      expect(user!.status, UserStatus.active);
      expect(user.role, UserRole.resident);
      expect(user.unitNumber, 'C-22-250');
      expect(user.requestedUnit, isNull);
      expect(user.approvedBy, 'admin-001');
      expect(user.approvedAt, isNotNull);
      expect(user.isVerifiedResident, isTrue);
    });

    test('INVARIANT: rejects self-approval', () async {
      await repository.createUserProfile(
        uid: 'admin-001',
        email: 'admin@example.com',
        name: 'Admin',
        requestedUnit: 'A-01-01',
      );

      expect(
        () => repository.approveResident(
          targetUid: 'admin-001',
          approvedByUid: 'admin-001',
        ),
        throwsA(isA<UserRepositoryException>()),
      );
    });

    test('INVARIANT: rejects approval without a requestedUnit', () async {
      // User signed up without a unit claim. Cannot be approved as
      // resident — nothing to approve them into.
      await repository.createUserProfile(
        uid: 'user-noclaim',
        email: 'noclaim@example.com',
        name: 'No Claim',
      );

      expect(
        () => repository.approveResident(
          targetUid: 'user-noclaim',
          approvedByUid: 'admin-001',
        ),
        throwsA(isA<UserRepositoryException>()),
      );
    });

    test('INVARIANT: rejects approval of already-active user', () async {
      await repository.createUserProfile(
        uid: 'resident-001',
        email: 'r@example.com',
        name: 'Resident',
        requestedUnit: 'C-22-250',
      );
      await repository.approveResident(
        targetUid: 'resident-001',
        approvedByUid: 'admin-001',
      );

      // Second approval attempt. Must fail — re-approval is a bug signal.
      expect(
        () => repository.approveResident(
          targetUid: 'resident-001',
          approvedByUid: 'admin-002',
        ),
        throwsA(isA<UserRepositoryException>()),
      );
    });

    test('INVARIANT: rejects approval of nonexistent user', () async {
      expect(
        () => repository.approveResident(
          targetUid: 'ghost-user',
          approvedByUid: 'admin-001',
        ),
        throwsA(isA<UserRepositoryException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // rejectAsPublic
  // ═══════════════════════════════════════════════════════════════

  group('rejectAsPublic', () {
    test('downgrades role to public and stamps audit', () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'u@example.com',
        name: 'User',
        requestedUnit: 'C-22-250',
      );

      await repository.rejectAsPublic(
        targetUid: 'user-123',
        rejectedByUid: 'admin-001',
      );

      final user = await repository.getUserProfile('user-123');
      expect(user!.role, UserRole.public);
      expect(user.status, UserStatus.active);
      expect(user.unitNumber, isNull);
      expect(user.requestedUnit, isNull,
          reason: 'Rejection must clear the unverified claim');
      expect(user.rejectedBy, 'admin-001');
      expect(user.rejectedAt, isNotNull);
      expect(user.isVerifiedResident, isFalse);
    });

    test('works on users who signed up without a requestedUnit',
        () async {
      // No unit claim to reject, but we still flip status to active and
      // role to public so they can use the general-feedback features.
      await repository.createUserProfile(
        uid: 'user-noclaim',
        email: 'nc@example.com',
        name: 'No Claim',
      );

      await repository.rejectAsPublic(
        targetUid: 'user-noclaim',
        rejectedByUid: 'admin-001',
      );

      final user = await repository.getUserProfile('user-noclaim');
      expect(user!.role, UserRole.public);
      expect(user.status, UserStatus.active);
    });

    test('INVARIANT: rejects self-rejection', () async {
      await repository.createUserProfile(
        uid: 'admin-001',
        email: 'a@example.com',
        name: 'Admin',
      );

      expect(
        () => repository.rejectAsPublic(
          targetUid: 'admin-001',
          rejectedByUid: 'admin-001',
        ),
        throwsA(isA<UserRepositoryException>()),
      );
    });

    test('INVARIANT: rejection does NOT grant admin or staff role',
        () async {
      await repository.createUserProfile(
        uid: 'attacker',
        email: 'a@example.com',
        name: 'Mallory',
        requestedUnit: 'A-01-01',
      );

      await repository.rejectAsPublic(
        targetUid: 'attacker',
        rejectedByUid: 'admin-001',
      );

      final user = await repository.getUserProfile('attacker');
      expect(user!.role, isNot(UserRole.admin));
      expect(user.role, isNot(UserRole.staff));
      expect(user.role, UserRole.public);
    });

    test('INVARIANT: rejects rejection of already-active user',
        () async {
      await repository.createUserProfile(
        uid: 'user-123',
        email: 'u@example.com',
        name: 'User',
        requestedUnit: 'C-22-250',
      );
      await repository.approveResident(
        targetUid: 'user-123',
        approvedByUid: 'admin-001',
      );

      // User is now an active resident. Cannot reject a non-pending user.
      // If admin wants to demote them, that's "suspend" (future sprint).
      expect(
        () => repository.rejectAsPublic(
          targetUid: 'user-123',
          rejectedByUid: 'admin-001',
        ),
        throwsA(isA<UserRepositoryException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // listPendingApprovals
  // ═══════════════════════════════════════════════════════════════

  group('listPendingApprovals', () {
    test('returns only users with pending_approval status', () async {
      await repository.createUserProfile(
        uid: 'pending-1',
        email: 'p1@example.com',
        name: 'Pending One',
        requestedUnit: 'A-01-01',
      );
      await repository.createUserProfile(
        uid: 'pending-2',
        email: 'p2@example.com',
        name: 'Pending Two',
        requestedUnit: 'B-02-02',
      );
      await repository.createUserProfile(
        uid: 'active-1',
        email: 'a1@example.com',
        name: 'Active One',
        requestedUnit: 'C-03-03',
      );
      await repository.approveResident(
        targetUid: 'active-1',
        approvedByUid: 'admin-001',
      );

      final pending = await repository.listPendingApprovals();

      expect(pending.length, 2);
      expect(
        pending.map((u) => u.uid).toSet(),
        {'pending-1', 'pending-2'},
      );
    });

    test('excludes users rejected to public', () async {
      await repository.createUserProfile(
        uid: 'pending-1',
        email: 'p1@example.com',
        name: 'Pending',
        requestedUnit: 'A-01-01',
      );
      await repository.createUserProfile(
        uid: 'rejected-1',
        email: 'r1@example.com',
        name: 'Rejected',
        requestedUnit: 'B-02-02',
      );
      await repository.rejectAsPublic(
        targetUid: 'rejected-1',
        rejectedByUid: 'admin-001',
      );

      final pending = await repository.listPendingApprovals();

      expect(pending.length, 1);
      expect(pending.first.uid, 'pending-1');
    });

    test('respects the limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await repository.createUserProfile(
          uid: 'pending-$i',
          email: 'p$i@example.com',
          name: 'Pending $i',
          requestedUnit: 'A-$i-$i',
        );
      }

      final pending = await repository.listPendingApprovals(limit: 3);
      expect(pending.length, 3);
    });

    test('returns empty list when no pending users exist', () async {
      final pending = await repository.listPendingApprovals();
      expect(pending, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // listPendingResidents (live stream for approval dashboards)
  // ═══════════════════════════════════════════════════════════════

  group('listPendingResidents', () {
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
        'emits only pending residents — excludes approved, rejected, and non-resident accounts',
        () async {
      await repository.createUserProfile(
        uid: 'pending-r1',
        email: 'r1@example.com',
        name: 'Pending Resident',
        requestedUnit: 'A-01-01',
      );
      await repository.createPublicProfile(
        uid: 'pub-1',
        email: 'pub@example.com',
        name: 'Public',
      );
      await repository.createUserProfile(
        uid: 'approved-r1',
        email: 'r2@example.com',
        name: 'Approved Resident',
        requestedUnit: 'B-02-02',
      );
      await repository.approveResident(
        targetUid: 'approved-r1',
        approvedByUid: 'admin-001',
      );
      await repository.createUserProfile(
        uid: 'rejected-r1',
        email: 'r3@example.com',
        name: 'Rejected',
        requestedUnit: 'C-03-03',
      );
      await repository.rejectAsPublic(
        targetUid: 'rejected-r1',
        rejectedByUid: 'admin-001',
      );

      final emissions = <List<AppUser>>[];
      final sub = repository.listPendingResidents().listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions, isNotEmpty);
      expect(emissions.last.map((u) => u.uid).toSet(), {'pending-r1'});
    });

    test('returns empty list when no pending residents exist', () async {
      final emissions = <List<AppUser>>[];
      final sub = repository.listPendingResidents().listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions, isNotEmpty);
      expect(emissions.last, isEmpty);
    });

    test('emits an updated list when a pending resident is approved',
        () async {
      await repository.createUserProfile(
        uid: 'pending-1',
        email: 'p1@example.com',
        name: 'Alice',
        requestedUnit: 'A-01-01',
      );
      await repository.createUserProfile(
        uid: 'pending-2',
        email: 'p2@example.com',
        name: 'Bob',
        requestedUnit: 'B-02-02',
      );

      final emissions = <List<AppUser>>[];
      final sub = repository.listPendingResidents().listen(emissions.add);
      await settle();

      await repository.approveResident(
        targetUid: 'pending-1',
        approvedByUid: 'admin-001',
      );
      await settle();
      await sub.cancel();

      expect(emissions, isNotEmpty);
      expect(emissions.first.length, 2,
          reason: 'Initial emission should include both pending residents');
      expect(emissions.last.length, 1);
      expect(emissions.last.first.uid, 'pending-2',
          reason:
              'Approved resident must disappear from the pending stream');
    });

    test('orders by createdAt ascending (oldest first — fair queue)',
        () async {
      await repository.createUserProfile(
        uid: 'first',
        email: 'first@example.com',
        name: 'First Applicant',
        requestedUnit: 'A-01-01',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.createUserProfile(
        uid: 'second',
        email: 'second@example.com',
        name: 'Second Applicant',
        requestedUnit: 'B-02-02',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.createUserProfile(
        uid: 'third',
        email: 'third@example.com',
        name: 'Third Applicant',
        requestedUnit: 'C-03-03',
      );

      final emissions = <List<AppUser>>[];
      final sub = repository.listPendingResidents().listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions, isNotEmpty);
      expect(
        emissions.last.map((u) => u.uid).toList(),
        ['first', 'second', 'third'],
      );
    });
  });
}