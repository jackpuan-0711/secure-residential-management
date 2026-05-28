import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';
// UserRole moved to its own file so AuthIdentity can use it without
// importing this (cloud_firestore-dependent) library. Re-exported here so
// existing `import '.../app_user.dart'` callers keep seeing UserRole.
export 'user_role.dart';

/// The account lifecycle status. Decoupled from role so an admin can
/// suspend a user without changing what they are.
///
/// Lifecycle:
///   pendingApproval → active  (admin approved residency claim)
///   pendingApproval → active  (admin rejected; role also flips to public)
///   active          → suspended (admin suspends, e.g. for abuse or move-out)
///
/// There is no transition FROM suspended back to active by the client.
/// That requires admin action (future sprint).
enum UserStatus {
  pendingApproval,
  active,
  suspended;

  String toFirestoreValue() {
    switch (this) {
      case UserStatus.pendingApproval:
        return 'pending_approval';
      case UserStatus.active:
        return 'active';
      case UserStatus.suspended:
        return 'suspended';
    }
  }

  static UserStatus fromFirestoreValue(String value) {
    switch (value) {
      case 'pending_approval':
        return UserStatus.pendingApproval;
      case 'active':
        return UserStatus.active;
      case 'suspended':
        return UserStatus.suspended;
      default:
        throw ArgumentError('Unknown UserStatus: "$value"');
    }
  }
}

/// Domain representation of a user in the residential management system.
///
/// This is the Firestore-backed profile at /users/{uid}, NOT the Firebase
/// Auth user. The Firebase Auth UID is the link between them.
///
/// KEY FIELDS FOR SECURITY:
///   - requestedUnit: a CLAIM made at signup, not a fact. Never grants
///     privileges on its own.
///   - unitNumber: the VERIFIED unit. Only set after admin approval.
///     Grants unit-scoped privileges (visitor registration, maintenance
///     requests, unit-targeted announcements).
class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final UserStatus status;

  /// The elevated role this user is REQUESTING, pending approval. Only
  /// ever [UserRole.admin] in practice: set when an account applies
  /// through the admin-registration flow, and cleared when a superadmin
  /// approves (role + {role} claim are granted together, server-side) or
  /// rejects. Null for ordinary resident/public signups. Never grants
  /// privilege on its own — the signed {role} claim does.
  final UserRole? requestedRole;

  /// The unit this user CLAIMS to occupy, pending admin verification.
  /// Shown to admins on the approval dashboard. Cleared on approval
  /// (where its value migrates to unitNumber) or rejection (where it
  /// is discarded).
  final String? requestedUnit;

  /// The VERIFIED unit occupied by this user. Only set by admin approval.
  /// Absence of this field means no unit-scoped access, regardless of role.
  final String? unitNumber;

  final String? phoneNumber;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  /// If the admin REJECTED a residency claim, this records who and when.
  /// Separate from approvedAt/approvedBy so the audit trail distinguishes
  /// between "approved as resident" and "rejected, downgraded to public."
  final DateTime? rejectedAt;
  final String? rejectedBy;

  final bool mfaEnrolled;
  final List<String> fcmTokens;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    this.requestedRole,
    this.requestedUnit,
    this.unitNumber,
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.mfaEnrolled = false,
    this.fcmTokens = const [],
  });

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('User document "${snapshot.id}" has no data');
    }

    return AppUser(
      uid: snapshot.id,
      email: data['email'] as String,
      name: data['name'] as String,
      role: UserRole.fromFirestoreValue(data['role'] as String),
      status: UserStatus.fromFirestoreValue(data['status'] as String),
      requestedRole: data['requestedRole'] != null
          ? UserRole.fromFirestoreValue(data['requestedRole'] as String)
          : null,
      requestedUnit: data['requestedUnit'] as String?,
      unitNumber: data['unitNumber'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      approvedBy: data['approvedBy'] as String?,
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      rejectedBy: data['rejectedBy'] as String?,
      mfaEnrolled: data['mfaEnrolled'] as bool? ?? false,
      fcmTokens:
          (data['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.toFirestoreValue(),
      'status': status.toFirestoreValue(),
      'requestedRole': requestedRole?.toFirestoreValue(),
      'requestedUnit': requestedUnit,
      'unitNumber': unitNumber,
      'phoneNumber': phoneNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'approvedAt':
          approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'rejectedAt':
          rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectedBy': rejectedBy,
      'mfaEnrolled': mfaEnrolled,
      'fcmTokens': fcmTokens,
    };
  }

  AppUser copyWith({
    String? email,
    String? name,
    UserRole? role,
    UserStatus? status,
    UserRole? requestedRole,
    String? requestedUnit,
    String? unitNumber,
    String? phoneNumber,
    DateTime? updatedAt,
    DateTime? approvedAt,
    String? approvedBy,
    DateTime? rejectedAt,
    String? rejectedBy,
    bool? mfaEnrolled,
    List<String>? fcmTokens,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      requestedRole: requestedRole ?? this.requestedRole,
      requestedUnit: requestedUnit ?? this.requestedUnit,
      unitNumber: unitNumber ?? this.unitNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      mfaEnrolled: mfaEnrolled ?? this.mfaEnrolled,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }

  /// Convenience: is this user a VERIFIED resident with unit-scoped access?
  /// Use this in UI code instead of manually checking role + status + unitNumber.
  bool get isVerifiedResident =>
      role == UserRole.resident &&
      status == UserStatus.active &&
      unitNumber != null;

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, role: ${role.name}, '
      'status: ${status.name}, unitNumber: $unitNumber)';
}