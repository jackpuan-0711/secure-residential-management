import 'package:flutter/material.dart';
import '../models/announcement.dart';
import '../services/announcement_repository.dart';
import '../screens/post_announcement_screen.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Read side of the announcements module: a live, ordered feed.
///
/// Streams [AnnouncementRepository.watchAnnouncements] (pinned desc, then
/// postedAt desc — backed by the composite index) and renders each item with
/// its priority colour + icon, a pinned indicator, a body snippet, and a
/// relative timestamp. Loading, empty, and error states are all handled so the
/// section is never a blank gap.
///
/// Designed to nest inside a scrolling parent (the privileged home's
/// SingleChildScrollView): it lays its items out as a non-scrolling Column.
class AnnouncementsFeed extends StatefulWidget {
  /// Injectable for tests; defaults to a live [AnnouncementRepository].
  final AnnouncementRepository? repository;
  final String? editorUid;
  final UserRole? editorRole;

  const AnnouncementsFeed({
    super.key,
    this.repository,
    this.editorUid,
    this.editorRole,
  });

  @override
  State<AnnouncementsFeed> createState() => _AnnouncementsFeedState();
}

class _AnnouncementsFeedState extends State<AnnouncementsFeed> {
  late final AnnouncementRepository _repo;
  late final Stream<List<Announcement>> _stream;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AnnouncementRepository();
    // Cache the stream so parent rebuilds don't re-subscribe.
    _stream = _repo.watchAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text('Announcements', style: tt.titleMedium),
        ),
        StreamBuilder<List<Announcement>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _FeedLoading();
            }
            if (snapshot.hasError) {
              return _FeedError(error: snapshot.error);
            }
            final items = snapshot.data ?? const <Announcement>[];
            if (items.isEmpty) {
              return const _FeedEmpty();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _AnnouncementCard(
                      announcement: items[i],
                      onEdit:
                          widget.editorUid == null || widget.editorRole == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PostAnnouncementScreen(
                                  postedBy: widget.editorUid!,
                                  postedByRole: widget.editorRole!,
                                  announcement: items[i],
                                  repository: _repo,
                                ),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback? onEdit;

  const _AnnouncementCard({required this.announcement, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = _priorityVisual(announcement.priority, cs);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(announcement.title, style: tt.titleSmall),
                      ),
                      if (announcement.pinned) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          AppIcons.pinned,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                      if (onEdit != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          tooltip: 'Edit announcement',
                          visualDensity: VisualDensity.compact,
                          onPressed: onEdit,
                          icon: const Icon(AppIcons.edit, size: 18),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    announcement.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${_priorityLabel(announcement.priority)} · '
                    '${_roleLabel(announcement.postedByRole)} · '
                    '${_relativeTime(announcement.postedAt)}'
                    '${announcement.editedAt == null ? '' : ' · Edited ${_relativeTime(announcement.editedAt!)}'}',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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

/// Priority → (icon, colour). info is neutral, warning amber, critical red.
(IconData, Color) _priorityVisual(AnnouncementPriority p, ColorScheme cs) {
  switch (p) {
    case AnnouncementPriority.info:
      return (AppIcons.info, cs.onSurfaceVariant);
    case AnnouncementPriority.warning:
      // Amber is a semantic status colour with no Material 3 ColorScheme slot,
      // so we use the project's WCAG-checked warning token here (the one
      // deliberate exception to "colours come from Theme.colorScheme").
      return (AppIcons.warning, AppColors.warning);
    case AnnouncementPriority.critical:
      return (AppIcons.error, cs.error);
  }
}

String _priorityLabel(AnnouncementPriority p) {
  switch (p) {
    case AnnouncementPriority.info:
      return 'Info';
    case AnnouncementPriority.warning:
      return 'Warning';
    case AnnouncementPriority.critical:
      return 'Critical';
  }
}

/// Human label for the poster's role (display/audit only).
String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.superadmin:
      return 'Superadmin';
    case UserRole.admin:
      return 'Admin';
    case UserRole.staff:
      return 'Staff';
    case UserRole.resident:
      return 'Resident';
    case UserRole.public:
      return 'Public';
  }
}

/// Compact relative timestamp ("just now", "5m ago", "3h ago", "2d ago"),
/// falling back to an absolute date beyond a week.
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.announcementsOutlined,
            size: 48,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No announcements yet.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  final Object? error;

  const _FeedError({required this.error});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: cs.error),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Could not load announcements.',
            style: tt.bodyMedium?.copyWith(color: cs.error),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
