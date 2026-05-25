import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Signup screen — creates a new user account.
///
/// Flow:
///   1. User enters name, email, password, confirms password
///   2. Client-side validation (format, match)
///   3. AuthService.signUp() is called — which:
///      - Creates the Firebase Auth account
///      - Sets the displayName
///      - Sends the email verification link
///   4. On success, pop back to AuthGate — the StreamBuilder router
///      in main.dart detects the new authenticated-but-unverified
///      state and renders EmailVerificationScreen.
///   5. On failure, show a SnackBar with the humanized error
///
/// ─── ARCHITECTURAL NOTE (Sprint 2, Step 4a) ────────────────────
/// This screen deliberately does NOT create a Firestore /users/{uid}
/// profile document. Profile creation is deferred to
/// CompleteProfileScreen (Step 4b), which runs after email
/// verification. See AuthService.signUp() for the full rationale.
/// ────────────────────────────────────────────────────────────────
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );

      // Success — pop back to AuthGate.
      //
      // ─── ARCHITECTURAL NOTE (Sprint 2, Step 4a) ──────────────
      // In Sprint 1 this screen explicitly pushed EmailVerificationScreen
      // because only two post-auth states existed (unverified, verified).
      //
      // Sprint 2 introduces six post-auth states:
      //   1. unverified              → EmailVerificationScreen
      //   2. verified, no profile    → CompleteProfileScreen
      //   3. pending_approval        → AwaitingApprovalScreen
      //   4. active + resident       → ResidentHome
      //   5. active + public         → PublicHome
      //   6. suspended               → SuspendedScreen
      //
      // Only AuthGate (main.dart) has the full picture needed to
      // decide the next screen, because the decision depends on BOTH
      // Firebase Auth state AND the Firestore profile document.
      //
      // Popping back lets AuthGate's StreamBuilder react to the new
      // authenticated-but-unverified state and route to
      // EmailVerificationScreen from one canonical place.
      //
      // The verification email has ALREADY been sent by
      // AuthService.signUp() via sendEmailVerification(). Nothing
      // about the user experience changes.
      // ──────────────────────────────────────────────────────────
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Validators ─────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    // OWASP ASVS 4.0.3 §2.1.1 (L1): minimum 12 characters for
    // memorised secrets. Firebase Auth's server-side minimum is 6;
    // this stricter client-side rule is our security baseline.
    if (value.length < 12) {
      return 'Password must be at least 12 characters';
    }
    // Deliberately NO composition rules per ASVS §2.1.9 — requiring
    // mixed case / digits / symbols reduces entropy in practice
    // (users append predictable suffixes) and is actively discouraged.
    //
    // Sprint 3 hardening per ASVS §2.1.7, §2.1.8:
    //   - Breach corpus check via Have I Been Pwned k-anonymity API
    //   - zxcvbn strength meter (advisory UX, not blocking)
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join your community',
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Register to access the resident portal',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ─── Name ─────────────────────────────
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(AppIcons.profileOutlined),
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ─── Email ────────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(AppIcons.emailOutlined),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ─── Password ─────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(AppIcons.lockOutlined),
                        helperText: 'At least 12 characters',
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
                    const SizedBox(height: AppSpacing.md),

                    // ─── Confirm password ─────────────────
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSignup(),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(AppIcons.lockOutlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword
                              ? AppIcons.visibility
                              : AppIcons.visibilityOff),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ─── Signup button ────────────────────
                    FilledButton(
                      onPressed: _isLoading ? null : _handleSignup,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ─── Back to login ────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?', style: tt.bodyMedium),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Log In'),
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