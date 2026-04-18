import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

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
///   - Uses `instance` of FirebaseAuth (singleton). For unit testing, we'll
///     inject a mock in a later sprint using an optional constructor param.
///   - Returns our own `AppUser` model, never Firebase's `User` — this
///     enforces the architectural boundary described in models/app_user.dart.
///   - Throws `AuthException` (defined below) for ALL errors. Callers only
///     need to catch one exception type.
class AuthService {
  final FirebaseAuth _firebaseAuth;

  /// Default constructor uses the global FirebaseAuth instance.
  /// Overloaded constructor `AuthService.withInstance()` lets us inject
  /// a mock for testing (we'll use this in Sprint 2).
  AuthService() : _firebaseAuth = FirebaseAuth.instance;

  AuthService.withInstance(this._firebaseAuth);

  // ===========================================================
  // STATE OBSERVATION
  // ===========================================================

  /// A stream of authentication state changes.
  ///
  /// Emits:
  ///   - `AppUser` when a user signs in or the app restarts with a cached session
  ///   - `null` when no user is signed in (signed out, or never signed in)
  ///
  /// Listen to this in the app's root widget to auto-route between
  /// Login screen and Home screen. We'll use it in Step 10.
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_mapFirebaseUser);
  }

  /// Current user synchronously (returns null if not signed in).
  /// Useful for one-off checks; prefer `authStateChanges` for reactive UI.
  AppUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  /// Private helper: converts Firebase's User to our AppUser.
  /// The architectural boundary is enforced here — no Firebase types leak out.
  AppUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      emailVerified: user.emailVerified,
    );
  }

  // ===========================================================
  // SIGNUP
  // ===========================================================

  /// Creates a new account with email + password, sets the display name,
  /// and sends the email verification link.
  ///
  /// Throws [AuthException] on failure (invalid email, weak password,
  /// email already in use, network error, etc.).
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Step 1: create the Firebase Auth account.
      // Firebase enforces password minimum 6 chars by default.
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw AuthException('Account creation failed unexpectedly.');
      }

      // Step 2: attach the display name to the Firebase user profile.
      // updateDisplayName is on the User object, not FirebaseAuth itself.
      await user.updateDisplayName(displayName.trim());

      // Step 3: send verification email. Required before the user can
      // enroll in MFA (Firebase enforces this).
      await user.sendEmailVerification();

      // Step 4: reload to pick up the displayName change in the cached user.
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;

      return _mapFirebaseUser(refreshedUser)!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeFirebaseError(e));
    } catch (e) {
      throw AuthException('Unexpected error: $e');
    }
  }

  // ===========================================================
  // SIGN IN
  // ===========================================================

  /// Signs in an existing user with email + password.
  /// Throws [AuthException] on failure.
  Future<AppUser> signIn({
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

  // ===========================================================
  // SIGN OUT
  // ===========================================================

  /// Signs out the current user. Clears cached auth state.
  /// authStateChanges stream will emit null after this completes.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // ===========================================================
  // EMAIL VERIFICATION
  // ===========================================================

  /// Re-sends the email verification link if the user requests it
  /// (e.g., "didn't receive the email" flow on the verification screen).
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

  /// Forces a reload of the user's profile from Firebase servers.
  /// Call this after the user clicks the verification link to pick up
  /// the updated emailVerified=true status.
  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  // ===========================================================
  // ERROR TRANSLATION
  // ===========================================================

  /// Converts Firebase's machine-readable error codes into messages
  /// we can safely show to end-users without leaking internal details.
  ///
  /// Full list: https://firebase.google.com/docs/auth/admin/errors
  String _humanizeFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        // With email enumeration protection ON (which we enabled),
        // Firebase returns 'invalid-credential' for both wrong email
        // and wrong password — we keep the message generic on purpose.
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Contact support.';
      default:
        // Fallback: show the code for debugging, but not the internal message.
        return 'Authentication failed (${e.code}).';
    }
  }
}

/// Custom exception thrown by AuthService for ALL auth failures.
/// Screens only need to `catch (AuthException)` — no Firebase types leak out.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}