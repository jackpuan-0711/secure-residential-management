import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/announcement.dart';
import '../services/announcement_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AnnouncementRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: StreamBuilder<List<Announcement>>(
        stream: repo.watchAnnouncements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final announcements = snapshot.data;

          if (announcements == null || announcements.isEmpty) {
            return const Center(child: Text('No announcements at this time.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              return _AnnouncementCard(announcement: announcements[index]);
            },
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isCritical = announcement.priority == AnnouncementPriority.critical;
    final isWarning = announcement.priority == AnnouncementPriority.warning;

    Color priorityColor = cs.primary;
    IconData priorityIcon = AppIcons.info;

    if (isCritical) {
      priorityColor = cs.error;
      priorityIcon = AppIcons.error;
    } else if (isWarning) {
      priorityColor = Colors.orange; // Default warning color
      priorityIcon = AppIcons.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (announcement.pinned) ...[
                  Icon(Icons.push_pin, size: 16, color: cs.primary),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Icon(priorityIcon, size: 16, color: priorityColor),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: announcement.pinned ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              DateFormat.yMMMd().add_jm().format(announcement.postedAt),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(announcement.body, style: tt.bodyMedium),
          ],
        ),
      ),
    );
  }
}
