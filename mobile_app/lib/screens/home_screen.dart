import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final AppUser user;

  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _SliverHeader(user: user),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _AnnouncementCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _QuickActionsGrid(user: user),
                  const SizedBox(height: AppSpacing.xl),
                  const _UpcomingEventsSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverHeader extends StatelessWidget {
  final AppUser user;

  const _SliverHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      collapsedHeight: 80,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${user.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              user.unitNumber ?? 'Resident',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(AppIcons.notifications, color: Colors.white),
          onPressed: () {},
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(30),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.announcements,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Latest Announcement',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'System maintenance scheduled for this Sunday from 2:00 AM to 4:00 AM.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final AppUser user;

  const _QuickActionsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    final isResident = user.role == UserRole.resident;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          children: [
            if (isResident)
              const _ActionButton(
                icon: AppIcons.visitorPass,
                label: 'Visitor',
                color: Colors.orange,
              ),
            const _ActionButton(
              icon: AppIcons.maintenance,
              label: 'Fix it',
              color: Colors.blue,
            ),
            const _ActionButton(
              icon: AppIcons.communityBulletin,
              label: 'Bulletin',
              color: Colors.green,
            ),
            const _ActionButton(
              icon: AppIcons.securityAlert,
              label: 'SOS',
              color: Colors.red,
            ),
            const _ActionButton(
              icon: AppIcons.feedback,
              label: 'Feedback',
              color: Colors.purple,
            ),
            const _ActionButton(
              icon: AppIcons.settings,
              label: 'Settings',
              color: Colors.blueGrey,
            ),
            const _ActionButton(
              icon: AppIcons.profile,
              label: 'Profile',
              color: Colors.teal,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withAlpha(10),
            borderRadius: AppRadius.lgBr,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
              ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _UpcomingEventsSection extends StatelessWidget {
  const _UpcomingEventsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Events',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {},
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const _EventTile(
          title: 'Community Yoga',
          date: 'Oct 25, 2023 • 08:00 AM',
          location: 'Clubhouse Garden',
        ),
        const _EventTile(
          title: 'Residents Meeting',
          date: 'Oct 28, 2023 • 07:30 PM',
          location: 'Main Hall',
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final String title;
  final String date;
  final String location;

  const _EventTile({
    required this.title,
    required this.date,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: AppRadius.mdBr,
          ),
          child: Icon(
            AppIcons.calendar,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$date\n$location', style: const TextStyle(fontSize: 12)),
        isThreeLine: true,
      ),
    );
  }
}
