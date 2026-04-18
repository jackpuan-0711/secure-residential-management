import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'models/app_user.dart';
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
/// It subscribes to AuthService.authStateChanges and decides which screen
/// to show based on the current auth state:
///   - Loading (initial snapshot)  → SplashScreen
///   - Signed out (user == null)   → LoginScreen
///   - Signed in + email verified  → HomeScreen
///   - Signed in + NOT verified    → EmailVerificationScreen
///
/// This widget is the ONLY place in the app that decides "where should
/// the user be?" — all screens are "dumb" and just react.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AppUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // ── State 1: Waiting for Firebase to report initial auth state ──
        // On app cold start, there's a brief moment before Firebase tells
        // us whether a session is cached. Show a splash during this.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final user = snapshot.data;

        // ── State 2: No user signed in → Login ──
        if (user == null) {
          return const LoginScreen();
        }

        // ── State 3: Signed in but email NOT verified → verification ──
        if (!user.emailVerified) {
          return const EmailVerificationScreen();
        }

        // ── State 4: Signed in AND verified → Home ──
        return HomeScreen(user: user);
      },
    );
  }
}

/// Shown briefly while Firebase reports initial auth state on cold start.
/// Kept in main.dart because it's tightly coupled to the routing logic —
/// no other screen uses it.
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