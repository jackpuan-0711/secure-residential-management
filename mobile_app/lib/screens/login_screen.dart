import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';

/// Login screen — the primary authentication entry point.
///
/// Responsibilities:
///   - Collect email + password from the user
///   - Validate format client-side before hitting Firebase
///   - Call AuthService.signIn() and handle success/failure
///   - Show loading state during the async call
///   - Navigate to Signup screen on demand
///
/// It does NOT:
///   - Navigate to Home on success — that's handled by the authStateChanges
///     stream in main.dart (added in Step 10). When Firebase Auth state
///     changes, the root widget auto-routes. This keeps navigation logic
///     centralized.
///   - Call FirebaseAuth directly — it only talks to AuthService.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form key lets us trigger validation on all TextFormFields at once.
  final _formKey = GlobalKey<FormState>();

  // Controllers hold the text in each field. MUST be disposed to avoid leaks.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Service instance. Created once per screen lifecycle.
  final _authService = AuthService();

  // UI state flags.
  bool _isLoading = false;      // disables button during async call
  bool _obscurePassword = true; // password visibility toggle

  @override
  void dispose() {
    // Controllers wrap native resources — always dispose in State.dispose()
    // or you'll leak memory every time the screen closes.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles the login button tap.
  /// Validates the form, calls AuthService, handles errors gracefully.
  Future<void> _handleLogin() async {
    // Trigger validation on all TextFormFields. Returns false if any fails.
    if (!_formKey.currentState!.validate()) return;

    // Hide keyboard for a cleaner loading experience.
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // On success: authStateChanges stream in main.dart will auto-navigate.
      // We don't push/pop here — single source of truth for routing.
    } on AuthException catch (e) {
      // AuthService already humanized the error — just display it.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // Always reset loading state, even on error.
      // The `mounted` check prevents calling setState on a disposed widget
      // (would happen if user navigated away mid-request).
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Prompts for an email and sends a password-reset link.
  /// Used when the user is locked out and cannot reach in-app settings.
  Future<void> _handleForgotPassword() async {
    final l10n = AppLocalizations.of(context);
    final resetController = TextEditingController(text: _emailController.text);

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetEmailDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.resetEmailDialogBody),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.loginEmailLabel,
                prefixIcon: const Icon(AppIcons.emailOutlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(resetController.text.trim()),
            child: Text(l10n.resetEmailSendAction),
          ),
        ],
      ),
    );

    resetController.dispose();

    if (email == null || email.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await _authService.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.resetEmailSentSuccess)),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  /// Client-side email validator.
  /// NOT a substitute for server-side validation (Firebase does that too),
  /// but catches obvious mistakes before wasting a network call.
  String? _validateEmail(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return l10n.validationEmailRequired;
    }
    // Simple regex: something@something.something
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return l10n.validationEmailInvalid;
    }
    return null;
  }

  /// Client-side password validator. Login only checks presence — the
  /// length/strength policy is enforced where a password is SET (signup,
  /// change password), never at login, so existing accounts are never
  /// locked out by a policy change.
  String? _validatePassword(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n.validationPasswordRequired;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              // Prevents overly wide forms on tablets.
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── App branding ─────────────────────────────
                    Icon(AppIcons.unit, size: 72, color: cs.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.loginWelcomeTitle,
                      textAlign: TextAlign.center,
                      style: tt.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.loginWelcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ─── Email field ──────────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.loginEmailLabel,
                        prefixIcon: Icon(AppIcons.emailOutlined),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ─── Password field ───────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: l10n.loginPasswordLabel,
                        prefixIcon: Icon(AppIcons.lockOutlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? AppIcons.visibility
                              : AppIcons.visibilityOff),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),

                    // ─── Forgot password ──────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            _isLoading ? null : _handleForgotPassword,
                        child: Text(l10n.loginForgotPassword),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // ─── Login button ─────────────────────────────
                    FilledButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.loginButton),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ─── Signup navigation ────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.loginNoAccountQuestion,
                          style: tt.bodyMedium,
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  ),
                          child: Text(l10n.loginSignUpAction),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}