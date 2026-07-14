import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/management_backend_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AdminManagementSection extends StatefulWidget {
  final ManagementBackendService? backend;

  const AdminManagementSection({super.key, this.backend});

  @override
  State<AdminManagementSection> createState() => _AdminManagementSectionState();
}

class _AdminManagementSectionState extends State<AdminManagementSection> {
  late final ManagementBackendService _backend;
  StreamSubscription<ManagedAdminAccounts>? _accountsSubscription;
  ManagedAdminAccounts? _accounts;
  Object? _loadError;
  bool _loading = true;
  bool _isAdding = false;
  String? _removingUid;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? ManagementBackendService();
    _loadAccounts();
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    super.dispose();
  }

  void _loadAccounts() {
    _accountsSubscription?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    _accountsSubscription = _backend.watchAdminAccounts().listen(
      (accounts) {
        if (!mounted) return;
        setState(() {
          _accounts = accounts;
          _loadError = null;
          _loading = false;
        });
      },
      onError: (Object error) {
        // Surface permission or malformed-data errors with a retry action.
        if (!mounted) return;
        setState(() {
          _loadError = error;
          _loading = false;
        });
      },
    );
  }

  Future<void> _showAddAdminDialog() async {
    final selected = await showDialog<ManagedAdminAccount>(
      context: context,
      builder: (_) => _AdminAccountPickerDialog(backend: _backend),
    );
    if (selected == null || !mounted) return;

    setState(() => _isAdding = true);
    try {
      // The repository re-checks the account inside the promotion transaction.
      await _backend.addAdmin(email: selected.email);
      if (!mounted) return;
      _toast('${selected.name} is now an administrator.');
    } catch (error) {
      if (mounted) _toast('Could not add administrator: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _removeAdmin(ManagedAdminAccount admin) async {
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
      await _backend.removeAdmin(targetUid: admin.uid);
      if (!mounted) return;
      _toast('Removed ${admin.name} from administrators.');
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
              IconButton(
                tooltip: 'Refresh accounts',
                onPressed: _loading ? null : _loadAccounts,
                icon: const Icon(Icons.refresh_rounded),
              ),
              FilledButton.icon(
                onPressed: _loading || _isAdding ? null : _showAddAdminDialog,
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
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  'Could not load current administrators.\n$_loadError',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _loadAccounts,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else
          _AdminList(
            admins: _accounts?.admins ?? const [],
            removingUid: _removingUid,
            onRemove: _removeAdmin,
          ),
      ],
    );
  }
}

class _AdminAccountPickerDialog extends StatefulWidget {
  final ManagementBackendService backend;

  const _AdminAccountPickerDialog({required this.backend});

  @override
  State<_AdminAccountPickerDialog> createState() =>
      _AdminAccountPickerDialogState();
}

class _AdminAccountPickerDialogState extends State<_AdminAccountPickerDialog> {
  final _searchController = TextEditingController();
  ManagedAdminAccount? _result;
  String? _error;
  bool _searching = false;

  Future<void> _search() async {
    final email = _searchController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a complete email address.');
      return;
    }
    setState(() {
      _searching = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await widget.backend.findAdminCandidate(email: email);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _result;

    return AlertDialog(
      title: const Text('Add administrator'),
      content: SizedBox(
        width: 480,
        height: 300,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search by email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('Search'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (account != null)
              ListTile(
                title: Text(account.email),
                subtitle: Text(
                  '${account.name}\nRegistered ${DateFormat.yMMMd().format(account.createdAt)}',
                ),
                trailing: const Icon(Icons.person_add_alt_1_rounded),
                onTap: () => Navigator.of(context).pop(account),
              )
            else
              const Text('Search for an existing active public account.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _AdminList extends StatelessWidget {
  final List<ManagedAdminAccount> admins;
  final String? removingUid;
  final ValueChanged<ManagedAdminAccount> onRemove;

  const _AdminList({
    required this.admins,
    required this.removingUid,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
            const Text('No current administrators have been added.'),
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
        final isRemoving = removingUid == admin.uid;
        return ListTile(
          leading: CircleAvatar(
            child: Text(admin.name.isEmpty ? 'A' : admin.name[0].toUpperCase()),
          ),
          title: Text(admin.name),
          subtitle: Text('${admin.email}\nID ${admin.uid}'),
          isThreeLine: true,
          trailing: IconButton(
            tooltip: 'Remove administrator',
            onPressed: removingUid == null ? () => onRemove(admin) : null,
            icon: isRemoving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.delete_outline_rounded, color: colors.error),
          ),
        );
      },
    );
  }
}
