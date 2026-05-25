/// AwaitingApprovalScreen — Sprint 2, Step 4b.
///
/// Gated landing for authenticated residents with status=pendingApproval.
/// The user has:
///   - A verified Firebase Auth account
///   - A Firestore /users/{uid} doc with role=resident, status=pendingApproval
///   - A requestedUnit value awaiting admin verification
///
/// Transition out happens when admin calls UserRepository.approveResident
/// (promotes requestedUnit → unitNumber, status → active) or rejectAsPublic
/// (role → public, status → active). main.dart StreamBuilder will detect
/// the change and route accordingly.
///
/// This screen is intentionally minimal — no feedback forms, no
/// announcements access. Firestore rules (Step 5) will enforce that
/// pendingApproval users cannot read resident-tier collections. The UI
/// merely reflects that restriction honestly.
library;

import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AwaitingApprovalScreen extends StatefulWidget {
  final AuthService? authService;
  final UserRepository? userRepository;

  const AwaitingApprovalScreen({
    super.key,
    this.authService,
    this.userRepository,
  });

  @override
  State<AwaitingApprovalScreen> createState() =>
      _AwaitingApprovalScreenState();
}

class _AwaitingApprovalScreenState extends State<AwaitingApprovalScreen> {
  late final AuthService _authService;
  late final UserRepository _userRepository;

  AppUser? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userRepository = widget.userRepository ?? UserRepository();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final identity = _authService.currentUser;
    if (identity == null) return;

    setState(() => _isLoading = true);
    try {
      final profile = await _userRepository.getUserProfile(identity.uid);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account Under Review'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(AppIcons.pending, size: 72, color: cs.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Waiting for admin approval',
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'An administrator will review your unit number and '
                      "activate your resident account. You'll get access "
                      'automatically once approved — no action needed from you.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_profile?.requestedUnit != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unit under review',
                                style: tt.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _profile!.requestedUnit!,
                                style: tt.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _loadProfile,
                      icon: Icon(AppIcons.refresh),
                      label: const Text('Refresh status'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: _handleSignOut,
                      icon: Icon(AppIcons.logout),
                      label: const Text('Sign out'),
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
