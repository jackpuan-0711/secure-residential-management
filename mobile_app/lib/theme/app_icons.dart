import 'package:flutter/material.dart';

/// Centralised icon registry.
///
/// Why this exists: if Material changes an icon name, or we switch to a
/// custom icon font, there is exactly one file to edit. Widget code
/// never imports a specific icon name directly — it imports AppIcons.X.
/// This also makes icon usage grep-able: searching for
/// `AppIcons.maintenance` finds every place that feature's icon appears.
abstract final class AppIcons {
  // ── Navigation tabs ──────────────────────────────────────────────
  static const IconData home = Icons.home_rounded;
  static const IconData homeOutlined = Icons.home_outlined;
  static const IconData feedback = Icons.rate_review_rounded;
  static const IconData feedbackOutlined = Icons.rate_review_outlined;
  static const IconData settings = Icons.settings_rounded;
  static const IconData settingsOutlined = Icons.settings_outlined;
  static const IconData profile = Icons.person_rounded;
  static const IconData profileOutlined = Icons.person_outline_rounded;

  // ── Resident feature tiles ───────────────────────────────────────
  static const IconData maintenance = Icons.build_rounded;
  static const IconData maintenanceOutlined = Icons.build_outlined;
  static const IconData announcements = Icons.campaign_rounded;
  static const IconData announcementsOutlined = Icons.campaign_outlined;
  static const IconData securityAlert = Icons.shield_rounded;
  static const IconData securityAlertOutlined = Icons.shield_outlined;
  static const IconData visitorPass = Icons.badge_rounded;
  static const IconData visitorPassOutlined = Icons.badge_outlined;
  static const IconData evCharging = Icons.ev_station_rounded;
  static const IconData evChargingOutlined = Icons.ev_station_outlined;

  // ── Public feature tiles ─────────────────────────────────────────
  static const IconData applyForResident = Icons.how_to_reg_rounded;
  static const IconData communityBulletin = Icons.article_rounded;
  static const IconData communityBulletinOutlined = Icons.article_outlined;

  // ── Admin feature tiles ──────────────────────────────────────────
  static const IconData adminDashboard = Icons.dashboard_rounded;
  static const IconData pendingApplications = Icons.pending_actions_rounded;
  static const IconData accountManagement = Icons.manage_accounts_rounded;
  static const IconData communicationHub = Icons.forum_rounded;
  static const IconData emergencyAlert = Icons.warning_rounded;
  static const IconData userStats = Icons.people_rounded;

  // ── Utility ──────────────────────────────────────────────────────
  static const IconData notifications = Icons.notifications_rounded;
  static const IconData notificationsOutlined = Icons.notifications_outlined;
  static const IconData logout = Icons.logout_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData editOutlined = Icons.edit_outlined;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData verified = Icons.verified_rounded;
  static const IconData pending = Icons.hourglass_top_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_rounded;
  static const IconData info = Icons.info_rounded;
  static const IconData arrowRight = Icons.arrow_forward_ios_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData lockOutlined = Icons.lock_outline_rounded;
  static const IconData email = Icons.email_rounded;
  static const IconData emailOutlined = Icons.email_outlined;
  static const IconData phone = Icons.phone_rounded;
  static const IconData unit = Icons.home_work_rounded;
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData visibility = Icons.visibility_outlined;
  static const IconData visibilityOff = Icons.visibility_off_outlined;
}
