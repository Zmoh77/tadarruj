// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'TADARRUJ';

  @override
  String get navToday => 'Aujourd\'hui';

  @override
  String get navGoals => 'Objectifs';

  @override
  String get navCalendar => 'Calendrier';

  @override
  String get navProgress => 'Progression';

  @override
  String get navQuran => 'Mon Coran';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get placeholderMessage => 'Écran prêt pour la prochaine étape.';

  @override
  String get connectedStatus => 'Connecté à Supabase';

  @override
  String get errorMissingKeys => 'Configuration manquante : clés Supabase non fournies.';

  @override
  String get errorGeneric => 'Une erreur inattendue est survenue. Veuillez réessayer.';

  @override
  String get onboardingTitle1 => 'Avancez à votre rythme';

  @override
  String get onboardingDesc1 => 'TADARRUJ organise votre lecture, votre mémorisation et vos révisions du Coran étape par étape, avec sérénité et sans jamais vous culpabiliser.';

  @override
  String get onboardingTitle2 => 'Choisissez votre langue';

  @override
  String get onboardingDesc2 => 'Vous pourrez modifier ce choix à tout moment dans les paramètres de l\'application.';

  @override
  String get onboardingTitle3 => 'Prêt à commencer ?';

  @override
  String get onboardingDesc3 => 'Créez votre espace personnel pour sauvegarder votre progression et retrouver votre programme chaque jour.';

  @override
  String get nextButton => 'Suivant';

  @override
  String get startButton => 'Commencer';

  @override
  String get authLoginTitle => 'Connexion';

  @override
  String get authSignupTitle => 'Créer un compte';

  @override
  String get authResetTitle => 'Mot de passe oublié';

  @override
  String get nameLabel => 'Prénom ou nom';

  @override
  String get emailLabel => 'Adresse e-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get signupButton => 'Créer mon compte';

  @override
  String get sendResetButton => 'Envoyer le lien de réinitialisation';

  @override
  String get forgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get noAccountLink => 'Pas encore de compte ? S\'inscrire';

  @override
  String get hasAccountLink => 'Déjà un compte ? Se connecter';

  @override
  String get backToLoginLink => 'Retour à la connexion';

  @override
  String get resetEmailSent => 'Si un compte existe avec cette adresse, un e-mail de réinitialisation vient d\'être envoyé.';

  @override
  String get signupSuccessCheckEmail => 'Compte créé ! Vérifiez votre boîte e-mail si une confirmation est requise, ou connectez-vous.';

  @override
  String get logoutButton => 'Se déconnecter';

  @override
  String get errInvalidCredentials => 'Adresse e-mail ou mot de passe incorrect.';

  @override
  String get errEmailAlreadyUsed => 'Cette adresse e-mail est déjà utilisée par un compte.';

  @override
  String get errWeakPassword => 'Le mot de passe doit contenir au moins 6 caractères.';

  @override
  String get errInvalidEmail => 'Veuillez saisir une adresse e-mail valide.';

  @override
  String get errNetwork => 'Impossible de joindre le serveur. Vérifiez votre connexion internet.';

  @override
  String get errEmptyFields => 'Veuillez remplir tous les champs obligatoires.';

  @override
  String get newGoalButton => 'Nouvel objectif';

  @override
  String get createGoalTitle => 'Créer un objectif';

  @override
  String get goalTypeLabel => 'Type d\'objectif';

  @override
  String get goalTypeReading => 'Lecture';

  @override
  String get goalTypeMemorization => 'Mémorisation';

  @override
  String get goalTypeRevision => 'Révision';

  @override
  String get goalTitleLabel => 'Titre de l\'objectif';

  @override
  String get goalTitleHint => 'Ex : Lecture complète du Coran';

  @override
  String get startPageLabel => 'Page de début (1 à 604)';

  @override
  String get endPageLabel => 'Page de fin (1 à 604)';

  @override
  String get durationDaysLabel => 'Durée souhaitée (en jours)';

  @override
  String get saveGoalButton => 'Générer mon programme';

  @override
  String get noGoalsYet => 'Aucun objectif actif pour le moment.';

  @override
  String get noGoalsDesc => 'Appuyez sur « Nouvel objectif » pour planifier votre parcours pas à pas.';

  @override
  String pagesCountSummary(int count, String perDay) {
    return '$count pages au total • environ $perDay page(s) par jour';
  }

  @override
  String goalProgressText(int start, int end, int days) {
    return 'Pages $start à $end • $days jours';
  }

  @override
  String get errInvalidPages => 'Veuillez indiquer des pages valides entre 1 et 604 (début ≤ fin).';

  @override
  String get errInvalidDuration => 'La durée doit être d\'au moins 1 jour.';

  @override
  String get todayGreeting => 'Programme du jour';

  @override
  String get noTasksTodayTitle => 'Aucune séance prévue aujourd\'hui';

  @override
  String get noTasksTodayDesc => 'Créez un objectif dans l\'onglet « Objectifs » pour générer votre programme quotidien.';

  @override
  String get markDoneButton => 'Valider la séance';

  @override
  String get completedBadge => 'Terminée';

  @override
  String todayPagesRange(int start, int end) {
    return 'Page $start à $end';
  }

  @override
  String get allDoneTodayMessage => 'Macha\'Allah ! Toutes vos séances du jour sont accomplies.';

  @override
  String get calendarSessionsForDay => 'Séances prévues ce jour';

  @override
  String get calendarNoSessionForDay => 'Aucune séance prévue pour cette date.';

  @override
  String get plannedBadge => 'Planifiée';

  @override
  String get todayShortcutButton => 'Aujourd\'hui';

  @override
  String get progressOverviewTitle => 'Vue d\'ensemble';

  @override
  String get progressPagesCompleted => 'Pages accomplies';

  @override
  String get progressSessionsCompleted => 'Séances validées';

  @override
  String get progressGoalsSectionTitle => 'Avancement par objectif';

  @override
  String get progressNoDataYet => 'Aucune donnée de progression pour le moment.';

  @override
  String get progressNoDataDesc => 'Validez votre première séance dans l\'onglet « Aujourd\'hui » pour voir évoluer vos statistiques.';

  @override
  String progressGoalDetail(int done, int total, int percent) {
    return '$done / $total pages ($percent%)';
  }

  @override
  String get quranSearchHint => 'Rechercher une sourate ou un numéro...';

  @override
  String get quranGoToPageHint => 'Page (1-604)';

  @override
  String get quranOpenButton => 'Ouvrir';

  @override
  String quranPageLabel(int page) {
    return 'Page $page / 604';
  }

  @override
  String get quranPrevPage => 'Page précédente';

  @override
  String get quranNextPage => 'Page suivante';

  @override
  String get settingsAccountSection => 'Compte';

  @override
  String get settingsLanguageSection => 'Langue de l\'application';

  @override
  String get settingsAboutSection => 'À propos';

  @override
  String get settingsVersionLabel => 'Version 1.0.0 • Accompagnement serein du Coran';

  @override
  String get reviewNeedsConsolidationButton => 'À consolider';

  @override
  String get reviewFluentButton => 'Fluide';

  @override
  String reviewScheduledFeedback(int days) {
    return 'Révision espacée programmée dans $days jour(s).';
  }

  @override
  String get errFreeLimitReached => 'Limite gratuite atteinte : archivez ou supprimez un objectif actif pour en créer un nouveau.';
}
