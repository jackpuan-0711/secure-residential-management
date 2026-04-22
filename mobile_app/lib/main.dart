import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'models/auth_identity.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/home_screen.dart';

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
/// It subscribes to AuthService.authStateChanges (emitting AuthIdentity?)
/// and decides which screen to show based on the current auth state.
///
/// ─── Current routing (post Sprint 2, Step 1.5) ──────────────────────
///   - Loading (initial snapshot)     → SplashScreen
///   - Signed out (identity == null)  → LoginScreen
///   - Signed in + email NOT verified → EmailVerificationScreen
///   - Signed in + verified           → HomeScreen (transitional)
///
/// ─── Future routing (Sprint 2, Steps 4b–7) ──────────────────────────
/// Once CompleteProfileScreen and role-based dashboards land, the
/// verified branch will split into six states driven by the user's
/// Firestore /users/{uid} document:
///   - No profile doc                  → CompleteProfileScreen
///   - status: pending_approval        → AwaitingApprovalScreen
///   - status: active, role: resident  → ResidentHome
///   - status: active, role: public    → PublicHome
///   - status: active, role: admin     → AdminHome
///   - status: suspended               → SuspendedScreen
///
/// This widget is the ONLY place in the app that decides "where should
/// the user be?" — all screens are "dumb" and just react.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AuthIdentity?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // ── State 1: Waiting for Firebase to report initial auth state ──
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final identity = snapshot.data;

        // ── State 2: No user signed in → Login ──
        if (identity == null) {
          return const LoginScreen();
        }

        // ── State 3: Signed in but email NOT verified → verification ──
        if (!identity.emailVerified) {
          return const EmailVerificationScreen();
        }

        // ── State 4: Signed in AND verified → Home (transitional) ──
        // Step 6 replaces this branch with a Firestore-backed loader
        // that fetches the AppUser profile and routes based on
        // role + status.
        return HomeScreen(identity: identity);
      },
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