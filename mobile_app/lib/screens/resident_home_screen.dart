import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'coming_soon_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Home for active, verified RESIDENTS. Self-contained shell: a bottom
/// nav with Home / Profile / Settings. The home tab shows the resident's
/// unit and four feature tiles; each is a placeholder that pushes a
/// "Coming soon" screen for now (Phase E builds Maintenance).
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
    _Feature(icon: AppIcons.maintenance, label: 'Maintenance Requests'),
    _Feature(icon: AppIcons.visitorPass, label: 'Visitor Pre-registration'),
    _Feature(icon: AppIcons.announcements, label: 'Announcements'),
    _Feature(icon: AppIcons.evCharging, label: 'EV Charging'),
  ];

  void _open(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ComingSoonScreen(title: title)),
    );
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
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(AppIcons.unit, size: 16, color: cs.primary),
                const SizedBox(width: AppSpacing.xs),
                Text('Unit ${user.unitNumber ?? "—"}', style: tt.bodyMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.3,
              children: [
                for (final f in _features)
                  _FeatureCard(
                    feature: f,
                    onTap: () => _open(context, f.label),
                  ),
              ],
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

  const _Feature({required this.icon, required this.label});
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(feature.icon, size: 32, color: cs.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                feature.label,
                textAlign: TextAlign.center,
                style: tt.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
