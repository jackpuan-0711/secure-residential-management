import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'l10n/app_localizations.dart';
import 'models/app_user.dart';
import 'models/auth_identity.dart';
import 'services/app_settings.dart';
import 'services/auth_service.dart';
import 'services/user_repository.dart';
import 'screens/login_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/awaiting_approval_screen.dart';
import 'screens/awaiting_superadmin_approval_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/superadmin_home_screen.dart';
import 'screens/public_home_screen.dart';
import 'screens/resident_home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load saved preferences (language, notification toggles) before the
  // first frame so the UI opens in the user's chosen language.
  final settings = await AppSettings.load();

  runApp(ResidentialApp(settings: settings));
}

class ResidentialApp extends StatelessWidget {
  final AppSettings settings;

  const ResidentialApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      // Rebuild MaterialApp whenever a preference changes so a language
      // switch applies app-wide and immediately, with no restart.
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: settings.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userRepository = UserRepository();

    return StreamBuilder<AuthIdentity?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final identity = authSnapshot.data;

        if (identity == null) {
          return const LoginScreen();
        }

        if (!identity.emailVerified) {
          return const EmailVerificationScreen();
        }

        // ─── PRIVILEGED ROLES ARE CLAIM-DRIVEN ──────────────────────────
        // The {role} custom claim is the authorization boundary: signed
        // into the JWT, settable only server-side. Route superadmin and
        // admin straight from the claim — never from the Firestore profile
        // — so a tampered users/{uid}.role can't reach an admin surface.
        // Server-side checks (Firestore rules + approval backend) still
        // gate every privileged action; this is routing only.
        if (identity.role == UserRole.superadmin) {
          return const SuperadminHomeScreen();
        }
        if (identity.role == UserRole.admin) {
          return const AdminHomeScreen();
        }

        // ─── UNPRIVILEGED BUCKET (resident / public / no claim) ─────────
        // Resident verification and pending/suspended workflow live in
        // Firestore, so consult the profile for these non-escalating
        // routes. Residents gain a {role:'resident'} claim only once the
        // approval backend lands in a later phase; until then they route
        // here by profile, which is safe — no admin surface is exposed.
        return StreamBuilder<AppUser?>(
          stream: userRepository.watchUserProfile(identity.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            final profile = profileSnapshot.data;

            if (profile == null) {
              return const CompleteProfileScreen();
            }

            if (profile.status == UserStatus.suspended) {
              return const _SuspendedPlaceholder();
            }

            // Admin applicant awaiting a superadmin's decision (Phase B).
            if (profile.requestedRole == UserRole.admin &&
                profile.status == UserStatus.pendingApproval) {
              return const AwaitingSuperadminApprovalScreen();
            }

            // Any other pending applicant — a resident signup OR a public
            // user who applied to upgrade — waits on the admin queue.
            if (profile.status == UserStatus.pendingApproval) {
              return const AwaitingApprovalScreen();
            }

            // Active, verified resident.
            if (profile.role == UserRole.resident) {
              return ResidentHomeScreen(user: profile);
            }

            // Everyone else active (public, and any non-routed tier)
            // lands on the public home.
            return PublicHomeScreen(user: profile);
          },
        );
      },
    );
  }
}

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
