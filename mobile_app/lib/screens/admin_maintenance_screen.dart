import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/maintenance_request.dart';
import '../services/maintenance_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/maintenance_visuals.dart';

/// Admin / superadmin maintenance queue: every resident request, newest first,
/// with inline status control.
///
/// ─── SECURITY ────────────────────────────────────────────────────────────
/// Reaching this screen requires the {role:'admin'|'superadmin'} claim
/// (AuthGate routed the session here). Reads and status writes are independently
/// gated by firestore.rules — only an admin/superadmin claim may read the whole
/// collection or advance a request's status, and the status write is pinned to
/// `handledBy == request.auth.uid`. [handledByUid] is the session uid, threaded
/// through so the audit trail records who acted.
class AdminMaintenanceScreen extends StatefulWidget {
  final String handledByUid;

  /// Injectable for tests; defaults to a live [MaintenanceRepository].
  final MaintenanceRepository? repository;

  const AdminMaintenanceScreen({
    super.key,
    required this.handledByUid,
    this.repository,
  });

  @override
  State<AdminMaintenanceScreen> createState() => _AdminMaintenanceScreenState();
}

class _AdminMaintenanceScreenState extends State<AdminMaintenanceScreen> {
  late final MaintenanceRepository _repo;
  late final Stream<List<MaintenanceRequest>> _stream;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MaintenanceRepository();
    _stream = _repo.watchAllRequests();
  }

  Future<void> _setStatus(
      MaintenanceRequest request, MaintenanceStatus status) async {
    if (status == request.status) return;
    try {
      await _repo.updateStatus(
        requestId: request.id,
        newStatus: status,
        handledByUid: widget.handledByUid,
      );
    } catch (e) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update status: $e'),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance queue')),
      body: SafeArea(
        child: StreamBuilder<List<MaintenanceRequest>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text('Could not load the queue.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.error)),
                ),
              );
            }
            final requests = snapshot.data ?? const <MaintenanceRequest>[];
            if (requests.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.checkCircle,
                          size: 56, color: cs.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text('Nothing in the queue', style: tt.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Resident maintenance requests will appear here.',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              );
            }
            final pending = requests
                .where((r) => r.status == MaintenanceStatus.pending)
                .length;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      left: AppSpacing.xs, bottom: AppSpacing.sm),
                  child: Text(
                    '${requests.length} total · $pending pending',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                for (final r in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _AdminRequestCard(
                      request: r,
                      onStatusSelected: (s) => _setStatus(r, s),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminRequestCard extends StatelessWidget {
  final MaintenanceRequest request;
  final ValueChanged<MaintenanceStatus> onStatusSelected;

  const _AdminRequestCard({
    required this.request,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (categoryLabel, categoryIcon) =
        maintenanceCategoryVisual(request.category);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryIcon, size: 18, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(request.title, style: tt.titleMedium)),
                MaintenanceStatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(AppIcons.unit, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Text('Unit ${request.unitNumber}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(width: AppSpacing.sm),
                Text('· $categoryLabel · '
                    '${DateFormat.yMMMd().format(request.createdAt)}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(request.description, style: tt.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            // Status control. SegmentedButton makes the current state obvious
            // and any transition one tap away.
            SegmentedButton<MaintenanceStatus>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: MaintenanceStatus.pending,
                  label: Text('Pending'),
                ),
                ButtonSegment(
                  value: MaintenanceStatus.inProgress,
                  label: Text('In progress'),
                ),
                ButtonSegment(
                  value: MaintenanceStatus.resolved,
                  label: Text('Resolved'),
                ),
              ],
              selected: {request.status},
              onSelectionChanged: (sel) => onStatusSelected(sel.first),
            ),
          ],
        ),
      ),
    );
  }
}
