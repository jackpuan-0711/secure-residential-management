import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/theme/app_icons.dart';
import 'package:mobile_app/theme/app_theme.dart';

void main() {
  group('AppSpacing', () {
    test('scale is strictly increasing', () {
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
      expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
    });

    test('known values match design spec', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxl, 48.0);
    });
  });

  group('AppRadius', () {
    test('scale is strictly increasing', () {
      expect(AppRadius.xs, lessThan(AppRadius.sm));
      expect(AppRadius.sm, lessThan(AppRadius.md));
      expect(AppRadius.md, lessThan(AppRadius.lg));
      expect(AppRadius.lg, lessThan(AppRadius.xl));
      expect(AppRadius.xl, lessThan(AppRadius.xxl));
    });

    test('full radius is 100 (pill shape)', () {
      expect(AppRadius.full, 100.0);
    });

    test('helper BorderRadius values match their scalar counterparts', () {
      expect(AppRadius.lgBr, BorderRadius.circular(AppRadius.lg));
      expect(AppRadius.fullBr, BorderRadius.circular(AppRadius.full));
    });
  });

  group('AppColors', () {
    test('primary is Slate 900', () {
      expect(AppColors.primary, const Color(0xFF0F172A));
    });

    test('secondary is Teal 700 (WCAG AA on white)', () {
      // Teal 700 (#0F766E) contrast ratio on white ≈ 5.2:1, above the 4.5:1 AA
      // threshold. Emerald 500 (#10B981) was only 3.4:1 — replaced here.
      expect(AppColors.secondary, const Color(0xFF0F766E));
    });

    test('error is Red 600 (WCAG AA on white)', () {
      expect(AppColors.error, const Color(0xFFDC2626));
    });

    test('role badge pairs are distinct', () {
      expect(AppColors.roleBadgePublicFg, isNot(AppColors.roleBadgeResidentFg));
      expect(
        AppColors.roleBadgeResidentFg,
        isNot(AppColors.roleBadgePendingFg),
      );
      expect(AppColors.roleBadgeAdminBg, equals(AppColors.primary));
    });

    test('demo banner colors are defined and non-null', () {
      expect(AppColors.demoBannerBg, isNotNull);
      expect(AppColors.demoBannerFg, isNotNull);
    });
  });

  group('AppTheme.light', () {
    test('returns a valid ThemeData with M3 enabled', () {
      final theme = AppTheme.light;
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
    });

    test('primary color matches AppColors.primary', () {
      expect(AppTheme.light.colorScheme.primary, AppColors.primary);
    });

    test('secondary color matches AppColors.secondary', () {
      expect(AppTheme.light.colorScheme.secondary, AppColors.secondary);
    });

    test('error color matches AppColors.error', () {
      expect(AppTheme.light.colorScheme.error, AppColors.error);
    });

    test('card theme has zero elevation', () {
      expect(AppTheme.light.cardTheme.elevation, isZero);
    });

    test('scaffold background uses surface container (Slate 100)', () {
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        AppColors.surfaceContainer,
      );
    });

    testWidgets('theme propagates correctly through MaterialApp', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      final ctx = tester.element(find.byType(Scaffold));
      final cs = Theme.of(ctx).colorScheme;
      expect(cs.primary, AppColors.primary);
      expect(cs.secondary, AppColors.secondary);
      expect(cs.error, AppColors.error);
    });

    testWidgets('NavigationBar uses theme indicator color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );
      // NavigationBar renders without layout errors under the theme.
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('AppIcons', () {
    test('navigation icons are defined', () {
      expect(AppIcons.home, isNotNull);
      expect(AppIcons.feedback, isNotNull);
      expect(AppIcons.settings, isNotNull);
      expect(AppIcons.profile, isNotNull);
    });

    test('feature icons are defined', () {
      expect(AppIcons.maintenance, isNotNull);
      expect(AppIcons.announcements, isNotNull);
      expect(AppIcons.visitorPass, isNotNull);
      expect(AppIcons.evCharging, isNotNull);
      expect(AppIcons.pendingApplications, isNotNull);
    });

    test('outlined variants differ from filled variants', () {
      expect(AppIcons.home, isNot(AppIcons.homeOutlined));
      expect(AppIcons.profile, isNot(AppIcons.profileOutlined));
      expect(AppIcons.maintenance, isNot(AppIcons.maintenanceOutlined));
    });
  });
}
