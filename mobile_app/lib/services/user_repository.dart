import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Thrown when a repository operation violates a domain invariant
/// (e.g. attempting to self-approve, or mutating an immutable field).
/// These represent bugs or attacks, not user-facing errors.
class UserRepositoryException implements Exception {
  final String message;
  const UserRepositoryException(this.message);

  @override
  String toString() => 'UserRepositoryException: $message';
}

/// The single chokepoint for all reads and writes to /users/{uid}.
///
/// THREAT MODEL NOTES:
///   - createUserProfile hard-codes role=resident, status=pendingApproval,
///     and unitNumber=null. Clients cannot self-promote via signup.
///   - updateProfile has no role/status/unitNumber parameter. Clients
///     cannot self-promote via profile edits either.
///   - approveResident and rejectAsPublic are the ONLY methods that write
///     to unitNumber or status=active. They are called by admin UIs that
///     Firestore rules will additionally gate by role (Step 5).
///   - Self-approval and self-rejection are blocked at the application
///     layer as a two-person-rule defense.
class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<AppUser> get _usersRef =>
      _firestore.collection('users').withConverter<AppUser>(
            fromFirestore: AppUser.fromFirestore,
            toFirestore: (user, _) => user.toFirestore(),
          );

  // ═══════════════════════════════════════════════════════════════
  // CREATE
  // ═══════════════════════════════════════════════════════════════

  /// Creates /users/{uid} after successful Firebase Auth signup.
  ///
  /// The user starts as a PENDING RESIDENT CLAIM:
  ///   - role:          resident (they claim to be one)
  ///   - status:        pending_approval (not yet verified)
  ///   - requestedUnit: their self-reported unit (to be verified by admin)
  ///   - unitNumber:    null (no unit-scoped privileges until approved)
  ///
  /// On admin approval → status flips to active, requestedUnit → unitNumber.
  /// On admin rejection → status flips to active, role → public, requestedUnit cleared.
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String name,
    String? requestedUnit,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);

    final existing = await docRef.get();
    if (existing.exists) {
      throw const UserRepositoryException(
        'User profile already exists. Use updateProfile() instead.',
      );
    }

    await docRef.set({
      'uid': uid,
      'email': email,
      'name': name,
      'role': UserRole.resident.toFirestoreValue(),
      'status': UserStatus.pendingApproval.toFirestoreValue(),
      'requestedUnit': requestedUnit,
      'unitNumber': null,
      'phoneNumber': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'approvedAt': null,
      'approvedBy': null,
      'rejectedAt': null,
      'rejectedBy': null,
      'mfaEnrolled': false,
      'fcmTokens': <String>[],
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════════

  Future<AppUser?> getUserProfile(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    return snapshot.data();
  }

  /// Reactive read. Manually converts snapshots (not via withConverter)
  /// to work around a reactivity gap in fake_cloud_firestore 4.x when
  /// subscribing to docs that don't exist at subscribe-time. Real
  /// Firestore behavior is identical under both paths.
  Stream<AppUser?> watchUserProfile(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return AppUser.fromFirestore(snapshot, null);
    });
  }
  
  // ═══════════════════════════════════════════════════════════════
  // UPDATE — self-service profile edits
  // ═══════════════════════════════════════════════════════════════

  /// Lets a user update their own MUTABLE profile fields.
  ///
  /// Explicitly has no role/status/unitNumber/requestedUnit parameter —
  /// those are privilege-relevant and must flow through admin-gated
  /// methods, not through a self-edit codepath.
  ///
  /// Residents CAN update their phoneNumber even before approval, but
  /// they CANNOT change the unit they requested — they'd have to delete
  /// and resubmit. This prevents the "admin approves C-22-250 but user
  /// swaps to D-01-001 after approval" attack.
  Future<void> updateProfile({
    required String uid,
    String? name,
    String? phoneNumber,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;

    if (updates.length == 1) {
      throw const UserRepositoryException(
        'updateProfile called with no fields to update.',
      );
    }

    await _firestore.collection('users').doc(uid).update(updates);
  }

  // ═══════════════════════════════════════════════════════════════
  // ADMIN OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Admin approves a resident's unit claim.
  ///
  /// Effects:
  ///   - status: pending_approval → active
  ///   - requestedUnit → unitNumber (the claim becomes the verified fact)
  ///   - requestedUnit is cleared
  ///   - approvedAt and approvedBy are stamped
  ///   - role stays 'resident'
  ///
  /// Firestore rules (Step 5) gate this by admin role at the infra layer.
  /// This method is the second defense layer (application layer).
  Future<void> approveResident({
    required String targetUid,
    required String approvedByUid,
  }) async {
    if (targetUid == approvedByUid) {
      throw const UserRepositoryException(
        'Users cannot approve their own accounts.',
      );
    }

    final docRef = _firestore.collection('users').doc(targetUid);

    // Transaction ensures we read requestedUnit and promote it atomically.
    // Without this, a racing updateProfile could slip between the read
    // and write. Overkill for PSM-2 load, correct for a security project.
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw const UserRepositoryException(
          'Cannot approve a user that does not exist.',
        );
      }

      final data = snap.data()!;
      final status = data['status'] as String?;
      if (status != 'pending_approval') {
        throw UserRepositoryException(
          'Cannot approve user: status is "$status", expected '
          '"pending_approval".',
        );
      }

      final requestedUnit = data['requestedUnit'] as String?;
      if (requestedUnit == null || requestedUnit.isEmpty) {
        throw const UserRepositoryException(
          'Cannot approve as resident: no requestedUnit on record. '
          'User should be approved only after submitting a unit claim.',
        );
      }

      tx.update(docRef, {
        'status': UserStatus.active.toFirestoreValue(),
        'unitNumber': requestedUnit,
        'requestedUnit': null,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approvedByUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Admin rejects a resident's claim. User is downgraded to public role,
  /// but their account remains usable for limited features (general
  /// feedback only — no unit-scoped operations).
  ///
  /// Effects:
  ///   - role: resident → public
  ///   - status: pending_approval → active
  ///   - requestedUnit is cleared (they get no privileges from it)
  ///   - rejectedAt and rejectedBy are stamped
  ///   - unitNumber stays null
  ///
  /// INTENTIONALLY DOES NOT delete the account. Deletion is a separate
  /// admin operation (future sprint) for abuse cases. Rejection is the
  /// normal outcome for "you're not actually a unit occupant."
  Future<void> rejectAsPublic({
    required String targetUid,
    required String rejectedByUid,
  }) async {
    if (targetUid == rejectedByUid) {
      throw const UserRepositoryException(
        'Users cannot reject their own accounts.',
      );
    }

    final docRef = _firestore.collection('users').doc(targetUid);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw const UserRepositoryException(
          'Cannot reject a user that does not exist.',
        );
      }

      final data = snap.data()!;
      final status = data['status'] as String?;
      if (status != 'pending_approval') {
        throw UserRepositoryException(
          'Cannot reject user: status is "$status", expected '
          '"pending_approval".',
        );
      }

      tx.update(docRef, {
        'role': UserRole.public.toFirestoreValue(),
        'status': UserStatus.active.toFirestoreValue(),
        'requestedUnit': null,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': rejectedByUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Lists users awaiting admin approval, newest first. Paginated.
  Future<List<AppUser>> listPendingApprovals({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<AppUser> query = _usersRef
        .where('status',
            isEqualTo: UserStatus.pendingApproval.toFirestoreValue())
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}