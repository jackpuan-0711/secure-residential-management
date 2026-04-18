import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Shown immediately after signup to tell the user to verify their email.
///
/// Features:
///   - Auto-polls every 3 seconds to detect when the user clicks the
///     verification link (email gets verified server-side; we need to
///     reload to pick up the new status)
///   - "Resend email" button with 60-second cooldown to prevent abuse
///   - "Sign out" escape hatch in case user wants to use a different email
///
/// Once emailVerified becomes true, authStateChanges stream fires again
/// and main.dart routes us to HomeScreen. (Wired up in Step 10.)
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = AuthService();

  Timer? _verificationPollTimer;
  Timer? _resendCooldownTimer;

  bool _isResending = false;
  int _resendCooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Start polling every 3 seconds for email verification.
    // Firebase doesn't push this event — we have to pull.
    _verificationPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerificationStatus(),
    );
  }

  @override
  void dispose() {
    _verificationPollTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerificationStatus() async {
    await _authService.reloadCurrentUser();
    final user = _authService.currentUser;

    // If the user verified, authStateChanges in main.dart will route us
    // to Home. We just stop polling here.
    if (user == null || user.emailVerified) {
      _verificationPollTimer?.cancel();
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    try {
      await _authService.resendVerificationEmail();
      _startResendCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _startResendCooldown() {
    setState(() => _resendCooldownSeconds = 60);
    _resendCooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_resendCooldownSeconds <= 1) {
          timer.cancel();
          if (mounted) setState(() => _resendCooldownSeconds = 0);
        } else {
          if (mounted) {
            setState(() => _resendCooldownSeconds--);
          }
        }
      },
    );
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    // authStateChanges will handle routing back to Login.
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? 'your email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Required'),
        automaticallyImplyLeading: false, // no back button
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Check your email',
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We've sent a verification link to:",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  'Click the link in the email to verify your account. '
                  'This screen will update automatically once verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),

                // Resend button with cooldown
                OutlinedButton.icon(
                  onPressed: (_isResending || _resendCooldownSeconds > 0)
                      ? null
                      : _handleResend,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    _resendCooldownSeconds > 0
                        ? 'Resend in ${_resendCooldownSeconds}s'
                        : 'Resend Email',
                  ),
                ),
                const SizedBox(height: 8),

                TextButton(
                  onPressed: _handleSignOut,
                  child: const Text('Use a different email (Sign out)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}