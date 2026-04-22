import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'models/app_user.dart';
import 'models/auth_identity.dart';
import 'services/auth_service.dart';
import 'services/user_repository.dart';
import 'screens/login_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/awaiting_approval_screen.dart';

/// Entry point of the Residential Management mobile app.
///
/// 1. Ensures Flutter engine binding is initialized (needed for platform
///    channels that Firebase uses internally)
/// 2. Initializes Firebase with platform-specific options
/// 3. Boots the root app widget
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ResidentialApp());
}

/// Root widget — sets up Material theme and delegates routing to AuthGate.
class ResidentialApp extends StatelessWidget {
  const ResidentialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Residential Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// AuthGate is the central routing widget.
///
/// ─── Router state machine (Sprint 2, Step 6) ────────────────────
/// The router listens to TWO streams:
///   1. Firebase Auth state (via AuthService.authStateChanges)
///   2. Firestore /users/{uid} doc (via UserRepository.watchUserProfile)
///
/// The second stream is only subscribed when (1) reports a verified user.
/// This nested-StreamBuilder pattern guarantees:
///   - Logged-out users never trigger a Firestore read
///   - Firestore listener is torn down automatically on sign-out
///
/// ─── State routing table ────────────────────────────────────────
///   auth=null                                → LoginScreen
///   auth=user, verified=false                → EmailVerificationScreen
///   auth=user, verified=true, profile=null   → CompleteProfileScreen
///   profile.status=pendingApproval           → AwaitingApprovalScreen
///   profile.status=suspended                 → SuspendedScreen (placeholder)
///   profile.status=active, role=resident     → HomeScreen (AppUser)
///   profile.status=active, role=public       → HomeScreen (AppUser)
///   profile.status=active, role=admin        → HomeScreen (AppUser)
///   profile.status=active, role=staff        → HomeScreen (AppUser)
///
/// Role-specific dashboards (ResidentHome, AdminHome, etc.) are Step 7.
/// For now all active users land on the transitional HomeScreen, which
/// accepts an AppUser and displays role/status in the UI for verification.
/// ────────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userRepository = UserRepository();

    return StreamBuilder<AuthIdentity?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        // ── Waiting for initial auth state ──
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final identity = authSnapshot.data;

        // ── No user signed in ──
        if (identity == null) {
          return const LoginScreen();
        }

        // ── Signed in but email not verified ──
        if (!identity.emailVerified) {
          return const EmailVerificationScreen();
        }

        // ── Verified — subscribe to Firestore profile doc ──
        return StreamBuilder<AppUser?>(
          stream: userRepository.watchUserProfile(identity.uid),
          builder: (context, profileSnapshot) {
            // Waiting for first Firestore snapshot
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            final profile = profileSnapshot.data;

            // ── Verified but no profile doc → complete profile ──
            if (profile == null) {
              return const CompleteProfileScreen();
            }

            // ── Profile exists — route by status and role ──
            switch (profile.status) {
              case UserStatus.pendingApproval:
                return const AwaitingApprovalScreen();
              case UserStatus.suspended:
                return const _SuspendedPlaceholder();
              case UserStatus.active:
                // All active roles land on HomeScreen for now.
                // Step 7 will split to ResidentHome / AdminHome / PublicHome.
                return HomeScreen(user: profile);
            }
          },
        );
      },
    );
  }
}

/// Temporary suspended-account screen. Step 7 will replace with a
/// dedicated SuspendedScreen under lib/screens/.
class _SuspendedPlaceholder extends StatelessWidget {
  const _SuspendedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Suspended'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 80,
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Your account has been suspended',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please contact the management office if you believe '
                'this is a mistake.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => AuthService().signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown briefly while Firebase reports initial auth state on cold start.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Residential Hub',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
