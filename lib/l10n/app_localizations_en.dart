// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TADARRUJ';

  @override
  String get navToday => 'Today';

  @override
  String get navGoals => 'Goals';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navProgress => 'Progress';

  @override
  String get navQuran => 'My Quran';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get placeholderMessage => 'Screen ready for the next step.';

  @override
  String get connectedStatus => 'Connected to Supabase';

  @override
  String get errorMissingKeys => 'Missing configuration: Supabase keys not provided.';

  @override
  String get errorGeneric => 'An unexpected error occurred. Please try again.';

  @override
  String get onboardingTitle1 => 'Progress at your own pace';

  @override
  String get onboardingDesc1 => 'TADARRUJ organizes your Quran reading, memorization, and spaced reviews step by step, peacefully and without guilt.';

  @override
  String get onboardingTitle2 => 'Choose your language';

  @override
  String get onboardingDesc2 => 'You can change this setting at any time in the application settings.';

  @override
  String get onboardingTitle3 => 'Ready to begin?';

  @override
  String get onboardingDesc3 => 'Create your personal space to save your progress and access your daily schedule.';

  @override
  String get nextButton => 'Next';

  @override
  String get startButton => 'Get started';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authSignupTitle => 'Create an account';

  @override
  String get authResetTitle => 'Reset password';

  @override
  String get nameLabel => 'First name or display name';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get signupButton => 'Create account';

  @override
  String get sendResetButton => 'Send reset link';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get noAccountLink => 'No account yet? Sign up';

  @override
  String get hasAccountLink => 'Already have an account? Sign in';

  @override
  String get backToLoginLink => 'Back to sign in';

  @override
  String get resetEmailSent => 'If an account exists for this address, a password reset email has been sent.';

  @override
  String get signupSuccessCheckEmail => 'Account created! Check your inbox if confirmation is required, or sign in.';

  @override
  String get logoutButton => 'Sign out';

  @override
  String get errInvalidCredentials => 'Incorrect email address or password.';

  @override
  String get errEmailAlreadyUsed => 'This email address is already registered.';

  @override
  String get errWeakPassword => 'Password must be at least 6 characters long.';

  @override
  String get errInvalidEmail => 'Please enter a valid email address.';

  @override
  String get errNetwork => 'Unable to reach the server. Please check your internet connection.';

  @override
  String get errEmptyFields => 'Please fill in all required fields.';

  @override
  String get newGoalButton => 'New goal';

  @override
  String get createGoalTitle => 'Create a goal';

  @override
  String get goalTypeLabel => 'Goal type';

  @override
  String get goalTypeReading => 'Reading';

  @override
  String get goalTypeMemorization => 'Memorization';

  @override
  String get goalTypeRevision => 'Revision';

  @override
  String get goalTitleLabel => 'Goal title';

  @override
  String get goalTitleHint => 'E.g., Complete Quran reading';

  @override
  String get startPageLabel => 'Start page (1 to 604)';

  @override
  String get endPageLabel => 'End page (1 to 604)';

  @override
  String get durationDaysLabel => 'Desired duration (in days)';

  @override
  String get saveGoalButton => 'Generate my schedule';

  @override
  String get noGoalsYet => 'No active goals yet.';

  @override
  String get noGoalsDesc => 'Tap \"New goal\" to plan your journey step by step.';

  @override
  String pagesCountSummary(int count, String perDay) {
    return '$count pages total • approx. $perDay page(s) per day';
  }

  @override
  String goalProgressText(int start, int end, int days) {
    return 'Pages $start to $end • $days days';
  }

  @override
  String get errInvalidPages => 'Please enter valid pages between 1 and 604 (start ≤ end).';

  @override
  String get errInvalidDuration => 'Duration must be at least 1 day.';

  @override
  String get todayGreeting => 'Today\'s schedule';

  @override
  String get noTasksTodayTitle => 'No sessions scheduled for today';

  @override
  String get noTasksTodayDesc => 'Create a goal in the \"Goals\" tab to generate your daily schedule.';

  @override
  String get markDoneButton => 'Complete session';

  @override
  String get completedBadge => 'Completed';

  @override
  String todayPagesRange(int start, int end) {
    return 'Page $start to $end';
  }

  @override
  String get allDoneTodayMessage => 'Masha\'Allah! All of today\'s sessions are completed.';

  @override
  String get calendarSessionsForDay => 'Sessions scheduled for this day';

  @override
  String get calendarNoSessionForDay => 'No sessions scheduled for this date.';

  @override
  String get plannedBadge => 'Planned';

  @override
  String get todayShortcutButton => 'Today';

  @override
  String get progressOverviewTitle => 'Overview';

  @override
  String get progressPagesCompleted => 'Pages completed';

  @override
  String get progressSessionsCompleted => 'Sessions completed';

  @override
  String get progressGoalsSectionTitle => 'Progress by goal';

  @override
  String get progressNoDataYet => 'No progress data yet.';

  @override
  String get progressNoDataDesc => 'Complete your first session in the \"Today\" tab to see your statistics grow.';

  @override
  String progressGoalDetail(int done, int total, int percent) {
    return '$done / $total pages ($percent%)';
  }

  @override
  String get quranSearchHint => 'Search a surah or number...';

  @override
  String get quranGoToPageHint => 'Page (1-604)';

  @override
  String get quranOpenButton => 'Open';

  @override
  String quranPageLabel(int page) {
    return 'Page $page / 604';
  }

  @override
  String get quranPrevPage => 'Previous page';

  @override
  String get quranNextPage => 'Next page';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsLanguageSection => 'Application language';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsVersionLabel => 'Version 1.0.0 • Peaceful Quran companion';

  @override
  String get reviewNeedsConsolidationButton => 'Consolidate';

  @override
  String get reviewFluentButton => 'Fluent';

  @override
  String reviewScheduledFeedback(int days) {
    return 'Spaced review scheduled in $days day(s).';
  }

  @override
  String get errFreeLimitReached => 'Free plan limit reached: archive or delete an active goal to create a new one.';
}
