// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Residential Management';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSave => 'Save';

  @override
  String get loginWelcomeTitle => 'Welcome Back';

  @override
  String get loginWelcomeSubtitle => 'Log in to your secure resident portal';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginButton => 'Secure Login';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginNoAccountQuestion => 'Don\'t have an account?';

  @override
  String get loginSignUpAction => 'Sign Up';

  @override
  String get validationEmailRequired => 'Email is required';

  @override
  String get validationEmailInvalid => 'Enter a valid email address';

  @override
  String get validationPasswordRequired => 'Password is required';

  @override
  String get validationPasswordMinLength =>
      'Password must be at least 12 characters';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacySecurity => 'Privacy & Security';

  @override
  String get settingsHelpCenter => 'Help Center';

  @override
  String get settingsAbout => 'About App';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'Choose what you would like to be notified about.';

  @override
  String get notifPushTitle => 'Push notifications';

  @override
  String get notifPushSubtitle => 'Receive alerts on this device';

  @override
  String get notifEmailTitle => 'Email notifications';

  @override
  String get notifEmailSubtitle => 'Receive important updates by email';

  @override
  String get notifAnnouncementsTitle => 'Community announcements';

  @override
  String get notifAnnouncementsSubtitle => 'News and notices from management';

  @override
  String get notificationsSaved => 'Notification preferences saved';

  @override
  String get privacyTitle => 'Privacy & Security';

  @override
  String get privacySectionAccount => 'Account security';

  @override
  String get privacyChangePassword => 'Change 6-digit PIN';

  @override
  String get privacyChangePasswordSubtitle => 'Update your local app lock PIN';

  @override
  String get privacySendResetEmail => 'Send password reset email';

  @override
  String get privacySendResetEmailSubtitle =>
      'We will email you a secure reset link';

  @override
  String get privacySectionData => 'Your privacy';

  @override
  String get privacyDataNote =>
      'Your data is stored securely and used only to operate the residence portal. We never sell your personal information.';

  @override
  String get changePasswordTitle => 'Change 6-digit PIN';

  @override
  String get currentPasswordLabel => 'Current 6-digit PIN';

  @override
  String get newPasswordLabel => 'New 6-digit PIN';

  @override
  String get confirmPasswordLabel => 'Confirm new 6-digit PIN';

  @override
  String get passwordHelperMinLength => 'Exactly 6 digits';

  @override
  String get changePasswordButton => 'Update PIN';

  @override
  String get validationCurrentPasswordRequired =>
      'Enter your current 6-digit PIN';

  @override
  String get validationConfirmPasswordRequired =>
      'Please confirm your new 6-digit PIN';

  @override
  String get validationPasswordsDoNotMatch => 'PINs do not match';

  @override
  String get passwordChangedSuccess => '6-digit PIN updated successfully';

  @override
  String get resetEmailDialogTitle => 'Send reset email';

  @override
  String get resetEmailDialogBody =>
      'We will send a secure password reset link to your account email. Continue?';

  @override
  String get resetEmailSendAction => 'Send link';

  @override
  String get resetEmailSentSuccess =>
      'Password reset email sent. Please check your inbox.';

  @override
  String get helpTitle => 'Help Center';

  @override
  String get helpIntro =>
      'Find answers to common questions, or contact the management office.';

  @override
  String get helpSectionFaq => 'Frequently asked questions';

  @override
  String get helpSectionContact => 'Contact us';

  @override
  String get helpFaqResetQuestion => 'How do I reset my password?';

  @override
  String get helpFaqResetAnswer =>
      'Open Settings, then Privacy & Security, then Change password. If you are locked out, use \"Forgot password?\" on the login screen to receive a reset link by email.';

  @override
  String get helpFaqApprovalQuestion => 'Why is my account pending approval?';

  @override
  String get helpFaqApprovalAnswer =>
      'Resident accounts are verified by the management office before unit features are unlocked. This usually takes 1 to 2 business days.';

  @override
  String get helpContactEmailLabel => 'Email';

  @override
  String get helpContactPhoneLabel => 'Phone';

  @override
  String get helpOfficeHours => 'Office hours: Mon to Fri, 9:00 AM to 5:00 PM';

  @override
  String get aboutTitle => 'About App';

  @override
  String get aboutDescription =>
      'Secure Residential Management is a private community portal connecting residents with their management office. For assistance, visit the Help Center.';

  @override
  String get aboutCopyright => 'Secure Residential Management';
}
