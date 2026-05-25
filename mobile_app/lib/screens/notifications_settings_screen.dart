import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';

/// Notification preferences. Each toggle is persisted by [AppSettings] and
/// takes effect immediately.
///
/// These flags record the user's CONSENT for each notification channel.
/// Delivery (FCM push, transactional email) is wired in a later sprint;
/// this screen is the source of truth the sender will consult.
class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  void _confirmSaved(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).notificationsSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              l10n.notificationsSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
          ),
          _NotificationSwitch(
            title: l10n.notifPushTitle,
            subtitle: l10n.notifPushSubtitle,
            value: settings.pushNotifications,
            onChanged: (v) async {
              await settings.setPushNotifications(v);
              if (context.mounted) _confirmSaved(context);
            },
          ),
          _NotificationSwitch(
            title: l10n.notifEmailTitle,
            subtitle: l10n.notifEmailSubtitle,
            value: settings.emailNotifications,
            onChanged: (v) async {
              await settings.setEmailNotifications(v);
              if (context.mounted) _confirmSaved(context);
            },
          ),
          _NotificationSwitch(
            title: l10n.notifAnnouncementsTitle,
            subtitle: l10n.notifAnnouncementsSubtitle,
            value: settings.announcementNotifications,
            onChanged: (v) async {
              await settings.setAnnouncementNotifications(v);
              if (context.mounted) _confirmSaved(context);
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: value,
        activeTrackColor: AppColors.secondary,
        onChanged: onChanged,
      ),
    );
  }
}
