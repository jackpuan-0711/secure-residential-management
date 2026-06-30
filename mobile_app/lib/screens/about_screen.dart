import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  static const _studentName = 'PUAN KANG WEI';
  static const _projectTitle =
      'SECURE Residential Management Mobile Application with Multi-Layered '
      'Authentication & IOT Integration';
  static const _supervisor = 'TS. DR. JOHAN BIN MOHAMAD SHARIF';
  static const _matricNumber = 'A23CS5043';

  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          _AboutItem(
            icon: AppIcons.profile,
            label: 'Name',
            value: _studentName,
          ),
          _AboutItem(
            icon: Icons.school_rounded,
            label: 'FYP title',
            value: _projectTitle,
          ),
          _AboutItem(
            icon: Icons.supervisor_account_outlined,
            label: 'Supervisor',
            value: _supervisor,
          ),
          _AboutItem(
            icon: Icons.badge_outlined,
            label: 'Matric No.',
            value: _matricNumber,
          ),
        ],
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
