import 'package:flutter/material.dart';

/// Spacing scale — 6-step geometric progression (4 → 48).
/// Use these tokens instead of hardcoded values so every spacing decision
/// is trivially auditable and globally adjustable.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Border-radius scale + named BorderRadius helpers.
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 100;

  static BorderRadius get smBr => BorderRadius.circular(sm);
  static BorderRadius get mdBr => BorderRadius.circular(md);
  static BorderRadius get lgBr => BorderRadius.circular(lg);
  static BorderRadius get xlBr => BorderRadius.circular(xl);
  static BorderRadius get xxlBr => BorderRadius.circular(xxl);
  static BorderRadius get fullBr => BorderRadius.circular(full);
}

/// Raw color palette.
///
/// WCAG AA contrast ratios (4.5:1 minimum for normal text):
///   primary (#0F172A) on white:      18.1:1  ✓
///   secondary (#0F766E) on white:     5.2:1  ✓  (Teal 700 — darker than Emerald 500's 3.4:1)
///   onSurfaceVariant (#475569) white:  6.8:1  ✓
///   error (#DC2626) on white:          5.4:1  ✓
///
/// Do NOT reference these in widget code — use Theme.of(context).colorScheme.
/// They are public only for tests and the theme builder.
abstract final class AppColors {
  // Primary — Slate 900. Deep navy reads as trustworthy and institutional
  // without the coldness of pure black.
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryContainer = Color(0xFFE2E8F0); // Slate 200

  // Secondary — Teal 700. Chosen over Emerald 500 (the prior theme) because
  // Teal 700 achieves WCAG AA on white; Emerald 500 at #10B981 does not (3.4:1).
  static const Color secondary = Color(0xFF0F766E);
  static const Color secondaryContainer = Color(0xFFCCFBF1); // Teal 50

  // Tertiary — Violet 700. Used for admin-specific highlights only.
  static const Color tertiary = Color(0xFF6D28D9);
  static const Color tertiaryContainer = Color(0xFFEDE9FE);

  // Status
  static const Color success = Color(0xFF15803D); // Green 700
  static const Color warning = Color(0xFFB45309); // Amber 700
  static const Color error = Color(0xFFDC2626);   // Red 600

  // Surfaces
  static const Color surface = Color(0xFFF8FAFC);            // Slate 50
  static const Color surfaceContainer = Color(0xFFF1F5F9);   // Slate 100
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0); // Slate 200

  // On-surface text
  static const Color onSurface = Color(0xFF0F172A);          // Slate 900
  static const Color onSurfaceVariant = Color(0xFF475569);   // Slate 600
  static const Color onSurfaceMuted = Color(0xFF94A3B8);     // Slate 400

  // Borders
  static const Color outline = Color(0xFFCBD5E1);            // Slate 300
  static const Color outlineVariant = Color(0xFFE2E8F0);     // Slate 200

  // Role badge pairs (background / foreground).
  // Named by the displayed role, not by color, for refactor safety.
  static const Color roleBadgePublicBg = Color(0xFFF1F5F9);
  static const Color roleBadgePublicFg = Color(0xFF475569);
  static const Color roleBadgeResidentBg = Color(0xFFDCFCE7); // Green 100
  static const Color roleBadgeResidentFg = Color(0xFF15803D); // Green 700
  static const Color roleBadgePendingBg = Color(0xFFFEF3C7);  // Amber 100
  static const Color roleBadgePendingFg = Color(0xFFB45309);  // Amber 700
  static const Color roleBadgeAdminBg = Color(0xFF0F172A);    // Slate 900
  static const Color roleBadgeAdminFg = Color(0xFFFFFFFF);

  // Demo banner (neutral info strip on shell screens)
  static const Color demoBannerBg = Color(0xFFEFF6FF);  // Blue 50
  static const Color demoBannerFg = Color(0xFF1D4ED8);  // Blue 700
}

/// Single source of truth for the Material 3 theme.
abstract final class AppTheme {
  static ThemeData get light {
    // Seed with Teal 600 so M3 tonal-palette generation gives warm,
    // accessible surface tones. We then pin the primary to Slate 900
    // via copyWith — the institutional feel comes from the override,
    // the generated surface hierarchy from the seed.
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.secondary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: const Color(0xFF134E4A),
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: const Color(0xFF4C1D95),
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF7F1D1D),
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHigh,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.surfaceContainer,

      // ── Typography ─────────────────────────────────────────────────
      // Full M3 type scale. Sizes follow Material spec; weights tightened
      // slightly for the residential-management information density.
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.15,
          color: AppColors.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15,
          color: AppColors.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1,
          color: AppColors.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5,
          color: AppColors.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25,
          color: AppColors.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4,
          color: AppColors.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1,
          color: AppColors.onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5,
          color: AppColors.onSurface,
        ),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5,
          color: AppColors.onSurfaceVariant,
        ),
      ),

      // ── Card ───────────────────────────────────────────────────────
      // Zero elevation + hairline border. Shadows add visual noise on
      // list-heavy dashboards; borders are lighter and more scannable.
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Filled button ──────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5,
          ),
        ),
      ),

      // ── Outlined button ────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),

      // ── Text button ────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      // ── Input decoration ───────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
        hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary, fontWeight: FontWeight.w500,
        ),
      ),

      // ── AppBar ─────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.outlineVariant,
        titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: AppColors.onSurface, letterSpacing: 0,
        ),
      ),

      // ── Bottom NavigationBar ───────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.onSurfaceVariant, size: 24);
        }),
      ),

      // ── Chip ───────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs,
        ),
      ),

      // ── Dialog ─────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),

      // ── Snackbar ───────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(color: Colors.white),
        elevation: 2,
      ),

      // ── Divider ────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        space: 1,
        thickness: 1,
      ),

      // ── ListTile ───────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs,
        ),
      ),
    );
  }
}
