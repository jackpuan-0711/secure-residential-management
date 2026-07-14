import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

enum _SecurityPhase { loading, biometric, setupPin, unlockPin, unlocked }

class AuthenticatedSecurityGate extends StatefulWidget {
  final String uid;
  final Widget child;

  const AuthenticatedSecurityGate({
    super.key,
    required this.uid,
    required this.child,
  });

  @override
  State<AuthenticatedSecurityGate> createState() =>
      _AuthenticatedSecurityGateState();
}

class _AuthenticatedSecurityGateState extends State<AuthenticatedSecurityGate>
    with WidgetsBindingObserver {
  final _authService = AuthService();
  final _appLockService = const AppLockService();
  final _biometricAuthService = BiometricAuthService();
  final _sessionService = SessionService();

  StreamSubscription<SessionSnapshot>? _sessionSubscription;
  Timer? _logoutTimer;
  DateTime _lastActivity = DateTime.now();
  _SecurityPhase _phase = _SecurityPhase.loading;
  String? _message;
  bool _biometricBusy = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedSecurityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid == widget.uid) return;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _logoutTimer?.cancel();
    _phase = _SecurityPhase.loading;
    _message = null;
    _biometricBusy = false;
    _signingOut = false;
    _lastActivity = DateTime.now();
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription?.cancel();
    _logoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleResume();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      AppLockService.lockRuntime(widget.uid);
      unawaited(_appLockService.recordLastActivity(widget.uid, DateTime.now()));
      _logoutTimer?.cancel();
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _sessionService.ensureActiveSession(widget.uid);
      _watchSession();
      await _appLockService.recordLastActivity(widget.uid, DateTime.now());
      if (!BiometricAuthService.isRuntimeVerified(widget.uid)) {
        _showBiometricPrompt();
        return;
      }
      await _resolvePinPhase();
    } on SessionException catch (e) {
      await _forceSignOut(e.message);
    } catch (e) {
      await _forceSignOut('Could not start a secure session.');
    }
  }

  void _watchSession() {
    _sessionSubscription ??= _sessionService.watchSession(widget.uid).listen((
      session,
    ) {
      if (!session.exists || !session.isCurrentDevice || session.isExpired) {
        _forceSignOut('This account was opened on another device.');
      }
    });
  }

  void _showBiometricPrompt() {
    if (!mounted) return;
    setState(() {
      _phase = _SecurityPhase.biometric;
      _message = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _verifyBiometric();
    });
  }

  Future<void> _verifyBiometric() async {
    if (_biometricBusy) return;
    setState(() {
      _biometricBusy = true;
      _message = null;
    });

    final result = await _biometricAuthService.authenticate(
      reason: 'Verify your fingerprint or face to continue.',
    );

    if (!mounted) return;
    if (result.success) {
      BiometricAuthService.markRuntimeVerified(widget.uid);
      setState(() => _biometricBusy = false);
      await _resolvePinPhase();
      return;
    }

    if (result.canFallbackToPin) {
      setState(() => _biometricBusy = false);
      await _resolvePinPhase();
      return;
    }

    setState(() {
      _biometricBusy = false;
      _message = result.message;
    });
  }

  Future<void> _resolvePinPhase() async {
    final hasPin = await _appLockService.hasPin(widget.uid);
    if (!mounted) return;
    if (!hasPin) {
      setState(() {
        _phase = _SecurityPhase.setupPin;
        _message = null;
      });
      return;
    }

    if (AppLockService.isRuntimeUnlocked(widget.uid)) {
      await _unlockApp();
      return;
    }

    setState(() {
      _phase = _SecurityPhase.unlockPin;
      _message = null;
    });
  }

  Future<void> _setupPin(String pin) async {
    try {
      await _appLockService.setPin(widget.uid, pin);
      AppLockService.unlockRuntime(widget.uid);
      await _unlockApp();
    } on AppLockException catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  Future<void> _unlockWithPin(String pin) async {
    try {
      final ok = await _appLockService.verifyPin(widget.uid, pin);
      if (!mounted) return;
      if (!ok) {
        setState(() => _message = 'Incorrect PIN. Please try again.');
        return;
      }
      AppLockService.unlockRuntime(widget.uid);
      await _unlockApp();
    } on AppLockException catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  Future<void> _unlockApp() async {
    _lastActivity = DateTime.now();
    await _appLockService.recordLastActivity(widget.uid, _lastActivity);
    try {
      await _sessionService.touch(widget.uid, force: true);
    } catch (_) {
      await _forceSignOut('Could not refresh your secure session.');
      return;
    }
    if (!mounted) return;
    _restartLogoutTimer();
    setState(() {
      _phase = _SecurityPhase.unlocked;
      _message = null;
    });
  }

  Future<void> _handleResume() async {
    final lastActivity =
        await _appLockService.lastActivity(widget.uid) ?? _lastActivity;
    if (DateTime.now().difference(lastActivity) >=
        AppLockService.autoLogoutTimeout) {
      await _forceSignOut('Your session expired.');
      return;
    }
    if (!mounted || _phase == _SecurityPhase.loading) return;
    AppLockService.lockRuntime(widget.uid);
    await _resolvePinPhase();
  }

  void _recordActivity() {
    if (_phase != _SecurityPhase.unlocked) return;
    _lastActivity = DateTime.now();
    _restartLogoutTimer();
    unawaited(_appLockService.recordLastActivity(widget.uid, _lastActivity));
    unawaited(_sessionService.touch(widget.uid));
  }

  void _restartLogoutTimer() {
    _logoutTimer?.cancel();
    _logoutTimer = Timer(AppLockService.autoLogoutTimeout, () {
      final idleFor = DateTime.now().difference(_lastActivity);
      if (idleFor >= AppLockService.autoLogoutTimeout) {
        _forceSignOut('Your session expired.');
      } else {
        _restartLogoutTimer();
      }
    });
  }

  Future<void> _forceSignOut(String message) async {
    if (_signingOut) return;
    _signingOut = true;
    _logoutTimer?.cancel();
    AppLockService.lockRuntime(widget.uid);
    await _sessionService.clearLocalSession(widget.uid);
    if (mounted) {
      setState(() {
        _phase = _SecurityPhase.loading;
        _message = message;
      });
    }
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _SecurityPhase.loading:
        return const _SecurityScaffold(
          icon: AppIcons.lock,
          title: 'Securing session',
          body: 'Preparing your protected app session.',
          child: Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        );
      case _SecurityPhase.biometric:
        return _SecurityScaffold(
          icon: Icons.fingerprint_rounded,
          title: 'Biometric verification',
          body: 'Use your fingerprint or face to continue.',
          message: _message,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _biometricBusy ? null : _verifyBiometric,
                icon: _biometricBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint_rounded),
                label: Text(_biometricBusy ? 'Verifying' : 'Verify biometrics'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => _forceSignOut('Signed out.'),
                icon: const Icon(AppIcons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        );
      case _SecurityPhase.setupPin:
        return _SecurityScaffold(
          icon: AppIcons.lock,
          title: 'Create app lock PIN',
          body: 'Set a 6-digit PIN for this account on this device.',
          message: _message,
          child: _PinForm(
            submitLabel: 'Create PIN',
            confirm: true,
            onSubmit: _setupPin,
          ),
        );
      case _SecurityPhase.unlockPin:
        return _SecurityScaffold(
          icon: AppIcons.lock,
          title: 'App lock',
          body: 'Enter your 6-digit PIN to unlock the app.',
          message: _message,
          child: _PinForm(submitLabel: 'Unlock', onSubmit: _unlockWithPin),
        );
      case _SecurityPhase.unlocked:
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _recordActivity(),
          onPointerMove: (_) => _recordActivity(),
          onPointerSignal: (_) => _recordActivity(),
          child: widget.child,
        );
    }
  }
}

