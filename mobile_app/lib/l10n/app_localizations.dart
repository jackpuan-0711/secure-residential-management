import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ms'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Residential Management'**
  String get appTitle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginWelcomeTitle;

  /// No description provided for @loginWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to your secure resident portal'**
  String get loginWelcomeSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Secure Login'**
  String get loginButton;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginNoAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get loginNoAccountQuestion;

  /// No description provided for @loginSignUpAction.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get loginSignUpAction;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get validationPasswordRequired;

  /// No description provided for @validationPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 12 characters'**
  String get validationPasswordMinLength;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSectionSupport;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get settingsPrivacySecurity;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get settingsHelpCenter;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get settingsAbout;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language. The change applies immediately.'**
  String get languageSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageMalay.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Malaysia'**
  String get languageMalay;

  /// No description provided for @languageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get languageUpdated;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what you would like to be notified about.'**
  String get notificationsSubtitle;

  /// No description provided for @notifPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notifPushTitle;

  /// No description provided for @notifPushSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive alerts on this device'**
  String get notifPushSubtitle;

  /// No description provided for @notifEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get notifEmailTitle;

  /// No description provided for @notifEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive important updates by email'**
  String get notifEmailSubtitle;

  /// No description provided for @notifAnnouncementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Community announcements'**
  String get notifAnnouncementsTitle;

  /// No description provided for @notifAnnouncementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'News and notices from management'**
  String get notifAnnouncementsSubtitle;

  /// No description provided for @notificationsSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences saved'**
  String get notificationsSaved;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacyTitle;

  /// No description provided for @privacySectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get privacySectionAccount;

  /// No description provided for @privacyChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get privacyChangePassword;

  /// No description provided for @privacyChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password for your account'**
  String get privacyChangePasswordSubtitle;

  /// No description provided for @privacySendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send password reset email'**
  String get privacySendResetEmail;

  /// No description provided for @privacySendResetEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will email you a secure reset link'**
  String get privacySendResetEmailSubtitle;

  /// No description provided for @privacySectionData.
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get privacySectionData;

  /// No description provided for @privacyDataNote.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored securely and used only to operate the residence portal. We never sell your personal information.'**
  String get privacyDataNote;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordHelperMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 12 characters'**
  String get passwordHelperMinLength;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get changePasswordButton;

  /// No description provided for @validationCurrentPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get validationCurrentPasswordRequired;

  /// No description provided for @validationConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your new password'**
  String get validationConfirmPasswordRequired;

  /// No description provided for @validationPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validationPasswordsDoNotMatch;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get passwordChangedSuccess;

  /// No description provided for @resetEmailDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Send reset email'**
  String get resetEmailDialogTitle;

  /// No description provided for @resetEmailDialogBody.
  ///
  /// In en, this message translates to:
  /// **'We will send a secure password reset link to your account email. Continue?'**
  String get resetEmailDialogBody;

  /// No description provided for @resetEmailSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get resetEmailSendAction;

  /// No description provided for @resetEmailSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Please check your inbox.'**
  String get resetEmailSentSuccess;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpTitle;

  /// No description provided for @helpIntro.
  ///
  /// In en, this message translates to:
  /// **'Find answers to common questions, or contact the management office.'**
  String get helpIntro;

  /// No description provided for @helpSectionFaq.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get helpSectionFaq;

  /// No description provided for @helpSectionContact.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get helpSectionContact;

  /// No description provided for @helpFaqResetQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do I reset my password?'**
  String get helpFaqResetQuestion;

  /// No description provided for @helpFaqResetAnswer.
  ///
  /// In en, this message translates to:
  /// **'Open Settings, then Privacy & Security, then Change password. If you are locked out, use \"Forgot password?\" on the login screen to receive a reset link by email.'**
  String get helpFaqResetAnswer;

  /// No description provided for @helpFaqApprovalQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why is my account pending approval?'**
  String get helpFaqApprovalQuestion;

  /// No description provided for @helpFaqApprovalAnswer.
  ///
  /// In en, this message translates to:
  /// **'Resident accounts are verified by the management office before unit features are unlocked. This usually takes 1 to 2 business days.'**
  String get helpFaqApprovalAnswer;

  /// No description provided for @helpFaqLanguageQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do I change the app language?'**
  String get helpFaqLanguageQuestion;

  /// No description provided for @helpFaqLanguageAnswer.
  ///
  /// In en, this message translates to:
  /// **'Open Settings, then Language, and choose English or Bahasa Malaysia.'**
  String get helpFaqLanguageAnswer;

  /// No description provided for @helpContactEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get helpContactEmailLabel;

  /// No description provided for @helpContactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get helpContactPhoneLabel;

  /// No description provided for @helpOfficeHours.
  ///
  /// In en, this message translates to:
  /// **'Office hours: Mon to Fri, 9:00 AM to 5:00 PM'**
  String get helpOfficeHours;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutTitle;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Secure Residential Management is a private community portal connecting residents with their management office. For assistance, visit the Help Center.'**
  String get aboutDescription;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'Secure Residential Management'**
  String get aboutCopyright;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ms'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ms':
      return AppLocalizationsMs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
