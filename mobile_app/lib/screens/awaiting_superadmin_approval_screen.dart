/// AwaitingSuperadminApprovalScreen — admin module.
///
/// Gated landing for accounts that applied through the admin-registration
/// flow and are awaiting a superadmin's decision. The user has:
///   - A verified Firebase Auth account (no admin role claim yet)
///   - A Firestore /users/{uid} doc with requestedRole=admin,
///     status=pendingApproval
///
/// Transition out happens when a superadmin approves (grants the
/// {role:'admin'} claim, status → active) or rejects. Because the granted
/// role lives in the signed token, the user must refresh it — sign out and
/// back in — to land on the admin home. AuthGate then re-routes
/// automatically once the new claim is present.
///
/// Intentionally minimal: an unapproved admin applicant has no admin
/// privileges; callable functions and Firestore rules enforce that boundary.
library;

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AwaitingSuperadminApprovalScreen extends StatelessWidget {
  const AwaitingSuperadminApprovalScreen({super.key});

  Future<void> _refreshAccess(BuildContext context) async {
    try {
      await AuthService().refreshCurrentUserClaims();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Access refreshed.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not refresh access: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Access Under Review'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(AppIcons.pending, size: 72, color: cs.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Waiting for superadmin approval',
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'A superadmin will review your request for an '
                      'administrator account. Once approved, sign out and '
                      'back in to refresh your access — you will then land '
                      'on the admin dashboard.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: () => _refreshAccess(context),
                      icon: Icon(AppIcons.refresh),
                      label: const Text('Refresh access'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () => AuthService().signOut(),
                      icon: Icon(AppIcons.logout),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
