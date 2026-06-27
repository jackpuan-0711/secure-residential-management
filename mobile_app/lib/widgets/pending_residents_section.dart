import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pending_residents_list.dart';

/// "Pending Residents" approval queue as a self-contained section
/// (header + live list), shown on both the admin and superadmin homes.
///
/// Behaviour is unchanged from the inline version it replaces — it simply
/// wraps [PendingResidentsList] with its section header so the privileged
/// homes can compose it declaratively. All approval logic (approve / reject /
/// confirm / audit stamp) stays in [PendingResidentsList]; this is layout only.
class PendingResidentsSection extends StatelessWidget {
  const PendingResidentsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text('Pending Residents', style: tt.titleMedium),
        ),
        const PendingResidentsList(),
      ],
    );
  }
}
