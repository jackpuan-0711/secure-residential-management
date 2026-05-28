/// The role assigned to a user — the app's RBAC primitive.
///
/// ─── WHERE THIS LIVES & WHY IT'S ITS OWN FILE ────────────────────
/// Extracted from app_user.dart (Sprint 2, admin module) so that
/// AuthIdentity can carry the role WITHOUT importing AppUser — and so
/// without dragging cloud_firestore into the lightweight, Firebase-free
/// auth-session type. app_user.dart re-exports this enum, so existing
/// `import '.../app_user.dart'` callers are unaffected.
///
/// ─── THREAT MODEL NOTE ───────────────────────────────────────────
/// - The AUTHORITATIVE role is the Firebase Auth custom claim
///   `{role: '<name>'}`, signed into the JWT and settable ONLY server-side
///   (the genesis bootstrap script or the approval backend). AppUser.role
///   is a queryable Firestore MIRROR — never the security boundary.
/// - Role strings are referenced by Firestore security rules. Renaming
///   them requires a data migration AND a rules update, in lockstep.
/// - A signup flow can only ever produce `resident` or `public`. `admin`
///   is REQUESTED via the admin-registration flow but granted only by a
///   superadmin's approval (a server-side claim write). `superadmin` is
///   provisioned once, out-of-band, by the genesis bootstrap script.
///   `staff` is out-of-band provisioned. None of these elevated roles can
///   be self-granted from client code.
enum UserRole {
  superadmin,
  admin,
  staff,
  resident,
  public;

  String toFirestoreValue() => name;

  static UserRole fromFirestoreValue(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => throw ArgumentError('Unknown UserRole: "$value"'),
    );
  }
}
