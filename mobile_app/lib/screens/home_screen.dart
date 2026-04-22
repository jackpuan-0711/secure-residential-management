import 'package:flutter/material.dart';
import '../models/auth_identity.dart';
import '../services/auth_service.dart';

/// Home screen — shown after successful authentication AND email verification.
///
/// ─── TRANSITIONAL WIDGET (Sprint 2, Step 1.5) ────────────────────
/// This screen currently takes an `AuthIdentity` (Firebase Auth data
/// only). It displays the Firebase Auth `displayName` and a
/// verification chip, serving as the "signed-in landing" so the app
/// compiles and the post-verification flow can be smoke-tested.
///
/// In Sprint 2, Step 6, this widget will be replaced with a role-aware
/// dashboard that takes an `AppUser` loaded from Firestore.
/// ──────────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  /// The current authenticated session''s Firebase Auth identity.
  final AuthIdentity identity;

  const HomeScreen({super.key, required this.identity});

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to return.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = identity.displayName?.isNotEmpty == true
        ? identity.displayName!
        : 'Resident';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Residential Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 48,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome, $displayName',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'You are signed in securely.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: displayName,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: identity.email,
                        trailing: identity.emailVerified
                            ? const Chip(
                                label: Text('Verified'),
                                avatar: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                              )
                            : const Chip(
                                label: Text('Unverified'),
                                avatar: Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.fingerprint,
                        label: 'User ID',
                        value: identity.uid,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.construction,
                        size: 40,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'More features coming soon',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Visitors • Maintenance • Announcements • EV Charger',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}