class _SecurityScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? message;
  final Widget child;

  const _SecurityScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(icon, size: 72, color: cs.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: tt.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(color: cs.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    child,
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

class _PinForm extends StatefulWidget {
  final String submitLabel;
  final bool confirm;
  final Future<void> Function(String pin) onSubmit;

  const _PinForm({
    required this.submitLabel,
    required this.onSubmit,
    this.confirm = false,
  });

  @override
  State<_PinForm> createState() => _PinFormState();
}

class _PinFormState extends State<_PinForm> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await widget.onSubmit(_pinController.text);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validatePin(String? value) {
    if (value == null || value.isEmpty) return 'Enter your 6-digit PIN';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'PIN must be exactly 6 digits';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    final pinError = _validatePin(value);
    if (pinError != null) return pinError;
    if (value != _pinController.text) return 'PINs do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: AppLockService.pinLength,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(AppLockService.pinLength),
            ],
            decoration: const InputDecoration(
              labelText: '6-digit PIN',
              prefixIcon: Icon(AppIcons.lockOutlined),
              counterText: '',
            ),
            validator: _validatePin,
            onFieldSubmitted: (_) {
              if (!widget.confirm) _submit();
            },
          ),
          if (widget.confirm) ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: AppLockService.pinLength,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(AppLockService.pinLength),
              ],
              decoration: const InputDecoration(
                labelText: 'Confirm 6-digit PIN',
                prefixIcon: Icon(AppIcons.lockOutlined),
                counterText: '',
              ),
              validator: _validateConfirm,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
