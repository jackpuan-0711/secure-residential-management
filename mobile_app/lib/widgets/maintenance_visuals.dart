import 'package:flutter/material.dart';

import '../models/maintenance_request.dart';
import '../theme/app_theme.dart';

/// Shared presentation helpers for maintenance, so the resident list and the
/// admin queue render category / status identically (one source of truth).

/// Category → (label, icon).
(String, IconData) maintenanceCategoryVisual(MaintenanceCategory c) {
  switch (c) {
    case MaintenanceCategory.plumbing:
      return ('Plumbing', Icons.plumbing_rounded);
    case MaintenanceCategory.electrical:
      return ('Electrical', Icons.electrical_services_rounded);
    case MaintenanceCategory.appliance:
      return ('Appliance', Icons.kitchen_rounded);
    case MaintenanceCategory.commonArea:
      return ('Common area', Icons.deck_rounded);
    case MaintenanceCategory.other:
      return ('Other', Icons.build_rounded);
  }
}

/// Status → (label, colour). Status colours are the project's documented
/// exception to "colours come from Theme.colorScheme" (see AnnouncementsFeed).
(String, Color) maintenanceStatusVisual(MaintenanceStatus s, ColorScheme cs) {
  switch (s) {
    case MaintenanceStatus.pending:
      return ('Pending', AppColors.warning);
    case MaintenanceStatus.inProgress:
      return ('In progress', cs.primary);
    case MaintenanceStatus.resolved:
      return ('Resolved', AppColors.success);
  }
}

/// A compact status pill, used in both the resident list and the admin queue.
class MaintenanceStatusBadge extends StatelessWidget {
  final MaintenanceStatus status;

  const MaintenanceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (label, color) = maintenanceStatusVisual(status, cs);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
