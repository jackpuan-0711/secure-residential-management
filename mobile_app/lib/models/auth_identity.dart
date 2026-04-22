/// Immutable wrapper around the subset of Firebase Auth's User that the
/// rest of the app needs to know about.
///
/// ─── WHY THIS EXISTS (Sprint 2, Step 1.5) ─────────────────────────
/// Sprint 1 had a single `AppUser` class that doubled as both the auth
/// identity wrapper AND the domain user. Sprint 2 Step 1 redefined
/// `AppUser` as the Firestore domain model (role, status, unit, audit
/// fields, ...) to match the thesis ERD (Section 4.4, Figure 4.14).
///
/// That left a gap: AuthService still needs a lightweight "what does
/// Firebase Auth know about the current session" type that does not
/// require a Firestore round-trip. AuthIdentity fills that gap.
///
/// ─── ARCHITECTURAL BOUNDARY ──────────────────────────────────────
/// AuthIdentity is the ONLY authenticated-session type that
/// AuthService returns. Firebase's `User` type never escapes
/// AuthService. This preserves the "no Firebase types leak out"
/// invariant documented in auth_service.dart.
///
/// AuthIdentity is NOT a substitute for AppUser:
///   - AuthIdentity answers: "who is logged in right now, and is
///     their email verified?"
///   - AppUser answers: "what is this person's role, status, unit,
///     approval history, profile data, ...?"
///
/// AuthGate (main.dart) uses AuthIdentity alone to decide the
/// pre-profile states (splash, login, verify email). Once the user
/// is verified, Step 6 will introduce a second loader that fetches
/// the matching AppUser from UserRepository for role-based routing.
/// ──────────────────────────────────────────────────────────────────
class AuthIdentity {
  /// Firebase's unique user ID. Stable for the lifetime of the account.
  /// This is ALSO the document ID under /users/{uid} — it links
  /// AuthIdentity to the AppUser record.
  final String uid;

  /// User's email address. Non-null because the app uses email/password
  /// signup exclusively.
  final String email;

  /// Display name set via FirebaseAuth.User.updateDisplayName during
  /// signup. Can be null if a future social-login provider doesn't
  /// supply one.
  final String? displayName;

  /// Whether the email verification link has been clicked. Gates access
  /// to every post-auth screen except EmailVerificationScreen itself.
  final bool emailVerified;

  const AuthIdentity({
    required this.uid,
    required this.email,
    required this.emailVerified,
    this.displayName,
  });

  /// Debugging convenience. Never log this in production — PII.
  @override
  String toString() =>
      'AuthIdentity(uid: $uid, email: $email, verified: $emailVerified)';
}