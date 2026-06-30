import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Shows the signed-in user's profile (hosted as a tab inside the role
/// home shells). Supports an inline edit of the two MUTABLE fields (name,
/// phone) via UserRepository.updateProfile — role/status/unit are NOT
/// editable here (privilege-relevant; admin-gated elsewhere).
class ProfileScreen extends StatefulWidget {
  final AppUser user;
  final AuthService? authService;
  final UserRepository? userRepository;

  const ProfileScreen({
    super.key,
    required this.user,
    this.authService,
    this.userRepository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService;
  late final UserRepository _userRepository;
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userRepository = widget.userRepository ?? UserRepository();
    _user = widget.user;
  }

  static String _humanizeRole(UserRole role) => switch (role) {
    UserRole.superadmin => 'Super Admin',
    UserRole.admin => 'Admin',
    UserRole.staff => 'Staff',
    UserRole.resident => 'Resident',
    UserRole.public => 'Public',
  };

  static String _humanizeStatus(UserStatus status) => switch (status) {
    UserStatus.pendingApproval => 'Pending approval',
    UserStatus.active => 'Active',
    UserStatus.suspended => 'Suspended',
  };

  static String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  Future<void> _edit() async {
    final result = await showDialog<_ProfileFormResult>(
      context: context,
      builder: (_) => _ProfileEditDialog(
        initialName: _user.name,
        initialPhone: _user.phoneNumber ?? '',
      ),
    );
    if (result == null) return;

    final newPhone = result.phone.isEmpty ? null : result.phone;
    try {
      await _userRepository.updateProfile(
        uid: _user.uid,
        name: result.name,
        phoneNumber: newPhone,
        clearPhoneNumber: newPhone == null,
      );
      if (mounted) {
        setState(
          () => _user = _user.copyWith(
            name: result.name,
            phoneNumber: newPhone,
            clearPhoneNumber: newPhone == null,
          ),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to return.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final unitDisplay = _user.unitNumber != null
        ? _user.unitNumber!
        : (_user.requestedUnit != null
              ? '${_user.requestedUnit!} (pending)'
              : 'Not assigned');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.edit),
            tooltip: 'Edit',
            onPressed: _edit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(AppIcons.profile, size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _user.name.isNotEmpty ? _user.name : 'User',
              style: tt.headlineSmall,
            ),
            Text(
              _user.email,
              style: tt.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            _ProfileItem(
              icon: AppIcons.unit,
              label: 'Unit',
              value: unitDisplay,
            ),
            _ProfileItem(
              icon: AppIcons.verified,
              label: 'Role',
              value: _humanizeRole(_user.role),
            ),
            _ProfileItem(
              icon: AppIcons.pending,
              label: 'Status',
              value: _humanizeStatus(_user.status),
            ),
            _ProfileItem(
              icon: AppIcons.phone,
              label: 'Phone',
              value: _user.phoneNumber ?? 'Not set',
            ),
            _ProfileItem(
              icon: AppIcons.calendar,
              label: 'Member since',
              value: _formatDate(_user.createdAt),
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(AppIcons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFormResult {
  final String name;
  final String phone;

  const _ProfileFormResult({required this.name, required this.phone});
}

/// Owns the form controllers for the full lifetime of the dialog route.
/// Disposing controllers in the caller immediately after `showDialog` returns
/// can race the route's closing animation and produce a red error screen.
class _ProfileEditDialog extends StatefulWidget {
  final String initialName;
  final String initialPhone;

  const _ProfileEditDialog({
    required this.initialName,
    required this.initialPhone,
  });

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _ProfileFormResult(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) => (value == null || value.trim().length < 2)
                    ? 'Enter at least 2 characters'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: 'e.g. 012-345 6789',
                ),
                validator: (value) {
                  final phone = (value ?? '').trim();
                  if (phone.isEmpty) return null;
                  if (!RegExp(r'^\+?[0-9][0-9 ()-]{6,19}$').hasMatch(phone)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label, style: Theme.of(context).textTheme.labelSmall),
          subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }
}
