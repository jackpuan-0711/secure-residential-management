import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// SuperadminHomeScreen — landing for the genesis superadmin.
///
/// Placeholder shell. The admin-approval dashboard (list pending admin
/// requests → approve/reject via the server-side approval backend) lands
/// in a later phase. Routing here is driven by the {role:'superadmin'}
/// custom claim — see AuthGate in main.dart.
class SuperadminHomeScreen extends StatelessWidget {
  const SuperadminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Superadmin Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome, Superadmin!'),
            const SizedBox(height: 8),
            const Text(
              'Admin approval dashboard coming soon.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => AuthService().signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
