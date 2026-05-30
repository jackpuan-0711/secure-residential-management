/// CompleteProfileScreen — Sprint 2, Step 4b.
///
/// Reached via the AuthGate router (main.dart, Step 6/7) when:
///   - Firebase Auth user exists
///   - Email is verified
///   - /users/{uid} Firestore doc does NOT exist
///
/// This is the single point where the Firestore profile is created.
/// Two outcomes:
///   1. User self-identifies as RESIDENT → profile created with
///      role=resident, status=pendingApproval, requestedUnit=<form>.
///      Router then sends them to AwaitingApprovalScreen.
///   2. User chooses PUBLIC tier → profile created with role=public,
///      status=active, requestedUnit=null. Router sends to PublicHome.
///
/// Security invariants (enforced by UserRepository + Firestore rules):
///   - requestedUnit is user-claimed; NOT trusted as verified.
///   - unitNumber (verified) is NEVER set here. Only admin approval
///     promotes requestedUnit → unitNumber (transaction, audit trail).
///   - public tier is a PSM-2 extension to the PSM-1 RBAC model.
///     Distinct from the PSM-1 Visitor entity (unauthenticated QR guest).
library;

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../utils/validators.dart';

enum _RoleChoice { resident, publicUser }

class CompleteProfileScreen extends StatefulWidget {
  final AuthService? authService;
  final UserRepository? userRepository;

  const CompleteProfileScreen({
    super.key,
    this.authService,
    this.userRepository,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final AuthService _authService;
  late final UserRepository _userRepository;

  final _formKey = GlobalKey<FormState>();
  final _unitController = TextEditingController();

  _RoleChoice _selectedRole = _RoleChoice.publicUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userRepository = widget.userRepository ?? UserRepository();
  }

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final identity = _authService.currentUser;
    if (identity == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      if (_selectedRole == _RoleChoice.resident) {
        await _userRepository.createUserProfile(
          uid: identity.uid,
          email: identity.email,
          name: identity.displayName ?? 'User',
          requestedUnit: _unitController.text.trim(),
        );
      } else {
        await _userRepository.createPublicProfile(
          uid: identity.uid,
          email: identity.email,
          name: identity.displayName ?? 'User',
        );
      }

      // TODO(step-6): rely on AuthGate router after main.dart StreamBuilder
      // lands — remove manual SnackBar.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_humanizeError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _humanizeError(Object e) {
    if (e is UserRepositoryException) return e.message;
    return 'Failed to save profile. Please try again.';
  }

  String? _validateUnit(String? value) {
    // Public users have no unit to validate.
    if (_selectedRole != _RoleChoice.resident) return null;
    // Shared validator — same regex enforced by Firestore rules and
    // re-checked in UserRepository (client validation is UX only).
    return validateUnitNumber(value);
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          automaticallyImplyLeading: false,
        ),
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
                    Text(
                      'Setting up account for:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'How will you use this app?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),

                    // ─── Role selection ──────────────────────────────
                    // ignore: deprecated_member_use
                    RadioListTile<_RoleChoice>(
                      title: const Text("I'm a resident"),
                      subtitle: const Text(
                        'Apply for unit-based access (requires admin approval)',
                      ),
                      value: _RoleChoice.resident,
                      // ignore: deprecated_member_use
                      groupValue: _selectedRole,
                      // ignore: deprecated_member_use
                      onChanged: _isLoading
                          ? null
                          : (v) => setState(() => _selectedRole = v!),
                    ),

                    // ─── Unit field (resident only) ──────────────────
                    if (_selectedRole == _RoleChoice.resident)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextFormField(
                          key: const Key('unitNumberField'),
                          controller: _unitController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: unitNumberInputFormatters,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Unit Number',
                            hintText: unitNumberHint,
                            prefixIcon: Icon(Icons.home_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateUnit,
                        ),
                      ),

                    // ignore: deprecated_member_use
                    RadioListTile<_RoleChoice>(
                      title: const Text('Continue as public user'),
                      subtitle: const Text(
                        "You'll be able to view community announcements and submit "
                        'general feedback. Resident features (property complaints, '
                        'visitor pre-registration) require admin approval of a '
                        'verified unit.',
                      ),
                      value: _RoleChoice.publicUser,
                      // ignore: deprecated_member_use
                      groupValue: _selectedRole,
                      // ignore: deprecated_member_use
                      onChanged: _isLoading
                          ? null
                          : (v) => setState(() => _selectedRole = v!),
                    ),

                    const SizedBox(height: 24),

                    // ─── Submit ──────────────────────────────────────
                    FilledButton(
                      onPressed: _isLoading ? null : _handleSubmit,
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
                              'Continue',
                              style: TextStyle(fontSize: 16),
                            ),
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
