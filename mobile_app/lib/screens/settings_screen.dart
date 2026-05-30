import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'help_center_screen.dart';
import 'notifications_settings_screen.dart';
import 'privacy_security_screen.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SectionHeader(title: l10n.settingsSectionGeneral),
          _SettingTile(
            icon: AppIcons.notificationsOutlined,
            title: l10n.settingsNotifications,
            onTap: () => _open(context, const NotificationsSettingsScreen()),
          ),
          _SettingTile(
            icon: AppIcons.lockOutlined,
            title: l10n.settingsPrivacySecurity,
            onTap: () => _open(context, const PrivacySecurityScreen()),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionHeader(title: l10n.settingsSectionSupport),
          _SettingTile(
            icon: Icons.help_outline_rounded,
            title: l10n.settingsHelpCenter,
            onTap: () => _open(context, const HelpCenterScreen()),
          ),
          _SettingTile(
            icon: AppIcons.info,
            title: l10n.settingsAbout,
            onTap: () => _showAboutDialog(context, l10n),
          ),
          const SizedBox(height: AppSpacing.md),
          // Account section. Strings are hardcoded (no l10n keys): the
          // localization system is intentionally left untouched this phase.
          const _SectionHeader(title: 'Account'),
          _SettingTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete account',
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  /// A deliberately minimal "About" dialog.
  ///
  /// ─── SECURITY: NO VERSION, NO BUNDLED LICENSE LIST ─────────────────
  /// We do NOT use Flutter's [showAboutDialog]. That helper exposes the
  /// app version/build and a "View licenses" page enumerating every
  /// bundled open-source package. For a security-focused residential app
  /// that is needless information disclosure: build/version strings and
  /// the full dependency inventory help an attacker fingerprint the app
  /// and look up known CVEs. End users gain nothing from it. This dialog
  /// shows only the product name, purpose, and copyright. (This is why
  /// Settings deliberately does NOT surface an app-version row.)
  /// ────────────────────────────────────────────────────────────────────
  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.aboutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aboutDescription,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '© ${DateTime.now().year} ${l10n.aboutCopyright}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }

  /// Placeholder only — no action is wired. Self-service account deletion
  /// is out of scope for this phase.
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          "Account deletion isn't available yet. Please contact the "
          'management office if you need your account removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase label that groups the settings list into sections.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        trailing: const Icon(AppIcons.arrowRight, size: 16),
        onTap: onTap,
      ),
    );
  }
}
