/// Represents an authenticated user in our app's domain.
///
/// This is intentionally DECOUPLED from Firebase's `User` class. By wrapping
/// Firebase's user in our own class, our UI never imports firebase_auth
/// directly — it only imports AppUser. If we ever swap auth providers,
/// only AuthService needs to change, not every screen.
///
/// This is also where we'll later add fields that Firebase Auth doesn't
/// natively store, such as role ('resident' | 'admin' | 'staff' | 'visitor')
/// which lives in Firestore. For Day 2, we keep it minimal — just the
/// authentication identity. Profile fields get layered in during Sprint 2.
class AppUser {
  /// Firebase's unique user ID (UID). Stable for the lifetime of the account.
  /// We use this as the primary key in Firestore /users/{uid} documents.
  final String uid;

  /// User's email address. Guaranteed non-null because we require
  /// email/password signup in this project.
  final String email;

  /// Display name (e.g., "Jack Puan"). May be null immediately after signup
  /// before the user completes their profile. We enforce it in the signup
  /// flow by calling updateDisplayName() right after account creation.
  final String? displayName;

  /// Whether the user has verified their email via the verification link
  /// that Firebase sends on signup. Critical for MFA — users cannot enroll
  /// in MFA until their email is verified. Also used to gate access to
  /// sensitive features.
  final bool emailVerified;

  const AppUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    this.displayName,
  });

  /// Debugging convenience. Never log this in production — contains PII.
  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, verified: $emailVerified)';
}