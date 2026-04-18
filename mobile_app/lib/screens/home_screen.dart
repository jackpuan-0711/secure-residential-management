import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Home screen — shown after successful authentication AND email verification.
///
/// For Day 2, this is a minimal "you're logged in" landing screen that:
///   - Displays the user's profile info (name, email, verification status)
///   - Provides a Logout button
///
/// In Sprint 2, this will be replaced with a role-aware dashboard:
///   - Resident → sees Visitors, Maintenance, Announcements, EV Charger
///   - Admin → sees User Management, Announcements, Reports
///   - Staff → sees Maintenance Queue, Visitor Logs, IoT Monitoring
///
/// The UI stays this thin on purpose — it makes the routing logic in
/// main.dart (Step 10) easy to reason about.
class HomeScreen extends StatelessWidget {
  /// The authenticated user, passed in from the router in main.dart.
  /// Passing it in (rather than re-fetching from AuthService) makes this
  /// widget easy to test in isolation — you just construct it with a
  /// mock AppUser.
  final AppUser user;

  const HomeScreen({super.key, required this.user});

  Future<void> _handleLogout(BuildContext context) async {
    // Confirm before logout — prevents accidental taps.
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
      // authStateChanges stream in main.dart will route back to Login.
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName?.isNotEmpty == true
        ? user.displayName!
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
              // ─── Welcome header ─────────────────────────────
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
                    color:
                        Theme.of(context).colorScheme.onPrimaryContainer,
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

              // ─── Profile card ───────────────────────────────
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
                        value: user.email,
                        trailing: user.emailVerified
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
                        value: user.uid,
                        // Debug-only — will be removed in Sprint 2.
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Placeholder for future modules ─────────────
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

/// Private helper widget for a labeled info row on the profile card.
/// Not exported — internal to this file only (underscore prefix).
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