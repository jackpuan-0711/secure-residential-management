import 'package:flutter/material.dart';

import '../models/auth_identity.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/visitor_admin_entry.dart';

/// Restricted operations home for gate staff.
///
/// Staff claims intentionally route here instead of an admin dashboard: gate
/// staff can validate visitor passes but cannot approve users or manage
/// property data.
class StaffHomeScreen extends StatelessWidget {
  final AuthIdentity identity;
  final AuthService? authService;

  const StaffHomeScreen({super.key, required this.identity, this.authService});

  @override
  Widget build(BuildContext context) {
    final auth = authService ?? AuthService();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Operations'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.signOut,
            icon: const Icon(AppIcons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 36,
                        color: cs.onPrimaryContainer,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Gate staff access', style: tt.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Scan each pass at arrival and check visitors out when '
                        'they leave. Every action is recorded against your account.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            VisitorAdminEntry(staffId: identity.uid),
          ],
        ),
      ),
    );
  }
}
