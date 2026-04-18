import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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
            backgroundColor: Colors.red.shade700,
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

  /// Client-side email validator.
  /// NOT a substitute for server-side validation (Firebase does that too),
  /// but catches obvious mistakes before wasting a network call.
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    // Simple regex: something@something.something
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Client-side password validator.
  /// Matches Firebase's minimum (6 chars). In Sprint 3 we'll tighten this
  /// with stronger rules (uppercase, number, symbol) and a strength meter.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── App branding ───────────────────────────────
                  Icon(
                    Icons.home_work_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to your secure resident portal',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Email field ────────────────────────────────
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // ─── Password field ─────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 24),

                  // ─── Login button ───────────────────────────────
                  FilledButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Secure Login',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Signup navigation ──────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                        child: const Text('Sign Up'),
                      ),
                    ],
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