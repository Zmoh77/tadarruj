import '../quran/murajaa_screen.dart';
import '../progress/hifz_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/hizb_divisions.dart';
import '../../core/quran_metadata.dart';
import '../../core/tadarruj_brand.dart';
import '../calendar/calendar_repository.dart';
import '../goals/goals_repository.dart';
import '../progress/memory_health_repository.dart';
import '../progress/progress_repository.dart';
import '../quran/quran_reader_screen.dart';
import 'today_repository.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final Set<String> _completingIds = {};

  String _toArDigits(Object input) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var out = input.toString();
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(western[i], eastern[i]);
    }
    return out;
  }

  String _hijriFormatted(bool isAr) {
    final h = HijriCalendar.now();
    if (isAr) {
      const monthsAr = [
        'محرّم', 'صفر', 'ربيع الأول', 'ربيع الآخر',
        'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
        'رمضان', 'شوّال', 'ذو القعدة', 'ذو الحجة'
      ];
      final mName = monthsAr[(h.hMonth - 1).clamp(0, 11)];
      return _toArDigits('${h.hDay} $mName ${h.hYear} هـ');
    }
    const monthsFr = [
      'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
      'Jumada al-Ula', 'Jumada al-Akhirah', 'Rajab', 'Sha’ban',
      'Ramadan', 'Shawwal', 'Dhu al-Qi’dah', 'Dhu al-Hijjah'
    ];
    final mName = monthsFr[(h.hMonth - 1).clamp(0, 11)];
    return '${h.hDay} $mName ${h.hYear} H';
  }

  String _activityLabel(String activity, bool isAr, bool isFr) {
    switch (activity) {
      case 'memorisation':
        return isAr ? 'حفظ' : (isFr ? 'Mémorisation' : 'Memorisation');
      case 'revision':
        return isAr ? 'مراجعة' : (isFr ? 'Révision' : 'Revision');
      default:
        return isAr ? 'تلاوة' : (isFr ? 'Lecture' : 'Reading');
    }
  }

  Future<void> _openSessionAndTrack(
    TodayTaskModel task,
    bool isAr,
    bool isFr,
  ) async {
    HapticFeedback.lightImpact();
    final surah = QuranMetadata.getSurahForPage(task.startPage);
    await ref.read(memoryHealthRepositoryProvider).saveInterruptedSession(
          InterruptedSessionState(
            page: task.startPage,
            surahNumber: surah.number,
            activity: task.activity,
            taskId: task.id,
            savedAt: DateTime.now(),
          ),
        );
    ref.invalidate(interruptedSessionProvider);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuranReaderScreen(initialPage: task.startPage),
      ),
    );
    ref.invalidate(interruptedSessionProvider);
  }

  Future<void> _completeWithEvaluation(
    TodayTaskModel task,
    bool isAr,
    bool isFr,
  ) async {
    if (_completingIds.contains(task.id)) return;

    String selectedRating = 'mastered';
    String? selectedDifficulty;

    final difficultyReasons = isAr
        ? const [
            'نسيان آية',
            'تشابه بين آيتين',
            'نسيان بداية الآية',
            'صعوبة الربط بين آيتين',
            'خطأ في التلاوة',
            'موضع محدد يحتاج تثبيتاً',
          ]
        : (isFr
            ? const [
                'Oubli d’un verset',
                'Confusion entre deux versets',
                'Oubli du début d’un verset',
                'Difficulté à enchaîner deux versets',
                'Erreur de récitation',
                'Difficulté sur un passage spécifique',
              ]
            : const [
                'Forgot a verse',
                'Confusion between two verses',
                'Forgot start of a verse',
                'Difficulty linking two verses',
                'Recitation mistake',
                'Specific passage difficulty',
              ]);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TadarrujColors.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAr
                      ? 'كيف كانت تلاوتك؟'
                      : (isFr
                          ? 'Comment s’est passée ta récitation ?'
                          : 'How was your recitation?'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isAr
                      ? 'تقييمك يحدّث مستوى التثبيت ويجدول المراجعة القادمة تلقائياً.'
                      : (isFr
                          ? 'Ton évaluation ajuste le niveau de maîtrise et programme la prochaine révision.'
                          : 'Your rating updates mastery level and schedules the next review.'),
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _RatingOptionTile(
                  selected: selectedRating == 'hard',
                  title: isAr
                      ? 'صعب — نسيت أو أخطأت عدة مرات'
                      : (isFr
                          ? 'Difficile — oublis ou plusieurs erreurs'
                          : 'Difficult — forgot or several mistakes'),
                  accentColor: const Color(0xFFB45309),
                  onTap: () => setModalState(() {
                    selectedRating = 'hard';
                    selectedDifficulty ??= difficultyReasons.first;
                  }),
                ),
                const SizedBox(height: 8),
                _RatingOptionTile(
                  selected: selectedRating == 'hesitant',
                  title: isAr
                      ? 'متردد — أعرف المقطع مع بعض التردد'
                      : (isFr
                          ? 'Hésitant — je connais le passage avec des hésitations'
                          : 'Hesitant — know it with some hesitation'),
                  accentColor: TadarrujColors.goldAccent,
                  onTap: () => setModalState(() {
                    selectedRating = 'hesitant';
                    selectedDifficulty ??= difficultyReasons.first;
                  }),
                ),
                const SizedBox(height: 8),
                _RatingOptionTile(
                  selected: selectedRating == 'mastered',
                  title: isAr
                      ? 'متقن — تلوته بسلاسة دون صعوبة'
                      : (isFr
                          ? 'Maîtrisé — récité correctement sans difficulté'
                          : 'Mastered — recited smoothly without difficulty'),
                  accentColor: TadarrujColors.emeraldDeep,
                  onTap: () => setModalState(() {
                    selectedRating = 'mastered';
                    selectedDifficulty = null;
                  }),
                ),
                if (selectedRating != 'mastered') ...[
                  const SizedBox(height: 14),
                  Text(
                    isAr
                        ? 'طبيعة الصعوبة (اختياري)'
                        : (isFr
                            ? 'Nature de la difficulté (optionnel)'
                            : 'Nature of difficulty (optional)'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: difficultyReasons.map((reason) {
                      final isSel = selectedDifficulty == reason;
                      return RawChip(showCheckmark: false, 
                        selected: isSel,
                        selectedColor: TadarrujColors.sageSoft,
                        label: Text(
                          reason,
                          style: TextStyle(fontSize: 12),
                        ),
                        onSelected: (_) =>
                            setModalState(() => selectedDifficulty = reason),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    isAr
                        ? 'حفظ وإتمام الجلسة'
                        : (isFr ? 'Enregistrer la séance' : 'Save session'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _completingIds.add(task.id));
    HapticFeedback.mediumImpact();

    try {
      final surah = QuranMetadata.getSurahForPage(task.startPage);
      await ref.read(todayRepositoryProvider).completeTask(
            task,
            isFluent: selectedRating == 'mastered',
          );

      await ref.read(memoryHealthRepositoryProvider).recordReviewEvaluation(
            surahNumber: surah.number,
            ayahFrom: 1,
            ayahTo: (task.estimatedLines / 2).ceil().clamp(1, 20),
            rating: selectedRating,
            difficultyType: selectedDifficulty,
          );

      await ref.read(memoryHealthRepositoryProvider).clearInterruptedSession();

      ref.invalidate(todayTasksProvider);
      ref.invalidate(goalsListProvider);
      ref.invalidate(calendarTasksByDateProvider);
      ref.invalidate(passageMasteryListProvider);
      ref.invalidate(interruptedSessionProvider);
      final _ = ref.refresh(progressSummaryProvider);

      if (mounted) {
        final versesCount = (task.estimatedLines * 1.1).round().clamp(1, 999);
        final consolidatedCount =
            selectedRating == 'mastered' ? versesCount : (versesCount ~/ 2);
        final minutesSpent = (task.estimatedLines * 1.1).round().clamp(3, 90);

        await _showSobreSessionCompletedSheet(
          isAr: isAr,
          isFr: isFr,
          versesReviewed: versesCount,
          versesConsolidated: consolidatedCount,
          minutesSpent: minutesSpent,
        );
      }
    } finally {
      if (mounted) setState(() => _completingIds.remove(task.id));
    }
  }

  Future<void> _showSobreSessionCompletedSheet({
    required bool isAr,
    required bool isFr,
    required int versesReviewed,
    required int versesConsolidated,
    required int minutesSpent,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TadarrujColors.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: TadarrujColors.sageSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: TadarrujColors.emeraldDeep,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isAr
                        ? 'تمّت الجلسة بفضل الله'
                        : (isFr ? 'Séance accomplie' : 'Session completed'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SummaryMetricLine(
                text: isAr
                    ? '• ${_toArDigits(versesReviewed)} آية تمت مراجعتها'
                    : (isFr
                        ? '• $versesReviewed versets révisés'
                        : '• $versesReviewed verses reviewed'),
              ),
              const SizedBox(height: 6),
              _SummaryMetricLine(
                text: isAr
                    ? '• ${_toArDigits(versesConsolidated)} آية تم تثبيتها'
                    : (isFr
                        ? '• $versesConsolidated versets consolidés'
                        : '• $versesConsolidated verses consolidated'),
              ),
              const SizedBox(height: 6),
              _SummaryMetricLine(
                text: isAr
                    ? '• ${_toArDigits(minutesSpent)} دقيقة مع القرآن الكريم'
                    : (isFr
                        ? '• $minutesSpent minutes consacrées au Coran'
                        : '• $minutesSpent minutes spent with the Quran'),
              ),
              const SizedBox(height: 16),
              Text(
                isAr
                    ? 'الثبات على القليل الدائم خير من الكثير المنقطع. بارك الله في خطواتك.'
                    : (isFr
                        ? 'La constance avant la quantité. Qu’Allah bénisse ta régularité.'
                        : 'Consistency before quantity. May Allah bless your steady effort.'),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isAr ? 'متابعة' : (isFr ? 'Continuer' : 'Continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final isAr = lang == 'ar';
    final isFr = lang == 'fr';
    final theme = Theme.of(context);

    final tasksAsync = ref.watch(todayTasksProvider);
    final goalsAsync = ref.watch(goalsListProvider);
    final masteryAsync = ref.watch(passageMasteryListProvider);
    final interruptedAsync = ref.watch(interruptedSessionProvider);

    final user = Supabase.instance.client.auth.currentUser;
    final rawName =
        (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final firstName = rawName.isNotEmpty
        ? rawName.split(' ').first
        : ((user?.email ?? '').split('@').first);

    final activeGoals = goalsAsync.valueOrNull ?? [];
    final primaryGoal = activeGoals.isNotEmpty ? activeGoals.first : null;
    final masteryRecords = masteryAsync.valueOrNull ?? [];
    final interruptedSession = interruptedAsync.valueOrNull;

    // Calcul sobre des indicateurs globaux de mémorisation
    final int memorizedPages = activeGoals.fold<int>(0, (sum, g) {
      if (g.goalType == 'memorisation') {
        return sum + (g.endPage - g.startPage + 1);
      }
      return sum;
    });
    final int memorizedHizb = (memorizedPages / 10.0).round();
    final int memorizedVerses = (memorizedPages * 15 * 1.1).round();
    final int memorizedSurahs = masteryRecords
        .where((r) =>
            r.level == MasteryLevel.stable || r.level == MasteryLevel.solid)
        .map((r) => r.surahNumber)
        .toSet()
        .length;
    final double globalRatio =
        (memorizedPages / 604.0).clamp(0.0, 1.0);

    final priorityWeakPassages = masteryRecords
        .where((r) =>
            r.level == MasteryLevel.fragile ||
            r.level == MasteryLevel.consolidating)
        .take(2)
        .toList();

    return Scaffold(
      appBar: TadarrujAppBar(
        title: isAr ? 'تَدَرُّج' : 'Tadarruj',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayTasksProvider);
          ref.invalidate(goalsListProvider);
          ref.invalidate(passageMasteryListProvider);
          ref.invalidate(interruptedSessionProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
          children: [
            // 1. Salutation discrète et chaleureuse
            Text(
              _hijriFormatted(isAr),
              style: theme.textTheme.bodySmall?.copyWith(
                color: TadarrujColors.goldAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAr
                  ? (firstName.isNotEmpty
                      ? 'السلام عليكم، $firstName'
                      : 'السلام عليكم')
                  : (firstName.isNotEmpty
                      ? 'As-salamu alaykum, $firstName'
                      : 'As-salamu alaykum'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),

            // 2. Reprise immédiate de la dernière séance interrompue (si existante)
            if (interruptedSession != null) ...[
              _buildInterruptedCard(interruptedSession, isAr, isFr),
              const SizedBox(height: 14),
            ],

            // 3. Progression générale de mémorisation & rappel doux de l'objectif
            _buildGlobalMemoryCard(
              theme: theme,
              isAr: isAr,
              isFr: isFr,
              globalRatio: globalRatio,
              surahsCount: memorizedSurahs,
              pagesCount: memorizedPages,
              hizbCount: memorizedHizb,
              versesCount: memorizedVerses,
              primaryGoal: primaryGoal,
            ),
            const SizedBox(height: 16),

            // 4. Programme de la journée & Bouton principal « Commencer ma séance »
            tasksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _buildOfflineOrErrorState(isAr, isFr),
              data: (tasks) {
                final todoTasks = tasks.where((t) => !t.isDone).toList();
                final doneTasks = tasks.where((t) => t.isDone).toList();

                if (todoTasks.isEmpty && doneTasks.isEmpty) {
                  return _buildEmptyTodayCompanion(
                    isAr: isAr,
                    isFr: isFr,
                    hasGoal: primaryGoal != null,
                  );
                }

                if (todoTasks.isEmpty && doneTasks.isNotEmpty) {
                  return _buildCompletedDayCard(isAr, isFr, doneTasks.length);
                }

                final nextTask = todoTasks.first;
                final sStart = QuranMetadata.getSurahForPage(nextTask.startPage);
                final sEnd = QuranMetadata.getSurahForPage(nextTask.endPage);
                final totalMinutes = todoTasks.fold<int>(
                  0,
                  (sum, t) => sum + (t.estimatedLines * 1.1).round().clamp(4, 45),
                );
                final surahTitle = isAr
                    ? (sStart.number == sEnd.number
                        ? 'سورة ${sStart.nameArabic}'
                        : 'سورة ${sStart.nameArabic} ← ${sEnd.nameArabic}')
                    : (sStart.number == sEnd.number
                        ? sStart.nameTranslit
                        : '${sStart.nameTranslit} → ${sEnd.nameTranslit}');

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.96, end: 1.0),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          TadarrujColors.emeraldDeep,
                          TadarrujColors.emeraldPrimary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TadarrujColors.emeraldDeep.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              isAr
                                  ? 'برنامج اليوم'
                                  : (isFr
                                      ? 'Programme du jour'
                                      : 'Today’s program'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: TadarrujColors.goldSoft,
                              ),
                            ),
                            ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          surahTitle,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr
                              ? _toArDigits(
                                  '${_activityLabel(nextTask.activity, true, false)} • الصفحات ${nextTask.startPage}–${nextTask.endPage} (~${nextTask.estimatedLines} سطراً)')
                              : (isFr
                                  ? '${_activityLabel(nextTask.activity, false, true)} • Pages ${nextTask.startPage}–${nextTask.endPage} (~${nextTask.estimatedLines} lignes)'
                                  : '${_activityLabel(nextTask.activity, false, false)} • Pages ${nextTask.startPage}–${nextTask.endPage} (~${nextTask.estimatedLines} lines)'),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.white.withValues(alpha: 0.90),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: TadarrujColors.goldSoft,
                            foregroundColor: TadarrujColors.emeraldDeep,
                          ),
                          onPressed: () =>
                              _openSessionAndTrack(nextTask, isAr, isFr),
                          icon: const Icon(Icons.menu_book_rounded, size: 20),
                          label: Text(
                            isAr
                                ? 'ابدأ جلستي الآن'
                                : (isFr
                                    ? 'Commencer ma séance'
                                    : 'Start my session'),
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.10),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                          ),
                          onPressed: _completingIds.contains(nextTask.id)
                              ? null
                              : () => _completeWithEvaluation(
                                  nextTask, isAr, isFr),
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                          label: Text(
                            isAr
                                ? 'تسجيل إتمام الورد وتقييمه'
                                : (isFr
                                    ? 'Valider et évaluer ma récitation'
                                    : 'Complete & rate recitation'),
                          ),
                        ),
                        if (todoTasks.length > 1) ...[
                          const Divider(height: 24),
                          ...todoTasks.skip(1).map((t) {
                            final s = QuranMetadata.getSurahForPage(t.startPage);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle_outlined,
                                      size: 14,
                                      color: TadarrujColors.sageGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isAr
                                          ? _toArDigits(
                                              '${_activityLabel(t.activity, true, false)} • سورة ${s.nameArabic} (ص. ${t.startPage}–${t.endPage})')
                                          : '${_activityLabel(t.activity, false, isFr)} • ${s.nameTranslit} (p. ${t.startPage}–${t.endPage})',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            // 5. Aperçu sobre des révisions prioritaires (passages fragiles)
            if (priorityWeakPassages.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPriorityRevisionsCard(priorityWeakPassages, isAr, isFr),
            ],

            // 6. Accès directs sobres : Révision active (Murāja’a) & Carte de mon Hifz (114 sourates)
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MurajaaScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.psychology_outlined, size: 18),
                    label: Text(
                      isAr
                          ? 'مراجعة ذكية'
                          : (isFr ? 'Murāja’a' : 'Murāja’a'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HifzMapScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: Text(
                      isAr
                          ? 'خريطة حفظي'
                          : (isFr ? 'Carte Hifz' : 'Hifz Map'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterruptedCard(
    InterruptedSessionState session,
    bool isAr,
    bool isFr,
  ) {
    final surah = QuranMetadata.getSurahByNumber(session.surahNumber);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TadarrujColors.sageSoft.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TadarrujColors.goldAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bookmark_outline_rounded,
              color: TadarrujColors.emeraldDeep, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr
                      ? 'متابعة الجلسة السابقة'
                      : (isFr
                          ? 'Reprendre la séance interrompue'
                          : 'Resume interrupted session'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAr
                      ? _toArDigits(
                          'سورة ${surah.nameArabic} • صفحة ${session.page}')
                      : (isFr
                          ? '${surah.nameTranslit} • Page ${session.page}'
                          : '${surah.nameTranslit} • Page ${session.page}'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuranReaderScreen(initialPage: session.page),
                ),
              );
            },
            child: Text(isAr ? 'استئناف' : (isFr ? 'Reprendre' : 'Resume')),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalMemoryCard({
    required ThemeData theme,
    required bool isAr,
    required bool isFr,
    required double globalRatio,
    required int surahsCount,
    required int pagesCount,
    required int hizbCount,
    required int versesCount,
    required GoalModel? primaryGoal,
  }) {
    final pct = (globalRatio * 100).toStringAsFixed(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  isAr
                      ? 'مسار الحفظ العام'
                      : (isFr
                          ? 'Progression générale'
                          : 'Overall memorization'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  isAr ? '${_toArDigits(pct)}٪' : '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TadarrujColors.sageGreen,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: globalRatio > 0 ? globalRatio : 0.02),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, animVal, _) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: animVal,
                  minHeight: 9,
                  backgroundColor: TadarrujColors.sageSoft,
                  color: TadarrujColors.emeraldPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CompactCounter(
                  value: isAr ? _toArDigits(surahsCount) : '$surahsCount',
                  label: isAr ? 'سور' : (isFr ? 'Sourates' : 'Surahs'),
                ),
                _CompactCounter(
                  value: isAr ? _toArDigits(pagesCount) : '$pagesCount',
                  label: isAr ? 'صفحات' : (isFr ? 'Pages' : 'Pages'),
                ),
                _CompactCounter(
                  value: isAr ? _toArDigits(hizbCount) : '$hizbCount',
                  label: isAr ? 'أحزاب' : (isFr ? 'Hizb' : 'Hizb'),
                ),
                _CompactCounter(
                  value: isAr ? _toArDigits(versesCount) : '$versesCount',
                  label: isAr ? 'آيات' : (isFr ? 'Versets' : 'Verses'),
                ),
              ],
            ),
            if (primaryGoal != null) ...[
              const Divider(height: 22),
              Text(
                isAr
                    ? 'الهدف الحالي: ${primaryGoal.title} — خطوة ثابتة كل يوم تكفي.'
                    : (isFr
                        ? 'Objectif en cours : ${primaryGoal.title} — avance à ton rythme, sans pression.'
                        : 'Current goal: ${primaryGoal.title} — steady progress, without pressure.'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityRevisionsCard(
    List<PassageMasteryRecord> passages,
    bool isAr,
    bool isFr,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined,
                    size: 18, color: TadarrujColors.goldAccent),
                const SizedBox(width: 8),
                Text(
                  isAr
                      ? 'مراجعات ذات أولوية'
                      : (isFr
                          ? 'Révisions prioritaires'
                          : 'Priority revisions'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...passages.map((p) {
              final s = QuranMetadata.getSurahByNumber(p.surahNumber);
              final statusLabel = p.level == MasteryLevel.fragile
                  ? (isAr ? 'يحتاج تثبيتاً' : (isFr ? 'Fragile' : 'Fragile'))
                  : (isAr
                      ? 'في طور التثبيت'
                      : (isFr ? 'En consolidation' : 'Consolidating'));
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            QuranReaderScreen(initialPage: s.startPage),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TadarrujColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isAr
                                ? _toArDigits(
                                    'سورة ${s.nameArabic} • الآيات ${p.ayahFrom}–${p.ayahTo}')
                                : '${s.nameTranslit} • v. ${p.ayahFrom}–${p.ayahTo}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: TadarrujColors.sageSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: TadarrujColors.emeraldDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTodayCompanion({
    required bool isAr,
    required bool isFr,
    required bool hasGoal,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasGoal
                  ? (isAr
                      ? 'لا توجد مراجعة مجدولة اليوم'
                      : (isFr
                          ? 'Aucune révision programmée aujourd’hui'
                          : 'No revision scheduled today'))
                  : (isAr
                      ? 'ابدأ رحلتك مع القرآن الكريم'
                      : (isFr
                          ? 'Commence ton parcours de mémorisation'
                          : 'Begin your memorization journey')),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasGoal
                  ? (isAr
                      ? 'يمكنك فتح المصحف للتلاوة الحرة أو مراجعة مواضعك السابقة بهدوء.'
                      : (isFr
                          ? 'Profite de ce moment calme pour relire librement ou consolider un passage.'
                          : 'Enjoy a quiet moment to read freely or review a previous passage.'))
                  : (isAr
                      ? 'حدد هدفاً بسيطاً يناسب وقتك اليومي — الثبات قبل الكثرة.'
                      : (isFr
                          ? 'Définis un premier objectif adapté à ton rythme — la constance avant la quantité.'
                          : 'Set a gentle first goal tailored to your pace — consistency before quantity.')),
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                if (hasGoal) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const QuranReaderScreen(initialPage: 1),
                    ),
                  );
                } else {
                  context.push('/goals/new');
                }
              },
              icon: Icon(
                  hasGoal ? Icons.menu_book_rounded : Icons.add_rounded),
              label: Text(
                hasGoal
                    ? (isAr
                        ? 'فتح المصحف'
                        : (isFr ? 'Ouvrir le Mushaf' : 'Open Mushaf'))
                    : (isAr
                        ? 'إنشاء هدفي الأول'
                        : (isFr
                            ? 'Créer mon premier objectif'
                            : 'Create my first goal')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedDayCard(bool isAr, bool isFr, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: TadarrujColors.sageGreen, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr
                        ? 'ورد اليوم مكتمل'
                        : (isFr
                            ? 'Programme du jour accompli'
                            : 'Today’s program completed'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'بارك الله في ثباتك. يمكنك فتح المصحف للمراجعة الحرة متى شئت.'
                  : (isFr
                      ? 'Qu’Allah bénisse ta constance. Tu peux ouvrir le Mushaf pour une lecture libre à tout moment.'
                      : 'May Allah bless your consistency. You can open the Mushaf for free reading anytime.'),
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QuranReaderScreen(initialPage: 1),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(
                isAr
                    ? 'مواصلة التلاوة في المصحف'
                    : (isFr ? 'Continuer dans le Mushaf' : 'Continue in Mushaf'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineOrErrorState(bool isAr, bool isFr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAr
                  ? 'وضع عدم الاتصال'
                  : (isFr ? 'Mode hors ligne' : 'Offline mode'),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'تعذر تحديث البيانات حالياً. يمكنك متابعة القراءة في المصحف مباشرة.'
                  : (isFr
                      ? 'Synchronisation indisponible pour le moment. Tu peux ouvrir le Mushaf hors ligne.'
                      : 'Unable to sync right now. You can open the Mushaf offline.'),
              style: TextStyle(
                  fontSize: 13, color: TadarrujColors.warmGrey),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(todayTasksProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                  isAr ? 'إعادة المحاولة' : (isFr ? 'Actualiser' : 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactCounter extends StatelessWidget {
  final String value;
  final String label;

  const _CompactCounter({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RatingOptionTile extends StatelessWidget {
  final bool selected;
  final String title;
  final Color accentColor;
  final VoidCallback onTap;

  const _RatingOptionTile({
    required this.selected,
    required this.title,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.12)
              : TadarrujColors.beigeSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : TadarrujColors.cardBorder,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? accentColor : TadarrujColors.warmGrey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricLine extends StatelessWidget {
  final String text;
  const _SummaryMetricLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
