import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Help Center: a short FAQ plus how to reach the management office.
///
/// Content is intentionally static and localized — no backend call — so it
/// works offline and before the user's profile loads.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              l10n.helpIntro,
              style: tt.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          _SectionHeader(title: l10n.helpSectionFaq),
          _FaqItem(
            question: l10n.helpFaqResetQuestion,
            answer: l10n.helpFaqResetAnswer,
          ),
          _FaqItem(
            question: l10n.helpFaqApprovalQuestion,
            answer: l10n.helpFaqApprovalAnswer,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionHeader(title: l10n.helpSectionContact),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    AppIcons.emailOutlined,
                    color: AppColors.primary,
                  ),
                  title: Text(l10n.helpContactEmailLabel),
                  subtitle: const Text('support@residentialhub.my'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(AppIcons.phone, color: AppColors.primary),
                  title: Text(l10n.helpContactPhoneLabel),
                  subtitle: const Text('+60 3-1234 5678'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(l10n.helpOfficeHours, style: tt.bodySmall),
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

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        shape: const Border(),
        leading: const Icon(AppIcons.info, color: AppColors.primary),
        title: Text(question, style: Theme.of(context).textTheme.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(
            answer,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
