import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'announcements_screen.dart';
import 'apply_for_resident_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Home for active public users and pending applicants who continue browsing.
/// It exposes the parts of the residential portal that do not require a
/// verified unit, while making the resident/admin request sequence explicit.
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

  bool get _hasPendingRequest => user.status == UserStatus.pendingApproval;

  void _openResidentApplication(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ApplyForResidentScreen()));
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
              'Welcome',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              user.name.isNotEmpty ? user.name : 'User',
              style: tt.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_hasPendingRequest)
              _PendingRequestCard(user: user)
            else
              const _AccessCard(),
            const SizedBox(height: AppSpacing.lg),
            Text('Available services', style: tt.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _PortalCard(
              icon: AppIcons.announcements,
              title: 'Community announcements',
              body: 'Read building notices, facility updates, and alerts.',
              actionLabel: 'Open',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PortalCard(
              icon: AppIcons.applyForResident,
              title: 'Resident access',
              body: _hasPendingRequest
                  ? 'Your current access request is under review.'
                  : 'Apply with your unit number to unlock resident services.',
              actionLabel: _hasPendingRequest ? 'Pending' : 'Apply',
              onTap: _hasPendingRequest
                  ? null
                  : () => _openResidentApplication(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PortalCard(
              icon: AppIcons.visitorPass,
              title: 'Visitor and household services',
              body:
                  'Verified residents can register guests and issue gate QR passes.',
              actionLabel: 'Resident only',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard();

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
              backgroundColor: cs.primary,
              child: Icon(AppIcons.profile, color: cs.onPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Public portal access',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Apply for resident access when you are ready to verify a unit.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.78),
                    ),
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

class _PendingRequestCard extends StatelessWidget {
  final AppUser user;

  const _PendingRequestCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const title = 'Resident access under review';
    final body =
        'Management is reviewing your unit claim ${user.requestedUnit ?? ""}.';

    return Card(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(AppIcons.pending, color: cs.onSecondaryContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer.withValues(alpha: 0.8),
                    ),
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

class _PortalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onTap;

  const _PortalCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdBr,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? cs.primary : cs.onSurfaceVariant,
                size: 32,
              ),
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
              const SizedBox(width: AppSpacing.sm),
              Text(
                actionLabel,
                style: tt.labelMedium?.copyWith(
                  color: enabled ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
