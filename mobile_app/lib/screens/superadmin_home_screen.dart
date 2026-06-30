import 'package:flutter/material.dart';

import '../models/auth_identity.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_management_section.dart';
import '../widgets/announcements_feed.dart';
import '../widgets/ev_admin_entry.dart';
import '../widgets/maintenance_admin_entry.dart';
import '../widgets/pending_residents_section.dart';
import '../widgets/post_announcement_entry.dart';
import '../widgets/visitor_admin_entry.dart';

class SuperadminHomeScreen extends StatefulWidget {
  final AuthIdentity identity;
  final AuthService? authService;

  const SuperadminHomeScreen({
    super.key,
    required this.identity,
    this.authService,
  });

  @override
  State<SuperadminHomeScreen> createState() => _SuperadminHomeScreenState();
}

class _SuperadminHomeScreenState extends State<SuperadminHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService ?? AuthService();
    final email = auth.currentUser?.email ?? widget.identity.email;

    final tabs = [
      _OverviewTab(
        email: email,
        onOpenResidents: () => setState(() => _index = 1),
        onOpenAdmins: () => setState(() => _index = 2),
        onOpenOperations: () => setState(() => _index = 3),
        onOpenAnnouncements: () => setState(() => _index = 4),
      ),
      const _ResidentsTab(),
      const _AdminsTab(),
      _OperationsTab(identity: widget.identity),
      _AnnouncementsTab(identity: widget.identity, role: UserRole.superadmin),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Superadmin Console'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => auth.signOut(),
            icon: Icon(AppIcons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.adminDashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.pendingApplications),
            label: 'Residents',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.accountManagement),
            label: 'Admins',
          ),
          NavigationDestination(icon: Icon(AppIcons.maintenance), label: 'Ops'),
          NavigationDestination(
            icon: Icon(AppIcons.announcementsOutlined),
            selectedIcon: Icon(AppIcons.announcements),
            label: 'Notices',
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final String email;
  final VoidCallback onOpenResidents;
  final VoidCallback onOpenAdmins;
  final VoidCallback onOpenOperations;
  final VoidCallback onOpenAnnouncements;

  const _OverviewTab({
    required this.email,
    required this.onOpenResidents,
    required this.onOpenAdmins,
    required this.onOpenOperations,
    required this.onOpenAnnouncements,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          color: cs.tertiary,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.verified, color: cs.onTertiary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'System administration',
                  style: tt.headlineSmall?.copyWith(color: cs.onTertiary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  email.isEmpty ? 'Signed in as superadmin' : email,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onTertiary.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionTile(
          icon: AppIcons.pendingApplications,
          title: 'Resident approvals',
          body: 'Approve or reject resident unit applications.',
          onTap: onOpenResidents,
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionTile(
          icon: AppIcons.accountManagement,
          title: 'Administrators',
          body: 'Add or remove management administrators.',
          onTap: onOpenAdmins,
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionTile(
          icon: AppIcons.maintenance,
          title: 'Operations',
          body: 'Open maintenance and EV station management.',
          onTap: onOpenOperations,
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionTile(
          icon: AppIcons.announcements,
          title: 'Building notices',
          body: 'Post and review resident announcements.',
          onTap: onOpenAnnouncements,
        ),
      ],
    );
  }
}

class _ResidentsTab extends StatelessWidget {
  const _ResidentsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: const [PendingResidentsSection()],
    );
  }
}

class _AdminsTab extends StatelessWidget {
  const _AdminsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [AdminManagementSection()],
    );
  }
}

class _OperationsTab extends StatelessWidget {
  final AuthIdentity identity;

  const _OperationsTab({required this.identity});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        MaintenanceAdminEntry(handledByUid: identity.uid),
        const SizedBox(height: AppSpacing.md),
        VisitorAdminEntry(staffId: identity.uid),
        const SizedBox(height: AppSpacing.md),
        const EvAdminEntry(),
      ],
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  final AuthIdentity identity;
  final UserRole role;

  const _AnnouncementsTab({required this.identity, required this.role});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        PostAnnouncementEntry(postedBy: identity.uid, postedByRole: role),
        const SizedBox(height: AppSpacing.md),
        AnnouncementsFeed(editorUid: identity.uid, editorRole: role),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: AppRadius.xlBr,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: 32, color: cs.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tt.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      body,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.arrowRight, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
