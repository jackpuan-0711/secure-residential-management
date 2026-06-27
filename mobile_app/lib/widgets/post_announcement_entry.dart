import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../screens/post_announcement_screen.dart';
import '../services/announcement_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// CTA card on the privileged homes that opens the announcement composer.
///
/// [postedBy] / [postedByRole] come from the authenticated session (the
/// AuthIdentity AuthGate routed on), NOT user input. They are threaded straight
/// to [PostAnnouncementScreen] so the eventual write matches what the Firestore
/// rule pins to `request.auth.uid` / `request.auth.token.role`.
class PostAnnouncementEntry extends StatelessWidget {
  final String postedBy;
  final UserRole postedByRole;

  /// Injectable for tests; forwarded to the composer.
  final AnnouncementRepository? repository;

  const PostAnnouncementEntry({
    super.key,
    required this.postedBy,
    required this.postedByRole,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        color: cs.primaryContainer,
        child: InkWell(
          borderRadius: AppRadius.xlBr,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostAnnouncementScreen(
                postedBy: postedBy,
                postedByRole: postedByRole,
                repository: repository,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  AppIcons.announcements,
                  color: cs.onPrimaryContainer,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post an announcement',
                        style: tt.titleMedium
                            ?.copyWith(color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Share a notice with all verified residents.',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.arrowRight,
                  size: 16,
                  color: cs.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
