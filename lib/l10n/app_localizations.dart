import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TADARRUJ'**
  String get appTitle;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get navGoals;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// No description provided for @navQuran.
  ///
  /// In en, this message translates to:
  /// **'My Quran'**
  String get navQuran;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @placeholderMessage.
  ///
  /// In en, this message translates to:
  /// **'Screen ready for the next step.'**
  String get placeholderMessage;

  /// No description provided for @connectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected to Supabase'**
  String get connectedStatus;

  /// No description provided for @errorMissingKeys.
  ///
  /// In en, this message translates to:
  /// **'Missing configuration: Supabase keys not provided.'**
  String get errorMissingKeys;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorGeneric;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Progress at your own pace'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'TADARRUJ organizes your Quran reading, memorization, and spaced reviews step by step, peacefully and without guilt.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'You can change this setting at any time in the application settings.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Ready to begin?'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Create your personal space to save your progress and access your daily schedule.'**
  String get onboardingDesc3;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

  /// No description provided for @startButton.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get startButton;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginTitle;

  /// No description provided for @authSignupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authSignupTitle;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'First name or display name'**
  String get nameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @signupButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signupButton;

  /// No description provided for @sendResetButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetButton;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @noAccountLink.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Sign up'**
  String get noAccountLink;

  /// No description provided for @hasAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get hasAccountLink;

  /// No description provided for @backToLoginLink.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToLoginLink;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this address, a password reset email has been sent.'**
  String get resetEmailSent;

  /// No description provided for @signupSuccessCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Account created! Check your inbox if confirmation is required, or sign in.'**
  String get signupSuccessCheckEmail;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logoutButton;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email address or password.'**
  String get errInvalidCredentials;

  /// No description provided for @errEmailAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This email address is already registered.'**
  String get errEmailAlreadyUsed;

  /// No description provided for @errWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters long.'**
  String get errWeakPassword;

  /// No description provided for @errInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errInvalidEmail;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Please check your internet connection.'**
  String get errNetwork;

  /// No description provided for @errEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields.'**
  String get errEmptyFields;

  /// No description provided for @newGoalButton.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get newGoalButton;

  /// No description provided for @createGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a goal'**
  String get createGoalTitle;

  /// No description provided for @goalTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal type'**
  String get goalTypeLabel;

  /// No description provided for @goalTypeReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get goalTypeReading;

  /// No description provided for @goalTypeMemorization.
  ///
  /// In en, this message translates to:
  /// **'Memorization'**
  String get goalTypeMemorization;

  /// No description provided for @goalTypeRevision.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get goalTypeRevision;

  /// No description provided for @goalTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal title'**
  String get goalTitleLabel;

  /// No description provided for @goalTitleHint.
  ///
  /// In en, this message translates to:
  /// **'E.g., Complete Quran reading'**
  String get goalTitleHint;

  /// No description provided for @startPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Start page (1 to 604)'**
  String get startPageLabel;

  /// No description provided for @endPageLabel.
  ///
  /// In en, this message translates to:
  /// **'End page (1 to 604)'**
  String get endPageLabel;

  /// No description provided for @durationDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Desired duration (in days)'**
  String get durationDaysLabel;

  /// No description provided for @saveGoalButton.
  ///
  /// In en, this message translates to:
  /// **'Generate my schedule'**
  String get saveGoalButton;

  /// No description provided for @noGoalsYet.
  ///
  /// In en, this message translates to:
  /// **'No active goals yet.'**
  String get noGoalsYet;

  /// No description provided for @noGoalsDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New goal\" to plan your journey step by step.'**
  String get noGoalsDesc;

  /// No description provided for @pagesCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} pages total • approx. {perDay} page(s) per day'**
  String pagesCountSummary(int count, String perDay);

  /// No description provided for @goalProgressText.
  ///
  /// In en, this message translates to:
  /// **'Pages {start} to {end} • {days} days'**
  String goalProgressText(int start, int end, int days);

  /// No description provided for @errInvalidPages.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid pages between 1 and 604 (start ≤ end).'**
  String get errInvalidPages;

  /// No description provided for @errInvalidDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration must be at least 1 day.'**
  String get errInvalidDuration;

  /// No description provided for @todayGreeting.
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule'**
  String get todayGreeting;

  /// No description provided for @noTasksTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions scheduled for today'**
  String get noTasksTodayTitle;

  /// No description provided for @noTasksTodayDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a goal in the \"Goals\" tab to generate your daily schedule.'**
  String get noTasksTodayDesc;

  /// No description provided for @markDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Complete session'**
  String get markDoneButton;

  /// No description provided for @completedBadge.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedBadge;

  /// No description provided for @todayPagesRange.
  ///
  /// In en, this message translates to:
  /// **'Page {start} to {end}'**
  String todayPagesRange(int start, int end);

  /// No description provided for @allDoneTodayMessage.
  ///
  /// In en, this message translates to:
  /// **'Masha\'Allah! All of today\'s sessions are completed.'**
  String get allDoneTodayMessage;

  /// No description provided for @calendarSessionsForDay.
  ///
  /// In en, this message translates to:
  /// **'Sessions scheduled for this day'**
  String get calendarSessionsForDay;

  /// No description provided for @calendarNoSessionForDay.
  ///
  /// In en, this message translates to:
  /// **'No sessions scheduled for this date.'**
  String get calendarNoSessionForDay;

  /// No description provided for @plannedBadge.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get plannedBadge;

  /// No description provided for @todayShortcutButton.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayShortcutButton;

  /// No description provided for @progressOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get progressOverviewTitle;

  /// No description provided for @progressPagesCompleted.
  ///
  /// In en, this message translates to:
  /// **'Pages completed'**
  String get progressPagesCompleted;

  /// No description provided for @progressSessionsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sessions completed'**
  String get progressSessionsCompleted;

  /// No description provided for @progressGoalsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress by goal'**
  String get progressGoalsSectionTitle;

  /// No description provided for @progressNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No progress data yet.'**
  String get progressNoDataYet;

  /// No description provided for @progressNoDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete your first session in the \"Today\" tab to see your statistics grow.'**
  String get progressNoDataDesc;

  /// No description provided for @progressGoalDetail.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} pages ({percent}%)'**
  String progressGoalDetail(int done, int total, int percent);

  /// No description provided for @quranSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a surah or number...'**
  String get quranSearchHint;

  /// No description provided for @quranGoToPageHint.
  ///
  /// In en, this message translates to:
  /// **'Page (1-604)'**
  String get quranGoToPageHint;

  /// No description provided for @quranOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get quranOpenButton;

  /// No description provided for @quranPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {page} / 604'**
  String quranPageLabel(int page);

  /// No description provided for @quranPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get quranPrevPage;

  /// No description provided for @quranNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get quranNextPage;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Application language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0 • Peaceful Quran companion'**
  String get settingsVersionLabel;

  /// No description provided for @reviewNeedsConsolidationButton.
  ///
  /// In en, this message translates to:
  /// **'Consolidate'**
  String get reviewNeedsConsolidationButton;

  /// No description provided for @reviewFluentButton.
  ///
  /// In en, this message translates to:
  /// **'Fluent'**
  String get reviewFluentButton;

  /// No description provided for @reviewScheduledFeedback.
  ///
  /// In en, this message translates to:
  /// **'Spaced review scheduled in {days} day(s).'**
  String reviewScheduledFeedback(int days);

  /// No description provided for @errFreeLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Free plan limit reached: archive or delete an active goal to create a new one.'**
  String get errFreeLimitReached;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
