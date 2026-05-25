import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_identity.dart';

/// Central authentication service for the Residential Management app.
///
/// This class is the SINGLE PLACE in the app that talks to FirebaseAuth.
/// All UI screens call methods here — they never import firebase_auth directly.
///
/// Responsibilities:
///   - Sign up new users with email/password
///   - Sign in existing users
///   - Sign out the current user
///   - Stream authentication state changes (for auto-routing)
///   - Send email verification
///   - Translate cryptic Firebase error codes into user-friendly messages
///
/// Design decisions:
///   - Uses `instance` of FirebaseAuth (singleton). For unit testing,
///     inject a mock via the `AuthService.withInstance()` constructor
///     (wired up in Step 8).
///   - Returns our own `AuthIdentity` model, never Firebase''s `User` —
///     this enforces the architectural boundary described in
///     models/auth_identity.dart. AuthIdentity is the auth-session type.
///     It is DISTINCT from AppUser, which is the Firestore domain model
///     loaded via UserRepository.
///   - Throws `AuthException` (defined below) for ALL errors. Callers
///     only need to catch one exception type.
class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService() : _firebaseAuth = FirebaseAuth.instance;

  AuthService.withInstance(this._firebaseAuth);

  Stream<AuthIdentity?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_mapFirebaseUser);
  }

  AuthIdentity? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  AuthIdentity? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AuthIdentity(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      emailVerified: user.emailVerified,
    );
  }

  /// Creates a new account with email + password, sets the display name,
  /// and sends the email verification link.
  ///
  /// ─── ARCHITECTURAL NOTE (Sprint 2, Step 4a) ────────────────────
  /// This method deliberately does NOT create a Firestore
  /// /users/{uid} profile document. Profile creation is a separate,
  /// post-verification step (see CompleteProfileScreen, Step 4b).
  ///
  /// Reasoning:
  /// 1. Separation of concerns. Firebase Auth owns identity;
  ///    Firestore owns profile data. The two systems share no
  ///    distributed transaction primitive.
  /// 2. Security boundary. Email verification sits between signup
  ///    and profile creation. Firestore rules enforce
  ///    request.auth.token.email_verified == true on profile writes.
  /// 3. Role flexibility. PSM-2 extends the PSM-1 RBAC model
  ///    (Admin, Staff, Resident, Visitor) with a fifth
  ///    authenticated tier: `public`. A `public` user is a
  ///    registered Firebase account with app access but no
  ///    unit-level authorisation — distinct from the PSM-1
  ///    Visitor entity, which is an unauthenticated QR-code
  ///    guest pre-registered by a resident (UC003, Figure 4.14).
  ///    Deferring Firestore profile creation to
  ///    CompleteProfileScreen lets the user declare whether they
  ///    are continuing as a public app user or applying as a
  ///    resident (pending admin approval), rather than forcing
  ///    every signup through a resident-only form.
  /// ────────────────────────────────────────────────────────────────
  Future<AuthIdentity> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw AuthException('Account creation failed unexpectedly.');
      }

      await user.updateDisplayName(displayName.trim());
      await user.sendEmailVerification();
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;

      return _mapFirebaseUser(refreshedUser)!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeFirebaseError(e));
    } catch (e) {
      throw AuthException('Unexpected error: $e');
    }
  }

  Future<AuthIdentity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw AuthException('Sign in failed unexpectedly.');
      }
      return _mapFirebaseUser(user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeFirebaseError(e));
    } catch (e) {
      throw AuthException('Unexpected error: $e');
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> resendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException('No user signed in.');
    }
    if (user.emailVerified) {
      throw AuthException('Email is already verified.');
    }
    await user.sendEmailVerification();
  }

  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  /// Sends a password-reset email to [email] (out-of-band reset flow).
  ///
  /// Used both from the login screen ("Forgot password?", when the user is
  /// locked out) and from Privacy & Security (signed-in convenience option).
  ///
  /// SECURITY NOTE: Firebase intentionally does NOT reveal whether the
  /// address is registered — the call succeeds either way. We surface a
  /// neutral "email sent" message so this screen cannot be used as an
  /// account-enumeration oracle.
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeFirebaseError(e));
    } catch (e) {
      throw AuthException('Unexpected error: $e');
    }
  }

  /// Changes the signed-in user's password after re-verifying their
  /// current one.
  ///
  /// Reauthentication is required because changing a password is a
  /// security-sensitive operation: Firebase rejects it with
  /// `requires-recent-login` if the session is stale, and verifying the
  /// current password ensures it is the account owner — not someone who
  /// merely picked up an unlocked device — performing the change.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('No user signed in.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeFirebaseError(e));
    } catch (e) {
      throw AuthException('Unexpected error: $e');
    }
  }

  String _humanizeFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'requires-recent-login':
        return 'For your security, please sign out and sign in again before '
            'changing your password.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Contact support.';
      default:
        return 'Authentication failed (${e.code}).';
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}