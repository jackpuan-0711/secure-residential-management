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

  /// The role requested by an active public user. The supported self-service
  /// request is resident access; administrator roles are assigned directly by
  /// the superadmin and never requested from a public account.
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

    final rawEmail = data['email'];
    final rawName = data['name'];
    final rawRole = data['role'];
    final rawStatus = data['status'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    final fallbackDate = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    UserRole parseRole(Object? value) {
      if (value is! String) return UserRole.public;
      try {
        return UserRole.fromFirestoreValue(value);
      } on ArgumentError {
        return UserRole.public;
      }
    }

    UserStatus parseStatus(Object? value) {
      if (value is! String) return UserStatus.suspended;
      try {
        return UserStatus.fromFirestoreValue(value);
      } on ArgumentError {
        return UserStatus.suspended;
      }
    }

    final email = rawEmail is String ? rawEmail.trim() : '';
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : (email.isEmpty ? 'Account' : email.split('@').first);

    return AppUser(
      uid: snapshot.id,
      email: email,
      name: name,
      role: parseRole(rawRole),
      status: parseStatus(rawStatus),
      requestedRole: data['requestedRole'] is String
          ? parseRole(data['requestedRole'])
          : null,
      requestedUnit: data['requestedUnit'] is String
          ? data['requestedUnit'] as String
          : null,
      unitNumber: data['unitNumber'] is String
          ? data['unitNumber'] as String
          : null,
      phoneNumber: data['phoneNumber'] is String
          ? data['phoneNumber'] as String
          : null,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : fallbackDate,
      updatedAt: updatedAt is Timestamp
          ? updatedAt.toDate()
          : (createdAt is Timestamp ? createdAt.toDate() : fallbackDate),
      approvedAt: data['approvedAt'] is Timestamp
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'] is String
          ? data['approvedBy'] as String
          : null,
      rejectedAt: data['rejectedAt'] is Timestamp
          ? (data['rejectedAt'] as Timestamp).toDate()
          : null,
      rejectedBy: data['rejectedBy'] is String
          ? data['rejectedBy'] as String
          : null,
      mfaEnrolled: data['mfaEnrolled'] == true,
      fcmTokens:
          (data['fcmTokens'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
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
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
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
    bool clearPhoneNumber = false,
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
      phoneNumber: clearPhoneNumber ? null : phoneNumber ?? this.phoneNumber,
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
