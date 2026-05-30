import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'apply_for_resident_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Home for active PUBLIC users — and a browsing surface for pending
/// applicants who chose "Continue browsing as public" on the awaiting
/// screen. Self-contained shell: a bottom nav with Home / Profile /
/// Settings (no dead-ends; the home AppBar shows a back button only when
/// this screen was pushed, e.g. from the awaiting screen).
class PublicHomeScreen extends StatefulWidget {
  final AppUser user;

  const PublicHomeScreen({super.key, required this.user});

  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _PublicHomeTab(user: widget.user),
      ProfileScreen(user: widget.user),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.homeOutlined),
            selectedIcon: Icon(AppIcons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.profileOutlined),
            selectedIcon: Icon(AppIcons.profile),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.settingsOutlined),
            selectedIcon: Icon(AppIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _PublicHomeTab extends StatelessWidget {
  final AppUser user;

  const _PublicHomeTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasPendingApplication = user.requestedRole != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Welcome',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              user.name.isNotEmpty ? user.name : 'Guest',
              style: tt.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _InfoCard(
              icon: AppIcons.announcements,
              title: 'Public Announcements',
              body: 'Community-wide announcements will appear here.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _InfoCard(
              icon: AppIcons.communityBulletin,
              title: 'Community Info',
              body: 'Facilities, contacts, and general information for the '
                  'development.',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (hasPendingApplication)
              Card(
                color: cs.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(AppIcons.pending, color: cs.onSecondaryContainer),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Your resident application is under review.',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _ApplyCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ApplyForResidentScreen(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ApplyCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdBr,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                AppIcons.applyForResident,
                color: cs.onPrimaryContainer,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apply for Resident Access',
                      style: tt.titleMedium
                          ?.copyWith(color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Live here? Get verified for unit-based features.',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.arrowRight,
                  size: 16, color: cs.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
