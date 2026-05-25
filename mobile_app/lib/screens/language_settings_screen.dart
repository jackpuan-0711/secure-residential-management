import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Lets the user switch the app language between English and Bahasa
/// Malaysia. The choice is persisted by [AppSettings] and applied
/// immediately app-wide (the root MaterialApp rebuilds on change).
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  Future<void> _select(BuildContext context, Locale locale) async {
    final settings = SettingsScope.of(context);
    if (settings.locale.languageCode == locale.languageCode) return;

    await settings.setLocale(locale);
    if (!context.mounted) return;

    // Re-resolve l10n AFTER the change so the confirmation is in the new
    // language.
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).languageUpdated)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context);
    final currentCode = settings.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              l10n.languageSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
          ),
          _LanguageOption(
            label: l10n.languageEnglish,
            selected: currentCode == 'en',
            onTap: () => _select(context, const Locale('en')),
          ),
          _LanguageOption(
            label: l10n.languageMalay,
            selected: currentCode == 'ms',
            onTap: () => _select(context, const Locale('ms')),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.language_rounded, color: AppColors.primary),
        title: Text(label),
        trailing: selected
            ? const Icon(AppIcons.checkCircle, color: AppColors.secondary)
            : null,
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}
