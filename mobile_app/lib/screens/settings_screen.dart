import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'help_center_screen.dart';
import 'privacy_security_screen.dart';

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
            onTap: () => _open(context, const AboutScreen()),
          ),
        ],
      ),
    );
  }
}

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
