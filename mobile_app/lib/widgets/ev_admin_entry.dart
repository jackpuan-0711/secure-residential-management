import 'package:flutter/material.dart';

import '../screens/admin_ev_stations_screen.dart';
import '../services/ev_charging_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// CTA card on the privileged homes that opens EV station management.
class EvAdminEntry extends StatelessWidget {
  /// Injectable for tests; forwarded to the management screen.
  final EvChargingRepository? repository;

  const EvAdminEntry({super.key, this.repository});

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
              builder: (_) => AdminEvStationsScreen(repository: repository),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(AppIcons.evCharging, color: cs.primary, size: 32),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EV stations', style: tt.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Add charging bays and take them in / out of service.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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
