import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/pending_residents_list.dart';

/// AdminHomeScreen — admin landing.
///
/// Routed to by AuthGate when the signed token carries
/// `{role: 'admin'}`. Hosts the resident-approval workflow via
/// [PendingResidentsList]; admin self-registration and richer admin
/// surfaces are deferred (require the Flask grant endpoint).
class AdminHomeScreen extends StatelessWidget {
  final AuthService? authService;

  const AdminHomeScreen({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    final auth = authService ?? AuthService();
    final email = auth.currentUser?.email ?? '';
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          email.isEmpty
              ? 'Admin Dashboard'
              : 'Admin Dashboard — $email',
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
            ],
          ),
        ),
      ),
    );
  }
}
