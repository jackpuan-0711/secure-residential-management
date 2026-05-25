import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// In-app password change: verify the current password, then set a new one.
///
/// The new-password rule mirrors signup (OWASP ASVS 4.0.3 §2.1.1: minimum
/// 12 characters, no composition rules per §2.1.9) so the policy is
/// enforced identically wherever a password is set.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      await _authService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passwordChangedSuccess)),
      );
      navigator.pop();
    } on AuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateCurrent(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n.validationCurrentPasswordRequired;
    }
    return null;
  }

  String? _validateNew(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n.validationPasswordRequired;
    }
    // OWASP ASVS 4.0.3 §2.1.1 (L1): minimum 12 characters. Matches signup.
    if (value.length < 12) {
      return l10n.validationPasswordMinLength;
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n.validationConfirmPasswordRequired;
    }
    if (value != _newController.text) {
      return l10n.validationPasswordsDoNotMatch;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePasswordTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentController,
                    obscureText: _obscureCurrent,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.currentPasswordLabel,
                      prefixIcon: const Icon(AppIcons.lockOutlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent
                            ? AppIcons.visibility
                            : AppIcons.visibilityOff),
                        onPressed: () => setState(
                          () => _obscureCurrent = !_obscureCurrent,
                        ),
                      ),
                    ),
                    validator: _validateCurrent,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _newController,
                    obscureText: _obscureNew,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.newPasswordLabel,
                      helperText: l10n.passwordHelperMinLength,
                      prefixIcon: const Icon(AppIcons.lockOutlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew
                            ? AppIcons.visibility
                            : AppIcons.visibilityOff),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: _validateNew,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    decoration: InputDecoration(
                      labelText: l10n.confirmPasswordLabel,
                      prefixIcon: const Icon(AppIcons.lockOutlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? AppIcons.visibility
                            : AppIcons.visibilityOff),
                        onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                      ),
                    ),
                    validator: _validateConfirm,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.changePasswordButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
