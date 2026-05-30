import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Generic "Coming soon" placeholder for features not yet built (Phase E
/// builds maintenance; the rest are future work). Pushed as its own route
/// so it gets a back button automatically — no dead-ends (nav hygiene).
class ComingSoonScreen extends StatelessWidget {
  final String title;

  const ComingSoonScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_rounded, size: 72, color: cs.primary),
              const SizedBox(height: AppSpacing.md),
              Text('Coming soon', style: tt.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$title is not available yet.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
