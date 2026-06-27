/// AwaitingApprovalScreen — resident application "under review" landing.
///
/// Gated landing for any user whose resident application is pending an
/// admin decision: either a resident signup (role=resident,
/// status=pending_approval) or a public user who applied to upgrade
/// (role=public, requestedRole=resident, status=pending_approval).
///
/// Transition out happens when an admin calls approveResident (status →
/// active, requestedUnit → unitNumber, role → resident) or rejectAsPublic
/// (role → public, status → active). The AuthGate StreamBuilder detects
/// the change and re-routes automatically.
///
/// The profile stream routes the user immediately when a decision lands, or
/// on their next launch if the app was closed. No push delivery is implied.
///
/// While pending, the user may "Continue browsing as public" — public
/// features stay available; Firestore rules enforce that a pending user
/// has no unit-scoped access regardless of what this UI offers.
library;

import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'public_home_screen.dart';

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

  void _continueAsPublic() {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PublicHomeScreen(user: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unit = _profile?.requestedUnit;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Application Under Review'),
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
                      'Application under review',
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Your resident application for unit '
                      '${unit ?? "your unit"} is being reviewed by our '
                      "administrators. You'll see your status here once "
                      "it's processed.",
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (unit != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit under review', style: tt.bodySmall),
                              const SizedBox(height: AppSpacing.xs),
                              Text(unit, style: tt.titleLarge),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _continueAsPublic,
                      icon: Icon(AppIcons.home),
                      label: const Text('Continue browsing as public'),
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
