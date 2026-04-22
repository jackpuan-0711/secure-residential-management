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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.hourglass_top,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for admin approval',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'An administrator will review your unit number and '
                    "activate your resident account. You'll get access "
                    'automatically once approved — no action needed from you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_profile?.requestedUnit != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unit under review',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profile!.requestedUnit!,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh status'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
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
