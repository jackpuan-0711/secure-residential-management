import 'package:flutter/material.dart';

import '../screens/admin_maintenance_screen.dart';
import '../services/maintenance_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// CTA card on the privileged homes that opens the maintenance queue.
///
/// [handledByUid] is the session uid (from the AuthIdentity AuthGate routed on),
/// threaded to [AdminMaintenanceScreen] so a status change records who acted —
/// matching the rule's `handledBy == request.auth.uid` pin.
class MaintenanceAdminEntry extends StatelessWidget {
  final String handledByUid;

  /// Injectable for tests; forwarded to the queue screen.
  final MaintenanceRepository? repository;

  const MaintenanceAdminEntry({
    super.key,
    required this.handledByUid,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: InkWell(
          borderRadius: AppRadius.xlBr,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminMaintenanceScreen(
                handledByUid: handledByUid,
                repository: repository,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(AppIcons.maintenance, color: cs.primary, size: 32),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Maintenance queue', style: tt.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Review resident requests and update their status.',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.arrowRight, size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
