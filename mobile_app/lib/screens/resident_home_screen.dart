import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'announcements_screen.dart';
import 'ev_charging_screen.dart';
import 'maintenance_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'visitor_screen.dart';

/// Home for active, verified residents. The home tab is a compact management
/// dashboard with the common actions a resident expects in a commercial
/// residential app: visitors, maintenance, announcements, and EV charging.
class ResidentHomeScreen extends StatefulWidget {
  final AppUser user;

  const ResidentHomeScreen({super.key, required this.user});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _ResidentHomeTab(user: widget.user),
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

class _ResidentHomeTab extends StatelessWidget {
  final AppUser user;

  const _ResidentHomeTab({required this.user});

  static const _features = <_Feature>[
    _Feature(
      icon: AppIcons.visitorPass,
      label: 'Visitor Passes',
      body: 'Register guests and show gate QR codes.',
    ),
    _Feature(
      icon: AppIcons.maintenance,
      label: 'Maintenance',
      body: 'Submit defects and track service progress.',
    ),
    _Feature(
      icon: AppIcons.evCharging,
      label: 'EV Charging',
      body: 'Start, stop, and review charging sessions.',
    ),
    _Feature(
      icon: AppIcons.announcements,
      label: 'Announcements',
      body: 'Read notices from management.',
    ),
  ];

  void _open(BuildContext context, String title) {
    if (title == 'Announcements') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
    } else if (title == 'Maintenance') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => MaintenanceScreen(user: user)));
    } else if (title == 'Visitor Passes') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => VisitorScreen(user: user)));
    } else if (title == 'EV Charging') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => EvChargingScreen(user: user)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Welcome back',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              user.name.isNotEmpty ? user.name : 'Resident',
              style: tt.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _ResidentStatusCard(user: user),
            const SizedBox(height: AppSpacing.lg),
            Text('Quick actions', style: tt.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720 ? 4 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: columns == 4 ? 1.05 : 0.95,
                  children: [
                    for (final f in _features)
                      _FeatureCard(
                        feature: f,
                        onTap: () => _open(context, f.label),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Property services', style: tt.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const _ServiceSummary(
              icon: AppIcons.checkCircle,
              title: 'Resident access active',
              body:
                  'Your verified unit unlocks visitor, maintenance, and EV tools.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _ServiceSummary(
              icon: AppIcons.communityBulletin,
              title: 'Management updates',
              body:
                  'Building notices, facility updates, and urgent alerts appear in Announcements.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  final String body;

  const _Feature({required this.icon, required this.label, required this.body});
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final VoidCallback onTap;

  const _FeatureCard({required this.feature, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdBr,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(feature.icon, size: 32, color: cs.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(feature.label, style: tt.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Text(
                  feature.body,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResidentStatusCard extends StatelessWidget {
  final AppUser user;

  const _ResidentStatusCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: cs.primary,
              child: Icon(AppIcons.unit, color: cs.onPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit ${user.unitNumber ?? "-"}',
                    style: tt.titleLarge?.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Verified resident account',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.verified, color: cs.onPrimaryContainer),
          ],
        ),
      ),
    );
  }
}

class _ServiceSummary extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ServiceSummary({
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
        padding: const EdgeInsets.all(AppSpacing.md),
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
