import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../utils/validators.dart';

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

  CollectionReference<AppUser> get _usersRef => _firestore
      .collection('users')
      .withConverter<AppUser>(
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
      'requestedRole': null,
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

  /// Creates /users/{uid} as a PUBLIC-tier account after successful
  /// Firebase Auth signup.
  ///
  /// Public-tier users are authenticated app users who are NOT residents
  /// and do not need admin approval. They can view announcements and
  /// submit general feedback. They CANNOT submit property complaints,
  /// pre-register visitors, or access any unit-scoped features.
  ///
  /// The user starts ACTIVE because no verification is needed — they are
  /// not claiming any unit-level privileges. This is the key distinction
  /// from createUserProfile (resident claim, starts pendingApproval).
  ///
  /// ─── SECURITY INVARIANTS ────────────────────────────────────────
  ///   - role HARDCODED to public. Clients cannot self-promote.
  ///   - status HARDCODED to active. Nothing to verify.
  ///   - requestedUnit and unitNumber HARDCODED to null. Their
  ///     ABSENCE from the method signature is deliberate — the type
  ///     system prevents any caller from passing a unit value.
  ///   - Pre-existence check prevents overwriting (no silent
  ///     downgrade of a resident profile to public via replay).
  /// ────────────────────────────────────────────────────────────────
  ///
  /// ─── PSM-2 EXTENSION NOTE ──────────────────────────────────────
  /// The `public` role is a PSM-2 extension of the PSM-1 RBAC model
  /// (Admin, Staff, Resident, Visitor). DISTINCT from the PSM-1
  /// Visitor entity (unauthenticated QR-code guest, UC003).
  /// ────────────────────────────────────────────────────────────────
  Future<void> createPublicProfile({
    required String uid,
    required String email,
    required String name,
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
      'role': UserRole.public.toFirestoreValue(),
      'status': UserStatus.active.toFirestoreValue(),
      'requestedRole': null,
      'requestedUnit': null,
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
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
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
    bool clearPhoneNumber = false,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (clearPhoneNumber) {
      updates['phoneNumber'] = null;
    } else if (phoneNumber != null) {
      updates['phoneNumber'] = phoneNumber;
    }

    if (updates.length == 1) {
      throw const UserRepositoryException(
        'updateProfile called with no fields to update.',
      );
    }

    await _firestore.collection('users').doc(uid).update(updates);
  }

  // ═══════════════════════════════════════════════════════════════
  // SELF-SERVICE — public → resident upgrade application
  // ═══════════════════════════════════════════════════════════════

  /// An active PUBLIC user applies to become a resident by submitting a
  /// unit claim. Mirrors the resident-signup pending state, but as an
  /// in-place upgrade rather than a fresh profile.
  ///
  /// TRANSACTION + invariants (a double-apply or a non-public caller is
  /// a bug or an attack, so we reject rather than silently no-op):
  ///   - profile must exist
  ///   - role == 'public' AND status == 'active'
  ///   - requestedRole == null AND requestedUnit == null (no double-apply)
  ///   - requestedUnit matches the canonical format
  ///
  /// On success: status → pending_approval, requestedRole → 'resident',
  /// requestedUnit → `<value>`. role stays 'public' until an admin approves
  /// (which grants the role + the server-side claim). unitNumber stays
  /// null — it is only ever set by verified approval.
  ///
  /// SECURITY: the unit regex is re-validated HERE (defence in depth)
  /// even though the form and the Firestore rule both check it — client
  /// validation is never a trust boundary (CWE-20 / CWE-602).
  Future<void> applyForResident({
    required String uid,
    required String requestedUnit,
  }) async {
    final unit = requestedUnit.trim();
    if (!unitNumberRegExp.hasMatch(unit)) {
      throw const UserRepositoryException('Invalid unit number format.');
    }

    final docRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw const UserRepositoryException(
          'Cannot apply: no profile on record for this account.',
        );
      }

      final data = snap.data()!;
      if (data['role'] != UserRole.public.toFirestoreValue() ||
          data['status'] != UserStatus.active.toFirestoreValue()) {
        throw const UserRepositoryException(
          'Only an active public user can apply for resident access.',
        );
      }
      if (data['requestedRole'] != null || data['requestedUnit'] != null) {
        throw const UserRepositoryException(
          'A resident application is already on record.',
        );
      }

      tx.update(docRef, {
        'status': UserStatus.pendingApproval.toFirestoreValue(),
        'requestedRole': UserRole.resident.toFirestoreValue(),
        'requestedUnit': unit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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

      // A public applicant being approved is promoted to resident here;
      // an already-resident applicant simply keeps role=resident. Either
      // way the post-state is unambiguously a verified resident with no
      // outstanding role request, so we set both explicitly.
      tx.update(docRef, {
        'role': UserRole.resident.toFirestoreValue(),
        'requestedRole': null,
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
        'requestedRole': null,
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
        .where(
          'status',
          isEqualTo: UserStatus.pendingApproval.toFirestoreValue(),
        )
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // LIST — pending residents (live stream for approval dashboards)
  // ═══════════════════════════════════════════════════════════════

  /// Live stream of pending resident applicants for the admin /
  /// superadmin approval queue.
  ///
  /// Surfaces users with `status == 'pending_approval'` who are EITHER
  /// already role `resident` (signed up as a resident) OR a `public`
  /// user who applied to upgrade (`requestedRole == 'resident'`). Ordered
  /// by `createdAt` ASC (fair-queue: the longest-waiting applicant is on
  /// top). A Stream, so rows vanish automatically as approve / reject
  /// transitions flip status off `pending_approval`.
  ///
  /// The role/requestedRole OR is applied client-side after a single
  /// `status` equality query: Firestore can't express a disjunction
  /// across two fields in one query, and filtering the small pending set
  /// in Dart avoids a composite index and keeps the predicate obvious.
  ///
  /// SECURITY: Firestore rules grant read on `/users` only to the owner
  /// OR a claim admin / superadmin; an unprivileged subscriber gets a
  /// permission-denied error rather than data.
  Stream<List<AppUser>> listPendingResidents() {
    return _firestore
        .collection('users')
        .where(
          'status',
          isEqualTo: UserStatus.pendingApproval.toFirestoreValue(),
        )
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppUser.fromFirestore(d, null))
              .where(
                (u) =>
                    u.role == UserRole.resident ||
                    u.requestedRole == UserRole.resident,
              )
              .toList(),
        );
  }

  /// Live stream of active administrators for the superadmin console.
  /// Role changes are performed by callable functions because the Firebase
  /// Auth custom claim is the authorization boundary.
  Stream<List<AppUser>> listAdmins() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.admin.name)
        .snapshots()
        .map((snap) {
          final admins = snap.docs
              .map((d) => AppUser.fromFirestore(d, null))
              .where((u) => u.status == UserStatus.active)
              .toList();
          admins.sort((a, b) => a.name.compareTo(b.name));
          return admins;
        });
  }

  Future<List<AppUser>> listAdminCandidates() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.public.name)
        .get();
    final users = snapshot.docs
        .map((doc) => AppUser.fromFirestore(doc, null))
        .where((user) => user.status == UserStatus.active)
        .toList();
    users.sort((a, b) => a.name.compareTo(b.name));
    return users;
  }

  Future<void> addAdmin({
    required String targetUid,
    required String approvedByUid,
  }) async {
    if (targetUid == approvedByUid) {
      throw const UserRepositoryException(
        'You cannot change your own superadmin access.',
      );
    }

    final ref = _firestore.collection('users').doc(targetUid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw const UserRepositoryException('Account not found.');
      }
      final data = snapshot.data()!;
      if (data['role'] != UserRole.public.name ||
          data['status'] != UserStatus.active.toFirestoreValue()) {
        throw const UserRepositoryException(
          'Only an active public account can become an administrator.',
        );
      }

      transaction.update(ref, {
        'role': UserRole.admin.name,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approvedByUid,
        'adminRemovedAt': null,
        'adminRemovedBy': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> removeAdmin({
    required String targetUid,
    required String removedByUid,
  }) async {
    if (targetUid == removedByUid) {
      throw const UserRepositoryException(
        'You cannot remove your own superadmin access.',
      );
    }

    final ref = _firestore.collection('users').doc(targetUid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data()?['role'] != UserRole.admin.name) {
        throw const UserRepositoryException('Administrator not found.');
      }

      transaction.update(ref, {
        'role': UserRole.public.name,
        'approvedAt': null,
        'approvedBy': null,
        'adminRemovedAt': FieldValue.serverTimestamp(),
        'adminRemovedBy': removedByUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
