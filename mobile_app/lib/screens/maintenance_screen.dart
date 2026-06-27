import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/maintenance_request.dart';
import '../services/maintenance_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/maintenance_visuals.dart';
import 'submit_maintenance_screen.dart';

/// Resident-facing maintenance: file a request for your unit and track its
/// status (pending → in progress → resolved). All writes flow through
/// [MaintenanceRepository], gated server-side by firestore.rules — a resident
/// can only file for their own verified unit and cannot self-advance status.
class MaintenanceScreen extends StatefulWidget {
  final AppUser user;

  /// Injectable for tests; defaults to a live [MaintenanceRepository].
  final MaintenanceRepository? repository;

  const MaintenanceScreen({super.key, required this.user, this.repository});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late final MaintenanceRepository _repo;
  late final Stream<List<MaintenanceRequest>> _stream;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MaintenanceRepository();
    _stream = _repo.watchMyRequests(widget.user.uid);
  }

  bool get _canFile => (widget.user.unitNumber ?? '').isNotEmpty;

  Future<void> _openComposer() async {
    final filed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubmitMaintenanceScreen(
          residentId: widget.user.uid,
          unitNumber: widget.user.unitNumber ?? '',
          repository: widget.repository,
        ),
      ),
    );
    if (filed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance request submitted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: SafeArea(
        child: !_canFile
            ? _Centered(
                icon: AppIcons.pending,
                title: 'Unit not verified',
                body: 'Maintenance requests are tied to a verified unit. Once '
                    'your residency is approved you can file requests here.',
              )
            : StreamBuilder<List<MaintenanceRequest>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _Centered(
                      icon: Icons.error_outline,
                      title: 'Could not load requests',
                      body: '${snapshot.error}',
                      isError: true,
                    );
                  }
                  final requests =
                      snapshot.data ?? const <MaintenanceRequest>[];
                  if (requests.isEmpty) {
                    return _Centered(
                      icon: AppIcons.maintenanceOutlined,
                      title: 'No requests yet',
                      body: 'Tap “New request” to report an issue in your '
                          'unit. You can track its status here.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: requests.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _RequestCard(request: requests[i]),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: _canFile
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(AppIcons.add),
              label: const Text('New request'),
            )
          : null,
    );
  }
}

class _RequestCard extends StatelessWidget {
  final MaintenanceRequest request;

  const _RequestCard({required this.request});

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
            Text(
              '$categoryLabel · ${DateFormat.yMMMd().format(request.createdAt)}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              request.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium,
            ),
            if (request.status == MaintenanceStatus.resolved &&
                request.resolvedAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Resolved ${DateFormat.yMMMd().format(request.resolvedAt!)}',
                style: tt.labelSmall?.copyWith(color: AppColors.success),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool isError;

  const _Centered({
    required this.icon,
    required this.title,
    required this.body,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56,
                color: isError ? cs.error : cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: tt.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                  color: isError ? cs.error : cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
