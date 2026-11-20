// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تدرّج';

  @override
  String get navToday => 'اليوم';

  @override
  String get navGoals => 'الأهداف';

  @override
  String get navCalendar => 'التقويم';

  @override
  String get navProgress => 'التقدّم';

  @override
  String get navQuran => 'مصحفي';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get placeholderMessage => 'الشاشة جاهزة للمرحلة القادمة.';

  @override
  String get connectedStatus => 'متصل بقاعدة البيانات';

  @override
  String get errorMissingKeys => 'إعدادات ناقصة: مفاتيح الاتصال غير متوفرة.';

  @override
  String get errorGeneric => 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';

  @override
  String get onboardingTitle1 => 'تقدّم على مهلك وبثبات';

  @override
  String get onboardingDesc1 => 'ينظّم تطبيق تدرّج قراءتك وحفظك ومراجعتك للقرآن الكريم خطوة بخطوة، بكل سكينة ودون أي ضغط.';

  @override
  String get onboardingTitle2 => 'اختر لغتك';

  @override
  String get onboardingDesc2 => 'يمكنك تغيير هذا الخيار في أي وقت من إعدادات التطبيق.';

  @override
  String get onboardingTitle3 => 'هل أنت مستعد للبدء؟';

  @override
  String get onboardingDesc3 => 'أنشئ مساحتك الخاصة لحفظ تقدّمك ومتابعة وردك اليومي.';

  @override
  String get nextButton => 'التالي';

  @override
  String get startButton => 'ابدأ الآن';

  @override
  String get authLoginTitle => 'تسجيل الدخول';

  @override
  String get authSignupTitle => 'إنشاء حساب جديد';

  @override
  String get authResetTitle => 'نسيت كلمة المرور';

  @override
  String get nameLabel => 'الاسم الكريم';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get loginButton => 'دخول';

  @override
  String get signupButton => 'إنشاء حسابي';

  @override
  String get sendResetButton => 'إرسال رابط استعادة كلمة المرور';

  @override
  String get forgotPasswordLink => 'هل نسيت كلمة المرور؟';

  @override
  String get noAccountLink => 'ليس لديك حساب؟ سجّل الآن';

  @override
  String get hasAccountLink => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get backToLoginLink => 'العودة لتسجيل الدخول';

  @override
  String get resetEmailSent => 'إذا كان البريد مسجلاً لدينا، فقد تم إرسال رابط استعادة كلمة المرور.';

  @override
  String get signupSuccessCheckEmail => 'تم إنشاء الحساب بنجاح! تفقد بريدك الإلكتروني أو سجّل الدخول مباشرة.';

  @override
  String get logoutButton => 'تسجيل الخروج';

  @override
  String get errInvalidCredentials => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errEmailAlreadyUsed => 'هذا البريد الإلكتروني مستخدم بالفعل.';

  @override
  String get errWeakPassword => 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.';

  @override
  String get errInvalidEmail => 'يرجى إدخال بريد إلكتروني صحيح.';

  @override
  String get errNetwork => 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.';

  @override
  String get errEmptyFields => 'يرجى تعبئة جميع الحقول المطلوبة.';

  @override
  String get newGoalButton => 'هدف جديد';

  @override
  String get createGoalTitle => 'إنشاء هدف قرآني';

  @override
  String get goalTypeLabel => 'نوع الهدف';

  @override
  String get goalTypeReading => 'تلاوة';

  @override
  String get goalTypeMemorization => 'حفظ';

  @override
  String get goalTypeRevision => 'مراجعة';

  @override
  String get goalTitleLabel => 'عنوان الهدف';

  @override
  String get goalTitleHint => 'مثال: ختمة تلاوة كاملة';

  @override
  String get startPageLabel => 'صفحة البداية (1 إلى 604)';

  @override
  String get endPageLabel => 'صفحة النهاية (1 إلى 604)';

  @override
  String get durationDaysLabel => 'المدة المطلوبة (بالأيام)';

  @override
  String get saveGoalButton => 'إنشاء برنامجي';

  @override
  String get noGoalsYet => 'لا يوجد هدف نشط حالياً.';

  @override
  String get noGoalsDesc => 'اضغط على «هدف جديد» لتخطيط وردك القرآني خطوة بخطوة.';

  @override
  String pagesCountSummary(int count, String perDay) {
    return '$count صفحة إجمالاً • بمعدل $perDay صفحة يومياً';
  }

  @override
  String goalProgressText(int start, int end, int days) {
    return 'من صفحة $start إلى $end • $days يوماً';
  }

  @override
  String get errInvalidPages => 'يرجى اختيار صفحات صحيحة بين 1 و 604.';

  @override
  String get errInvalidDuration => 'يجب أن تكون المدة يوماً واحداً على الأقل.';

  @override
  String get todayGreeting => 'ورد اليوم';

  @override
  String get noTasksTodayTitle => 'لا يوجد ورد مجدول لليوم';

  @override
  String get noTasksTodayDesc => 'أنشئ هدفاً في تبويب «الأهداف» لتوليد برنامجك اليومي.';

  @override
  String get markDoneButton => 'إتمام الورد';

  @override
  String get completedBadge => 'مكتمل';

  @override
  String todayPagesRange(int start, int end) {
    return 'من صفحة $start إلى $end';
  }

  @override
  String get allDoneTodayMessage => 'ما شاء الله! أتممت جميع أورادك لهذا اليوم.';

  @override
  String get calendarSessionsForDay => 'أوراد هذا اليوم';

  @override
  String get calendarNoSessionForDay => 'لا يوجد ورد مجدول في هذا التاريخ.';

  @override
  String get plannedBadge => 'مجدول';

  @override
  String get todayShortcutButton => 'اليوم';

  @override
  String get progressOverviewTitle => 'نظرة عامة';

  @override
  String get progressPagesCompleted => 'الصفحات المنجزة';

  @override
  String get progressSessionsCompleted => 'الجلسات المكتملة';

  @override
  String get progressGoalsSectionTitle => 'التقدّم حسب الهدف';

  @override
  String get progressNoDataYet => 'لا توجد بيانات تقدّم بعد.';

  @override
  String get progressNoDataDesc => 'أتمّ وردك الأول في تبويب «اليوم» لمشاهدة إحصائياتك.';

  @override
  String progressGoalDetail(int done, int total, int percent) {
    return '$done / $total صفحة ($percent%)';
  }

  @override
  String get quranSearchHint => 'ابحث باسم السورة أو رقمها...';

  @override
  String get quranGoToPageHint => 'الصفحة (1-604)';

  @override
  String get quranOpenButton => 'فتح';

  @override
  String quranPageLabel(int page) {
    return 'صفحة $page / 604';
  }

  @override
  String get quranPrevPage => 'الصفحة السابقة';

  @override
  String get quranNextPage => 'الصفحة التالية';

  @override
  String get settingsAccountSection => 'الحساب';

  @override
  String get settingsLanguageSection => 'لغة التطبيق';

  @override
  String get settingsAboutSection => 'حول التطبيق';

  @override
  String get settingsVersionLabel => 'الإصدار 1.0.0 • رفيقك الهادئ مع القرآن الكريم';

  @override
  String get reviewNeedsConsolidationButton => 'يحتاج تثبيتاً';

  @override
  String get reviewFluentButton => 'متقن';

  @override
  String reviewScheduledFeedback(int days) {
    return 'تمت جدولة المراجعة المتباعدة بعد $days يوم/أيام.';
  }

  @override
  String get errFreeLimitReached => 'وصلت للحد المجاني: أرشف هدفاً حالياً لإنشاء هدف جديد.';
}
