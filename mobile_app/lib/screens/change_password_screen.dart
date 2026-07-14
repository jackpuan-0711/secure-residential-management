import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

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
  final _appLockService = const AppLockService();

  bool _isLoading = false;
  bool _hasExistingPin = true;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final hasPin = await _appLockService.hasPin(uid);
    if (mounted) setState(() => _hasExistingPin = hasPin);
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    try {
      if (_hasExistingPin) {
        final verified = await _appLockService.verifyPin(
          uid,
          _currentController.text,
        );
        if (!verified) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Current PIN is incorrect.'),
              backgroundColor: errorColor,
            ),
          );
          return;
        }
      }

      await _appLockService.setPin(uid, _newController.text);
      AppLockService.unlockRuntime(uid);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passwordChangedSuccess)),
      );
      navigator.pop();
    } on AppLockException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: errorColor),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateCurrent(String? value) {
    if (!_hasExistingPin) return null;
    return _validatePin(value, emptyMessage: 'Enter your current 6-digit PIN');
  }

  String? _validateNew(String? value) {
    return _validatePin(value, emptyMessage: 'Enter a new 6-digit PIN');
  }

  String? _validateConfirm(String? value) {
    final pinError = _validatePin(
      value,
      emptyMessage: 'Please confirm your new 6-digit PIN',
    );
    if (pinError != null) return pinError;
    if (value != _newController.text) return 'PINs do not match';
    return null;
  }

  String? _validatePin(String? value, {required String emptyMessage}) {
    if (value == null || value.isEmpty) return emptyMessage;
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'PIN must be exactly 6 digits';
    }
    return null;
  }

  List<TextInputFormatter> get _pinFormatters => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(AppLockService.pinLength),
  ];

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
                  if (_hasExistingPin) ...[
                    TextFormField(
                      controller: _currentController,
                      obscureText: _obscureCurrent,
                      keyboardType: TextInputType.number,
                      maxLength: AppLockService.pinLength,
                      inputFormatters: _pinFormatters,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.currentPasswordLabel,
                        counterText: '',
                        prefixIcon: const Icon(AppIcons.lockOutlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrent
                                ? AppIcons.visibility
                                : AppIcons.visibilityOff,
                          ),
                          onPressed: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                        ),
                      ),
                      validator: _validateCurrent,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextFormField(
                    controller: _newController,
                    obscureText: _obscureNew,
                    keyboardType: TextInputType.number,
                    maxLength: AppLockService.pinLength,
                    inputFormatters: _pinFormatters,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.newPasswordLabel,
                      helperText: l10n.passwordHelperMinLength,
                      counterText: '',
                      prefixIcon: const Icon(AppIcons.lockOutlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew
                              ? AppIcons.visibility
                              : AppIcons.visibilityOff,
                        ),
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
                    keyboardType: TextInputType.number,
                    maxLength: AppLockService.pinLength,
                    inputFormatters: _pinFormatters,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    decoration: InputDecoration(
                      labelText: l10n.confirmPasswordLabel,
                      counterText: '',
                      prefixIcon: const Icon(AppIcons.lockOutlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? AppIcons.visibility
                              : AppIcons.visibilityOff,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
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
