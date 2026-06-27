import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/user_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AdminManagementSection extends StatefulWidget {
  final String actorUid;
  final UserRepository? userRepository;

  const AdminManagementSection({
    super.key,
    required this.actorUid,
    this.userRepository,
  });

  @override
  State<AdminManagementSection> createState() => _AdminManagementSectionState();
}

class _AdminManagementSectionState extends State<AdminManagementSection> {
  late final UserRepository _repository;
  late final Stream<List<AppUser>> _admins;
  bool _isAdding = false;
  String? _removingUid;

  @override
  void initState() {
    super.initState();
    _repository = widget.userRepository ?? UserRepository();
    _admins = _repository.listAdmins();
  }

  Future<void> _showAddAdminDialog() async {
    setState(() => _isAdding = true);
    List<AppUser> candidates;
    try {
      candidates = await _repository.listAdminCandidates();
    } catch (error) {
      if (mounted) {
        _toast('Could not load public accounts: $error', isError: true);
      }
      return;
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
    if (!mounted) return;

    if (candidates.isEmpty) {
      _toast('No active public accounts are available to add.');
      return;
    }

    final selected = await showDialog<AppUser>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add administrator'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final user = candidates[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(dialogContext).pop(user),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _isAdding = true);
    try {
      await _repository.addAdmin(
        targetUid: selected.uid,
        approvedByUid: widget.actorUid,
      );
      if (mounted) _toast('Administrator access added.');
    } catch (error) {
      if (mounted) _toast('Could not add administrator: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _removeAdmin(AppUser admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove administrator?'),
        content: Text(
          '${admin.name} will lose all management access and return to a '
          'public account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _removingUid = admin.uid);
    try {
      await _repository.removeAdmin(
        targetUid: admin.uid,
        removedByUid: widget.actorUid,
      );
      if (mounted) _toast('Removed ${admin.name} from administrators.');
    } catch (error) {
      if (mounted) {
        _toast('Could not remove administrator: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _removingUid = null);
    }
  }

  void _toast(String message, {bool isError = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text('Administrators', style: textTheme.titleMedium),
              ),
              FilledButton.icon(
                onPressed: _isAdding ? null : _showAddAdminDialog,
                icon: _isAdding
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        StreamBuilder<List<AppUser>>(
          stream: _admins,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Could not load administrators.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              );
            }

            final admins = snapshot.data ?? const <AppUser>[];
            if (admins.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      AppIcons.accountManagement,
                      size: 48,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('No administrators have been added.'),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: admins.length,
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final admin = admins[index];
                final isRemoving = _removingUid == admin.uid;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      admin.name.isEmpty ? 'A' : admin.name[0].toUpperCase(),
                    ),
                  ),
                  title: Text(admin.name),
                  subtitle: Text(admin.email),
                  trailing: IconButton(
                    tooltip: 'Remove administrator',
                    onPressed: _removingUid == null
                        ? () => _removeAdmin(admin)
                        : null,
                    icon: isRemoving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.delete_outline_rounded,
                            color: colors.error,
                          ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
