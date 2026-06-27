import 'package:flutter/material.dart';

import '../screens/admin_visitor_scanner_screen.dart';
import '../services/visitor_repository.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// CTA card on privileged homes that opens the visitor QR scanner.
class VisitorAdminEntry extends StatelessWidget {
  final String staffId;
  final VisitorRepository? repository;

  const VisitorAdminEntry({super.key, required this.staffId, this.repository});

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
              builder: (_) => AdminVisitorScannerScreen(
                staffId: staffId,
                repository: repository,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: cs.primary,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visitor QR scanner', style: tt.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Validate resident-issued visitor passes and check guests in or out.',
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
