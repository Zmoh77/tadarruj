import '../../app/premium_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_mapper.dart';
import '../../core/hizb_divisions.dart';
import '../../core/quran_metadata.dart';
import '../../core/tadarruj_brand.dart';
import '../../l10n/app_localizations.dart';
import '../goals/goals_repository.dart';
import 'progress_repository.dart';

String _arDigits(Object input) {
  const w = ['0','1','2','3','4','5','6','7','8','9'];
  const e = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  var s = input.toString();
  for (int i = 0; i < 10; i++) { s = s.replaceAll(w[i], e[i]); }
  return s;
}

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String? _selectedGoalId;
  String _quickActivity = 'memorisation';
  final TextEditingController _linesController = TextEditingController();
  final TextEditingController _vigilanceController = TextEditingController();
  bool _isSaving = false;
  Set<int> _restDays = {};
  List _vigilanceNotes = [];
  bool _rebalanced = false;

  @override
  void initState() {
    super.initState();
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final rawRest = meta?['rest_days'];
    if (rawRest is List) {
      _restDays = rawRest.map((e) => (e as num).toInt()).toSet();
    }
    final rawVig = meta?['vigilance_notes'];
    if (rawVig is List) {
      _vigilanceNotes = List.from(rawVig);
    }
  }

  @override
  void dispose() {
    _linesController.dispose();
    _vigilanceController.dispose();
    super.dispose();
  }

  Future<void> _saveVigilanceNotes() async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'vigilance_notes': _vigilanceNotes}),
    );
  }

  Future<void> _addLines(int lines, String label) async {
    if (_isSaving || lines <= 0) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(progressRepositoryProvider).logQuickLines(
            activity: _quickActivity,
            lines: lines,
            goalId: _selectedGoalId,
          );
      _linesController.clear();
      final _ = ref.refresh(progressSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TadarrujColors.emeraldPrimary,
            content: Text('🎉 +$label enregistré et synchronisé !'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _undoToday() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(progressRepositoryProvider).undoLastTodayLog();
      final _ = ref.refresh(progressSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dernier ajout d’aujourd’hui annulé.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openFocusModal(BuildContext context, GoalProgressItem? goal, int targetLines, bool isFr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FocusSessionSheet(
        goalTitle: goal?.title ?? (isFr ? 'Séance libre' : 'Free session'),
        targetLines: targetLines > 0 ? targetLines : 10,
        isFr: isFr,
        onValidateSession: (validatedLines) {
          _addLines(validatedLines, '$validatedLines lignes (Séance Focus)');
        },
      ),
    );
  }

  int _countStudyDays(DateTime from, DateTime to) {
    if (to.isBefore(from)) return 1;
    int count = 0;
    DateTime cursor = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!cursor.isAfter(end)) {
      if (!_restDays.contains(cursor.weekday)) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count > 0 ? count : 1;
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(progressSummaryProvider);
    final isFr = Localizations.localeOf(context).languageCode != 'en';

    return Scaffold(
      appBar: TadarrujAppBar(title: l10n.navProgress),
      body: Stack(
        children: [
          const IslamicPatternOverlay(opacity: 0.04),
          summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(mapAuthError(err, l10n), textAlign: TextAlign.center),
              ),
            ),
            data: (summary) {
              final goals = summary.goals;
              if (_selectedGoalId != null &&
                  !goals.any((g) => g.id == _selectedGoalId)) {
                _selectedGoalId = null;
              }

              final GoalProgressItem? activeGoal = _selectedGoalId == null
                  ? (goals.isNotEmpty ? goals.first : null)
                  : goals.firstWhere((g) => g.id == _selectedGoalId);

              final int startPage = activeGoal?.startPage ?? 1;
              final int endPage = activeGoal?.endPage ?? 604;
              final int totalLines = activeGoal?.totalLines ??
                  ((endPage - startPage + 1).clamp(1, 604) * 15);

              final int doneLines = activeGoal != null
                  ? activeGoal.completedLines.clamp(0, totalLines)
                  : summary.totalLinesDone;
              final int remainingLines =
                  (totalLines - doneLines).clamp(0, totalLines);

              final double progressRatio = totalLines > 0
                  ? (doneLines / totalLines).clamp(0.0, 1.0)
                  : 0.0;
              final int progressPct = (progressRatio * 100).round();

              final DateTime now = DateTime.now();
              final DateTime baseDueDate = activeGoal?.targetDate ??
                  summary.targetDeadline ??
                  now.add(const Duration(days: 30));
              final DateTime dueDate = _rebalanced
                  ? baseDueDate.add(const Duration(days: 7))
                  : baseDueDate;
              final int remainingStudyDays = _countStudyDays(now, dueDate);

              final int smartDailyLines = remainingLines == 0
                  ? 0
                  : (remainingLines / remainingStudyDays).ceil();
              final String smartDailyPages =
                  (smartDailyLines / 15.0).toStringAsFixed(1);

              final String todayStr = _todayKey();
              final int todayDoneLines = summary.recentLogs
                  .where((e) =>
                      e.dateKey == todayStr &&
                      (activeGoal == null ||
                          e.goalId == null ||
                          e.goalId == activeGoal.id))
                  .fold<int>(0, (sum, e) => sum + e.lines);

              final bool dailyTargetReached =
                  smartDailyLines == 0 || todayDoneLines >= smartDailyLines;

              bool isReverseGoal = false;
              if (activeGoal != null && activeGoal.title.contains('→')) {
                final parts = activeGoal.title.split('→');
                if (parts.length == 2) {
                  final leftNums = RegExp(r'\d+').allMatches(parts[0]).map((m) => int.parse(m.group(0)!)).toList();
                  final rightNums = RegExp(r'\d+').allMatches(parts[1]).map((m) => int.parse(m.group(0)!)).toList();
                  if (leftNums.isNotEmpty && rightNums.isNotEmpty && leftNums.first > rightNums.first) {
                    isReverseGoal = true;
                  }
                }
              }

              final int startHizb = HizbDivisions.getForPage(startPage).number;
              final int endHizb = HizbDivisions.getForPage(endPage).number;
              final int hizbSpan = (endHizb - startHizb + 1).clamp(1, 60);

              final List<SurahInfo> coveredSurahs = [];
              for (int i = 1; i <= 114; i++) {
                final s = QuranMetadata.getSurahByNumber(i);
                if (s.endPage >= startPage && s.startPage <= endPage) {
                  coveredSurahs.add(s);
                }
              }
              if (isReverseGoal) {
                coveredSurahs.sort((a, b) => b.number.compareTo(a.number));
              }

              final double donePagesExact = doneLines / 15.0;
              final double currentVirtualPage = isReverseGoal
                  ? (endPage - donePagesExact).clamp(startPage.toDouble(), endPage.toDouble())
                  : (startPage + donePagesExact).clamp(startPage.toDouble(), endPage.toDouble());

              // Calcul du bilan hebdomadaire (7 derniers jours)
              final DateTime sevenDaysAgo = DateTime(now.year, now.month, now.day)
                  .subtract(const Duration(days: 6));
              final int lines7Days = summary.recentLogs.where((e) {
                final parsed = DateTime.tryParse(e.dateKey);
                if (parsed == null) return false;
                final dayOnly = DateTime(parsed.year, parsed.month, parsed.day);
                return !dayOnly.isBefore(sevenDaysAgo);
              }).fold<int>(0, (sum, e) => sum + e.lines);

              return RefreshIndicator(
                onRefresh: () async {
                  final _ = ref.refresh(progressSummaryProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 56),
                  children: [
                    // Sélecteur d'objectif multi-mode (Mémorisation / Révision / Khatma)
                    if (goals.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: goals.map((g) {
                            final isSelected = activeGoal?.id == g.id;
                            IconData icon = Icons.psychology_rounded;
                            if (g.activity == 'revision') {
                              icon = Icons.refresh_rounded;
                            } else if (g.activity == 'lecture') {
                              icon = Icons.menu_book_rounded;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: RawChip(showCheckmark: false, 
                                avatar: Icon(icon, size: 16),
                                label: Text(g.title),
                                selected: isSelected,
                                onSelected: (_) => setState(() {
                                  _selectedGoalId = g.id;
                                  _quickActivity = g.activity;
                                }),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // CARTE PRINCIPALE : ACTION IMMÉDIATE & RATTRAPAGE INTELLIGENT
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0E3B2E),
                            Color(0xFF1F5E4B),
                            Color(0xFF2B6CB0),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.track_changes_rounded,
                                  color: TadarrujColors.goldSoft, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  Localizations.localeOf(context).languageCode == 'ar' ? 'الهدف اليومي (متجدد تلقائياً)' : (isFr ? 'OBJECTIF DU JOUR' : 'TODAY’S TARGET'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(behavior: HitTestBehavior.opaque, 
                                onTap: () => _openFocusModal(
                                    context, activeGoal, smartDailyLines, isFr),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: TadarrujColors.goldSoft,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.play_arrow_rounded,
                                          size: 16, color: Colors.black),
                                      const SizedBox(width: 3),
                                      Text(
                                        Localizations.localeOf(context).languageCode == 'ar' ? 'وضع التركيز' : (isFr ? 'Mode Focus' : 'Focus Mode'),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                '$smartDailyLines',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 38,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                Localizations.localeOf(context).languageCode == 'ar' ? 'سطر / يوم' : (isFr ? 'lignes / jour' : 'lines / day'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            remainingLines == 0
                                ? (isFr
                                    ? (Localizations.localeOf(context).languageCode == 'ar' ? _arDigits('🎉 تم إتمام الهدف بالكامل ($totalLines / $totalLines سطراً)!') : '🎉 Objectif complet atteint ($totalLines / $totalLines lignes) !')
                                    : '🎉 Full goal completed!')
                                : (isFr
                                    ? (Localizations.localeOf(context).languageCode == 'ar' ? _arDigits('المتبقي $remainingLines سطراً على $remainingStudyDays يوم دراسة (≈ $smartDailyPages صفحة/يوم).') : 'Reste $remainingLines l. sur $remainingStudyDays j. d’étude (≈ $smartDailyPages p./jour).')
                                    : '$remainingLines l. left over $remainingStudyDays study days (≈ $smartDailyPages p./day).'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isFr
                                ? (Localizations.localeOf(context).languageCode == 'ar' ? _arDigits('المجموع: $doneLines / $totalLines سطراً ($progressPct%) • اليوم: $todayDoneLines سطر.') : 'Cumul : $doneLines / $totalLines l. ($progressPct%) • Aujourd’hui : $todayDoneLines l.')
                                : 'Total: $doneLines / $totalLines l. ($progressPct%) • Today: $todayDoneLines l.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          if (dailyTargetReached) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: TadarrujColors.goldSoft
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      color: TadarrujColors.goldSoft, size: 17),
                                const SizedBox(width: 6),
                                Expanded(child: Text(
                                  Localizations.localeOf(context).languageCode == 'ar' ? 'تم إتمام ورد اليوم! بارك الله في جهدك.' : (isFr ? 'Séance du jour validée ! Qu’Allah bénisse ton effort.' : 'Daily target reached!'),
                                  style: const TextStyle(
                                    color: TadarrujColors.goldSoft,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                )),
                              ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _QuickAddPill(
                                label: Localizations.localeOf(context).languageCode == 'ar' ? '+٥ أسطر' : '+5 l.',
                                onTap: () => _addLines(5, '5 lignes'),
                              ),
                              _QuickAddPill(
                                label: Localizations.localeOf(context).languageCode == 'ar' ? '+١٠ أسطر' : '+10 l.',
                                onTap: () => _addLines(10, '10 lignes'),
                              ),
                              _QuickAddPill(
                                label: Localizations.localeOf(context).languageCode == 'ar' ? '+١ صفحة' : '+1 page',
                                onTap: () => _addLines(15, '1 page (15 l.)'),
                              ),
                              if (smartDailyLines > 0 && !dailyTargetReached)
                                _QuickAddPill(
                                  label: isFr
                                      ? '✓ Valider ma séance ($smartDailyLines l.)'
                                      : '✓ Complete today ($smartDailyLines l.)',
                                  highlight: true,
                                  onTap: () => _addLines(
                                      (smartDailyLines - todayDoneLines)
                                          .clamp(1, 300),
                                      'Séance du jour'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(
                                width: 88,
                                height: 38,
                                child: TextField(
                                  controller: _linesController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: Localizations.localeOf(context).languageCode == 'ar' ? 'أسطر' : (isFr ? 'lignes' : 'lines'),
                                    hintStyle: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.65),
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.16),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0E3B2E),
                                ),
                                onPressed: () {
                                  final v = int.tryParse(
                                          _linesController.text.trim()) ??
                                      0;
                                  if (v > 0) _addLines(v, '$v lignes');
                                },
                                child: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'إضافة' : (isFr ? 'Ajouter' : 'Add')),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: isFr ? 'Annuler dernier ajout' : 'Undo',
                                onPressed: _undoToday,
                                icon: const Icon(Icons.undo_rounded,
                                    color: Colors.white),
                              ),
                              const Spacer(),
                              if (smartDailyLines > 15 && !_rebalanced)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: TadarrujColors.goldSoft,
                                  ),
                                  onPressed: () {
                                    setState(() => _rebalanced = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isFr
                                            ? '🌿 Rattrapage doux activé : planning étalé de 7 jours.'
                                            : '🌿 Gentle catch-up enabled (+7 days).'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.balance_rounded,
                                      size: 16),
                                  label: Text(
                                    Localizations.localeOf(context).languageCode == 'ar' ? 'إعادة التوازن' : (isFr ? 'Rééquilibrer' : 'Rebalance'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CARTE VISUELLE : TRAJECTOIRE & PALIERS PRÉVISIONNELS
                    _buildTrajectoryCard(
                      context: context,
                      isFr: isFr,
                      isReverse: isReverseGoal,
                      now: now,
                      startPage: startPage,
                      endPage: endPage,
                      doneLines: doneLines,
                      totalLines: totalLines,
                      remainingLines: remainingLines,
                      remainingStudyDays: remainingStudyDays,
                      smartDailyLines: smartDailyLines,
                      progressRatio: progressRatio,
                      progressPct: progressPct,
                    ),
                    const SizedBox(height: 16),

                    // CARTE THERMIQUE DES 30 JUZ DU CORAN (HEATMAP)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.grid_on_rounded,
                                    color: TadarrujColors.goldAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    Localizations.localeOf(context).languageCode == 'ar' ? 'خريطة الأجزاء الثلاثين (نظرة شاملة)' : (isFr ? 'Cartographie des 30 Juz (Vue globale)' : '30 Juz Heatmap (Global View)'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children: [
                                _LegendDot(
                                    color: const Color(0xFF28A745),
                                    label: Localizations.localeOf(context).languageCode == 'ar' ? 'مكتمل' : (isFr ? 'Acquis' : 'Done')),
                                _LegendDot(
                                    color: TadarrujColors.goldAccent,
                                    label: Localizations.localeOf(context).languageCode == 'ar' ? 'قيد الإنجاز' : (isFr ? 'En cours' : 'Active')),
                                _LegendDot(
                                    color: Colors.grey.withValues(alpha: 0.22),
                                    label: Localizations.localeOf(context).languageCode == 'ar' ? 'قادم' : (isFr ? 'À venir' : 'Upcoming')),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: List.generate(30, (i) {
                                final juzNum = i + 1;
                                final juzStartPage = (i * 20) + 1;
                                final juzEndPage =
                                    juzNum == 30 ? 604 : (juzNum * 20);
                                final double juzSpanPages =
                                    (juzEndPage - juzStartPage + 1).toDouble();

                                final bool isConcerned =
                                    endPage >= juzStartPage && startPage <= juzEndPage;

                                double juzPctRatio = 0.0;
                                if (isConcerned && donePagesExact > 0) {
                                  final double segLow = isReverseGoal ? currentVirtualPage : startPage.toDouble();
                                  final double segHigh = isReverseGoal ? (endPage + 1).toDouble() : (startPage + donePagesExact);
                                  final double overlapStart = segLow > juzStartPage ? segLow : juzStartPage.toDouble();
                                  final double overlapEnd = segHigh < (juzEndPage + 1) ? segHigh : (juzEndPage + 1).toDouble();
                                  final double doneInJuz = (overlapEnd - overlapStart).clamp(0.0, juzSpanPages);
                                  juzPctRatio = (doneInJuz / juzSpanPages).clamp(0.0, 1.0);
                                }
                                final int juzPct = (juzPctRatio * 100).round();

                                Color borderCol = Colors.grey.withValues(alpha: 0.28);
                                Color fillCol = Colors.transparent;
                                if (juzPct >= 100) {
                                  borderCol = const Color(0xFF28A745);
                                  fillCol = const Color(0xFF28A745).withValues(alpha: 0.24);
                                } else if (isConcerned) {
                                  borderCol = TadarrujColors.goldAccent;
                                  fillCol = TadarrujColors.goldAccent.withValues(alpha: 0.22);
                                }

                                return Tooltip(
                                  message:
                                      'Juz $juzNum (Pages $juzStartPage–$juzEndPage) • $juzPct%',
                                  child: Container(
                                    width: 58,
                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: fillCol,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: borderCol, width: isConcerned ? 1.4 : 0.8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          Localizations.localeOf(context).languageCode == 'ar' ? 'ج${_arDigits(juzNum)}' : 'J$juzNum',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isConcerned ? Localizations.localeOf(context).languageCode == 'ar' ? '${_arDigits(juzPct)}٪' : '$juzPct%' : '—',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10.5,
                                            color: juzPct >= 100
                                                ? const Color(0xFF28A745)
                                                : (isConcerned ? TadarrujColors.goldAccent : Colors.grey),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: juzPctRatio,
                                            minHeight: 3.5,
                                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                            color: juzPct >= 100
                                                ? const Color(0xFF28A745)
                                                : TadarrujColors.goldAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // GRILLE ADAPTATIVE CIBLÉE (Sourates exactes OU Hizb exacts de l'objectif)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  hizbSpan <= 1
                                      ? Icons.auto_stories_rounded
                                      : Icons.grid_view_rounded,
                                  color: TadarrujColors.emeraldPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hizbSpan <= 1
                                        ? (isFr
                                            ? 'Sourates de l’objectif (${coveredSurahs.length} sourate(s) • Pages $startPage–$endPage)'
                                            : 'Goal Surahs (${coveredSurahs.length} surah(s))')
                                        : (Localizations.localeOf(context).languageCode == 'ar'
                                            ? 'أحزاب الهدف (حزب ${isReverseGoal ? endHizb : startHizb} ← ${isReverseGoal ? startHizb : endHizb})'
                                            : (isFr
                                                ? 'Hizb de l’objectif (Hizb ${isReverseGoal ? endHizb : startHizb} → ${isReverseGoal ? startHizb : endHizb})'
                                                : 'Goal Hizb (Hizb ${isReverseGoal ? endHizb : startHizb} → ${isReverseGoal ? startHizb : endHizb})')),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (hizbSpan <= 1)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: coveredSurahs.map((s) {
                                  final isCompleted =
                                      currentVirtualPage >= s.endPage;
                                  final isInProgress = !isCompleted &&
                                      currentVirtualPage >= s.startPage;

                                  Color chipBg =
                                      Colors.grey.withValues(alpha: 0.14);
                                  Color textCol = Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .color!;
                                  if (isCompleted) {
                                    chipBg = const Color(0xFF28A745);
                                    textCol = Colors.white;
                                  } else if (isInProgress) {
                                    chipBg = TadarrujColors.goldAccent;
                                    textCol = Colors.black;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: chipBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${s.number}. ${s.nameTranslit} (p. ${s.startPage}–${s.endPage})',
                                      style: TextStyle(
                                        color: textCol,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(hizbSpan, (idx) {
                                  final hNum = isReverseGoal ? (endHizb - idx) : (startHizb + idx);
                                  final hInfo = HizbDivisions.all[hNum - 1];
                                  final double fullHizbPages = (hInfo.endPage - hInfo.startPage + 1).toDouble().clamp(1.0, 15.0);
                                  double doneInHizb = 0.0;
                                  if (donePagesExact > 0) {
                                    final double segLow = isReverseGoal ? currentVirtualPage : startPage.toDouble();
                                    final double segHigh = isReverseGoal ? (endPage + 1).toDouble() : (startPage + donePagesExact);
                                    final double overlapStart = segLow > hInfo.startPage ? segLow : hInfo.startPage.toDouble();
                                    final double overlapEnd = segHigh < (hInfo.endPage + 1) ? segHigh : (hInfo.endPage + 1).toDouble();
                                    doneInHizb = (overlapEnd - overlapStart).clamp(0.0, fullHizbPages);
                                  }
                                  final double hRatio = (doneInHizb / fullHizbPages).clamp(0.0, 1.0);
                                  final int hPct = (hRatio * 100).round();

                                  final bool isDone = hPct >= 100;
                                  final bool isStarted = hPct > 0 && !isDone;

                                  Color borderCol = Colors.grey.withValues(alpha: 0.35);
                                  Color fillCol = Colors.grey.withValues(alpha: 0.08);
                                  if (isDone) {
                                    borderCol = const Color(0xFF28A745);
                                    fillCol = const Color(0xFF28A745).withValues(alpha: 0.22);
                                  } else if (isStarted) {
                                    borderCol = TadarrujColors.goldAccent;
                                    fillCol = TadarrujColors.goldAccent.withValues(alpha: 0.22);
                                  }

                                  return Container(
                                    width: 64,
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: fillCol,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderCol, width: 1.4),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'H$hNum',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$hPct%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            color: isDone
                                                ? const Color(0xFF28A745)
                                                : (isStarted ? TadarrujColors.goldAccent : Colors.grey),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: hRatio,
                                            minHeight: 4,
                                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                            color: isDone
                                                ? const Color(0xFF28A745)
                                                : TadarrujColors.goldAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // BILAN HEBDOMADAIRE & RÉVISION ESPACÉE (MURAJA'A)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.insights_rounded,
                                    color: TadarrujColors.emeraldPrimary),
                                const SizedBox(width: 8),
                                Text(
                                  Localizations.localeOf(context).languageCode == 'ar' ? 'الحصيلة الأسبوعية' : (isFr ? 'Bilan hebdomadaire' : 'Weekly Summary'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniMetricBox(
                                    value: '$lines7Days l.',
                                    label: Localizations.localeOf(context).languageCode == 'ar' ? 'آخر 7 أيام' : (isFr ? '7 derniers jours' : 'Last 7 days'),
                                    color: TadarrujColors.emeraldPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MiniMetricBox(
                                    value: '${summary.currentStreak} j.',
                                    label: Localizations.localeOf(context).languageCode == 'ar' ? 'الاستمرارية' : (isFr ? 'Régularité' : 'Streak'),
                                    color: TadarrujColors.goldAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MiniMetricBox(
                                    value: 'J+1 • J+7',
                                    label: isFr
                                        ? 'Cycle Muraja’a'
                                        : 'Review cycle',
                                    color: const Color(0xFF2B6CB0),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // POINTS DE VIGILANCE (VERSETS / PASSAGES À CONSOLIDER)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orangeAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    Localizations.localeOf(context).languageCode == 'ar' ? 'آيات تحتاج إلى تثبيت ومراجعة' : (isFr ? 'Points de vigilance (Versets à consolider)' : 'Passages to strengthen'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _vigilanceController,
                                    decoration: InputDecoration(
                                      hintText: isFr
                                          ? 'Ex: Al-Baqara v.255 (liaison) ou p.42'
                                          : 'Ex: Al-Baqara v.255 or p.42',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () async {
                                    final txt =
                                        _vigilanceController.text.trim();
                                    if (txt.isEmpty) return;
                                    setState(() {
                                      _vigilanceNotes.add(txt);
                                      _vigilanceController.clear();
                                    });
                                    await _saveVigilanceNotes();
                                  },
                                  child: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'حفظ' : (isFr ? 'Noter' : 'Save')),
                                ),
                              ],
                            ),
                            if (_vigilanceNotes.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _vigilanceNotes.map((note) {
                                  return Chip(
                                    label: Text(note.toString()),
                                    deleteIcon:
                                        const Icon(Icons.check_circle_outline, size: 18),
                                    onDeleted: () async {
                                      setState(() {
                                        _vigilanceNotes.remove(note);
                                      });
                                      await _saveVigilanceNotes();
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrajectoryCard({
    required BuildContext context,
    required bool isFr,
    bool isReverse = false,
    required DateTime now,
    required int startPage,
    required int endPage,
    required int doneLines,
    required int totalLines,
    required int remainingLines,
    required int remainingStudyDays,
    required int smartDailyLines,
    required double progressRatio,
    required int progressPct,
  }) {
    DateTime addStudyDays(DateTime start, int studyDaysNeeded) {
      if (studyDaysNeeded <= 0) return start;
      DateTime cursor = DateTime(start.year, start.month, start.day);
      int counted = 0;
      while (counted < studyDaysNeeded) {
        cursor = cursor.add(const Duration(days: 1));
        if (!_restDays.contains(cursor.weekday)) {
          counted++;
        }
      }
      return cursor;
    }

    String formatDateFr(DateTime d) {
    final isArMonths = Localizations.localeOf(context).languageCode == 'ar';
    final months = isArMonths
        ? ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر']
        : ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    }

    final int dailyPace = smartDailyLines > 0 ? smartDailyLines : 15;
    final List milestones = [];

    final checkpoints = [
      {'days': 7, 'label': Localizations.localeOf(context).languageCode == 'ar' ? 'بعد ٧ أيام' : (isFr ? 'Dans 7 jours' : 'In 7 days')},
      {'days': 30, 'label': Localizations.localeOf(context).languageCode == 'ar' ? 'بعد شهر واحد' : (isFr ? 'Dans 1 mois' : 'In 1 month')},
      {'days': 90, 'label': Localizations.localeOf(context).languageCode == 'ar' ? 'بعد ٣ أشهر' : (isFr ? 'Dans 3 mois' : 'In 3 months')},
    ];

    for (final cp in checkpoints) {
      final int d = cp['days'] as int;
      if (d < remainingStudyDays && remainingLines > 0) {
        final int projectedLines =
            (doneLines + (d * dailyPace)).clamp(0, totalLines);
        final int projectedPct = ((projectedLines / totalLines) * 100).round();
        final int projectedPage = (isReverse
                ? (endPage - (projectedLines / 15.0)).ceil()
                : (startPage + (projectedLines / 15.0)).floor())
            .clamp(startPage, endPage);
        final surahAtPage = QuranMetadata.getSurahForPage(projectedPage);
        final DateTime realDate = addStudyDays(now, d);

        milestones.add({
          'title': '${cp['label']} (${formatDateFr(realDate)})',
          'subtitle': isFr
              ? 'Sourate ${surahAtPage.nameTranslit} • Page $projectedPage ($projectedPct%)'
              : 'Surah ${surahAtPage.nameTranslit} • Page $projectedPage ($projectedPct%)',
          'isFinal': false,
        });
      }
    }

    final int daysToFinish =
        remainingLines == 0 ? 0 : (remainingLines / dailyPace).ceil();
    final DateTime finishDate = addStudyDays(now, daysToFinish);
    final int finalTargetPage = isReverse ? startPage : endPage;
    final endSurah = QuranMetadata.getSurahForPage(finalTargetPage);

    milestones.add({
      'title': remainingLines == 0
          ? (isFr ? 'Objectif accompli !' : 'Goal completed!')
          : (isFr
              ? 'But final (${formatDateFr(finishDate)})'
              : 'Final goal (${formatDateFr(finishDate)})'),
      'subtitle': isFr
          ? 'Fin de ${endSurah.nameTranslit} • Page $finalTargetPage (100%)'
          : 'End of ${endSurah.nameTranslit} • Page $finalTargetPage (100%)',
      'isFinal': true,
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 66,
                  height: 66,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progressRatio,
                        strokeWidth: 7,
                        backgroundColor: Colors.grey.withValues(alpha: 0.18),
                        color: TadarrujColors.emeraldPrimary,
                      ),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar' ? '${_arDigits(progressPct)}٪' : '$progressPct%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar' ? 'التوقعات نحو الهدف النهائي' : (isFr ? 'Projection vers le but final' : 'Trajectory to final goal'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFr
                            ? (Localizations.localeOf(context).languageCode == 'ar' ? _arDigits('بمعدل $dailyPace سطراً في يوم الدراسة، إليك محطاتك القادمة:') : 'Au rythme de $dailyPace lignes / jour d’étude, voici tes paliers :')
                            : 'At $dailyPace lines / study day, here are your milestones:',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            if (!ref.watch(isPremiumProvider))
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TadarrujColors.goldAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TadarrujColors.goldAccent.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, size: 18, color: TadarrujColors.goldAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFr
                            ? 'Version gratuite : projection sur 7 jours. Débloquez l’horizon complet & les Halaqas avec Tadarruj+.'
                            : 'Free plan: 7-day projection. Unlock full trajectory & Halaqas with Tadarruj+.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ...(ref.watch(isPremiumProvider) ? milestones : milestones.take(1)).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value as Map;
              final bool isFinal = m['isFinal'] as bool;
              final bool isLast = idx == milestones.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFinal
                              ? TadarrujColors.goldAccent
                              : TadarrujColors.emeraldPrimary,
                        ),
                        child: Icon(
                          isFinal
                              ? Icons.emoji_events_rounded
                              : Icons.flag_rounded,
                          size: 13,
                          color: isFinal ? Colors.black : Colors.white,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 26,
                          color: TadarrujColors.emeraldPrimary
                              .withValues(alpha: 0.35),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['title'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color:
                                  isFinal ? TadarrujColors.goldAccent : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['subtitle'] as String,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickAddPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _QuickAddPill({
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(behavior: HitTestBehavior.opaque, 
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? TadarrujColors.goldSoft
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: highlight ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}

class _MiniMetricBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MiniMetricBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _FocusSessionSheet extends StatefulWidget {
  final String goalTitle;
  final int targetLines;
  final bool isFr;
  final void Function(int lines) onValidateSession;

  const _FocusSessionSheet({
    required this.goalTitle,
    required this.targetLines,
    required this.isFr,
    required this.onValidateSession,
  });

  @override
  State<_FocusSessionSheet> createState() => _FocusSessionSheetState();
}

class _FocusSessionSheetState extends State<_FocusSessionSheet> {
  int _seconds = 0;
  int _repetitions = 0;
  bool _running = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_running && mounted) {
        setState(() => _seconds++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatChrono(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isFr ? '🧘 Mode Focus Séance' : '🧘 Focus Session Mode',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            widget.goalTitle,
            style: const TextStyle(
              color: TadarrujColors.emeraldPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _formatChrono(_seconds),
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _running = !_running),
                icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_running
                    ? (widget.isFr ? 'Pause' : 'Pause')
                    : (widget.isFr ? 'Reprendre' : 'Resume')),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: TadarrujColors.goldAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => setState(() => _repetitions++),
                icon: const Icon(Icons.repeat_one_rounded),
                label: Text(
                  widget.isFr
                      ? 'Répétitions : $_repetitions / 10'
                      : 'Repetitions: $_repetitions / 10',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: TadarrujColors.emeraldPrimary,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onValidateSession(widget.targetLines);
              },
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                widget.isFr
                    ? 'Terminer & valider ${widget.targetLines} lignes'
                    : 'Finish & log ${widget.targetLines} lines',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}