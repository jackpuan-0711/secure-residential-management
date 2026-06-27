import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// Live list of pending resident applicants for the admin / superadmin
/// approval queue.
///
/// Subscribes to [UserRepository.listPendingResidents]. Each row carries
/// Approve / Reject actions; both go through a confirmation dialog before
/// touching Firestore so a mis-tap can't lock a resident out or grant
/// privileges. The audit stamp (`approvedBy` / `rejectedBy`) is the
/// signed-in admin's uid, resolved via [AuthService].
///
/// On success the row vanishes automatically — the underlying query no
/// longer matches once `status` flips off `pending_approval`.
class PendingResidentsList extends StatefulWidget {
  final UserRepository? userRepository;
  final AuthService? authService;

  const PendingResidentsList({
    super.key,
    this.userRepository,
    this.authService,
  });

  @override
  State<PendingResidentsList> createState() => _PendingResidentsListState();
}

class _PendingResidentsListState extends State<PendingResidentsList> {
  late final UserRepository _repo;
  late final AuthService _auth;
  late final Stream<List<AppUser>> _stream;

  @override
  void initState() {
    super.initState();
    _repo = widget.userRepository ?? UserRepository();
    _auth = widget.authService ?? AuthService();
    // Cache the stream so parent rebuilds don't re-subscribe (which
    // would set up a fresh Firestore snapshot listener each time).
    _stream = _repo.listPendingResidents();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error);
        }
        final pending = snapshot.data ?? const <AppUser>[];
        if (pending.isEmpty) {
          return const _EmptyState();
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: pending.length,
          separatorBuilder: (_, _) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final user = pending[index];
            return _PendingRow(
              user: user,
              onApprove: () => _approve(user),
              onReject: () => _reject(user),
            );
          },
        );
      },
    );
  }

  Future<void> _approve(AppUser user) async {
    final confirmed = await _confirm(
      title: 'Approve resident?',
      message:
          'Promote ${user.name} to a verified resident of '
          '${user.requestedUnit ?? "—"}. This grants unit-scoped privileges.',
      actionLabel: 'Approve',
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    try {
      final approverUid = _auth.currentUser?.uid;
      if (approverUid == null) {
        throw const UserRepositoryException('Please sign in again.');
      }
      await _repo.approveResident(
        targetUid: user.uid,
        approvedByUid: approverUid,
      );
      if (mounted) _toast('Approved ${user.name}.');
    } catch (e) {
      if (mounted) _toast('Approval failed: $e', isError: true);
    }
  }

  Future<void> _reject(AppUser user) async {
    final confirmed = await _confirm(
      title: 'Reject resident claim?',
      message:
          '${user.name} will be downgraded to a public account. Their unit '
          'claim (${user.requestedUnit ?? "none"}) will be discarded. They '
          'can still use general features but lose unit-scoped access.',
      actionLabel: 'Reject',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      final approverUid = _auth.currentUser?.uid;
      if (approverUid == null) {
        throw const UserRepositoryException('Please sign in again.');
      }
      await _repo.rejectAsPublic(
        targetUid: user.uid,
        rejectedByUid: approverUid,
      );
      if (mounted) _toast('Rejected ${user.name}.');
    } catch (e) {
      if (mounted) _toast('Rejection failed: $e', isError: true);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    required bool destructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _toast(String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? cs.error : null),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final AppUser user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingRow({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: tt.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Unit ${user.requestedUnit ?? "—"} · ${user.email}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  'Requested ${_formatDate(user.createdAt)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Reject',
            onPressed: onReject,
            icon: Icon(Icons.close, color: cs.error),
          ),
          IconButton(
            tooltip: 'Approve',
            onPressed: onApprove,
            icon: Icon(Icons.check, color: cs.primary),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.pending, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No pending residents.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: cs.error),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Could not load pending residents.',
            style: tt.bodyMedium?.copyWith(color: cs.error),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
