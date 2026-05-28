import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/pending_residents_list.dart';

/// SuperadminHomeScreen — landing for the genesis superadmin.
///
/// Routed to by AuthGate when the signed token carries
/// `{role: 'superadmin'}`. Hosts the same resident-approval queue as
/// [AdminHomeScreen] plus a placeholder for the admin-approval queue —
/// admin self-registration + grant flow is a deferred enhancement that
/// requires the Flask grant endpoint.
class SuperadminHomeScreen extends StatelessWidget {
  final AuthService? authService;

  const SuperadminHomeScreen({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    final auth = authService ?? AuthService();
    final email = auth.currentUser?.email ?? '';
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          email.isEmpty
              ? 'Superadmin Dashboard'
              : 'Superadmin Dashboard — $email',
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => auth.signOut(),
            icon: Icon(AppIcons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text('Pending Residents', style: tt.titleMedium),
              ),
              PendingResidentsList(authService: auth),

              const SizedBox(height: AppSpacing.lg),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child:
                    Text('Pending Admin Requests', style: tt.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  'No pending admin requests. Admin self-registration is '
                  'a deferred enhancement (requires Flask grant endpoint).',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
