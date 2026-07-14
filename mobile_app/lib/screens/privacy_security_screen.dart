import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'change_password_screen.dart';

/// Privacy & Security hub.
///
/// Security actions:
///   1. Change the local 6-digit app lock PIN.
///   2. Send a password reset email - out-of-band link.
/// Plus a short, plain-language note about how the user's data is handled.
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  Future<void> _sendResetEmail(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final authService = AuthService();
    final email = authService.currentUser?.email;
    if (email == null || email.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetEmailDialogTitle),
        content: Text(l10n.resetEmailDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.resetEmailSendAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await authService.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.resetEmailSentSuccess)),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SectionHeader(title: l10n.privacySectionAccount),
          _ActionTile(
            icon: AppIcons.lockOutlined,
            title: l10n.privacyChangePassword,
            subtitle: l10n.privacyChangePasswordSubtitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          _ActionTile(
            icon: AppIcons.emailOutlined,
            title: l10n.privacySendResetEmail,
            subtitle: l10n.privacySendResetEmailSubtitle,
            onTap: () => _sendResetEmail(context),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionHeader(title: l10n.privacySectionData),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(AppIcons.verified, color: AppColors.secondary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.privacyDataNote,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(AppIcons.arrowRight, size: 16),
        onTap: onTap,
      ),
    );
  }
}
