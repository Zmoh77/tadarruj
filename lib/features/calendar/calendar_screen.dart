import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/quran_metadata.dart';
import '../../core/tadarruj_brand.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_repository.dart';

class _DayActivityStats {
  final int minutes;
  final int newVerses;
  final int reviewVerses;

  const _DayActivityStats({
    this.minutes = 0,
    this.newVerses = 0,
    this.reviewVerses = 0,
  });
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  String _isoKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _toArDigits(Object v) {
    const w = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const e = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var s = v.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(w[i], e[i]);
    }
    return s;
  }

  Map<String, _DayActivityStats> _buildDailyStats(
    Map<String, List<CalendarTaskModel>> tasksByDate,
  ) {
    final Map<String, _DayActivityStats> stats = {};

    tasksByDate.forEach((dateKey, list) {
      int minutes = 0;
      int newVerses = 0;
      int reviewVerses = 0;
      for (final t in list) {
        if (t.isDone) {
          final pages = (t.endPage - t.startPage + 1).clamp(1, 604);
          final lines = pages * 15;
          minutes += (lines * 1.1).round().clamp(5, 60);
          final verses = (lines * 1.1).round();
          if (t.activity == 'memorisation') {
            newVerses += verses;
          } else {
            reviewVerses += verses;
          }
        }
      }
      if (minutes > 0 || newVerses > 0 || reviewVerses > 0) {
        stats[dateKey] = _DayActivityStats(
          minutes: minutes,
          newVerses: newVerses,
          reviewVerses: reviewVerses,
        );
      }
    });

    final rawLogs =
        Supabase.instance.client.auth.currentUser?.userMetadata?['study_logs'];
    if (rawLogs is List) {
      for (final item in rawLogs) {
        if (item is Map<String, dynamic>) {
          final d = (item['date'] as String?) ?? '';
          final lines = (item['lines'] as num?)?.toInt() ?? 0;
          final act = (item['activity'] as String?) ?? 'lecture';
          if (d.isNotEmpty && lines > 0) {
            final prev = stats[d] ?? const _DayActivityStats();
            final mins = (lines * 1.1).round().clamp(3, 60);
            final verses = (lines * 1.1).round();
            stats[d] = _DayActivityStats(
              minutes: prev.minutes + mins,
              newVerses: prev.newVerses + (act == 'memorisation' ? verses : 0),
              reviewVerses:
                  prev.reviewVerses + (act != 'memorisation' ? verses : 0),
            );
          }
        }
      }
    }

    return stats;
  }

  int _consistencyRate(Map<String, _DayActivityStats> stats, int windowDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int activeDays = 0;
    for (int i = 0; i < windowDays; i++) {
      final d = today.subtract(Duration(days: i));
      if ((stats[_isoKey(d)]?.minutes ?? 0) > 0) {
        activeDays++;
      }
    }
    return ((activeDays / windowDays) * 100).round().clamp(0, 100);
  }

  bool _isGentleResumeDay(
    DateTime day,
    Map<String, _DayActivityStats> stats,
  ) {
    if ((stats[_isoKey(day)]?.minutes ?? 0) <= 0) return false;
    for (int i = 1; i <= 3; i++) {
      final prev = day.subtract(Duration(days: i));
      if ((stats[_isoKey(prev)]?.minutes ?? 0) > 0) return false;
    }
    for (int i = 4; i <= 30; i++) {
      final older = day.subtract(Duration(days: i));
      if ((stats[_isoKey(older)]?.minutes ?? 0) > 0) return true;
    }
    return false;
  }

  Color _heatmapCellColor(int minutes, bool isSelected) {
    if (isSelected) return TadarrujColors.emeraldDeep;
    if (minutes <= 0) return Colors.transparent;
    if (minutes < 12) return TadarrujColors.sageSoft;
    if (minutes < 25) return TadarrujColors.sageMedium;
    return TadarrujColors.sageGreen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tasksMapAsync = ref.watch(calendarTasksByDateProvider);
    final theme = Theme.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final isAr = localeCode == 'ar';
    final isFr = localeCode == 'fr';

    final monthLabel = DateFormat.yMMMM(localeCode).format(_focusedMonth);
    final capitalizedMonth = monthLabel.isNotEmpty
        ? monthLabel[0].toUpperCase() + monthLabel.substring(1)
        : monthLabel;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final leadingEmptyCells = (firstDayOfMonth.weekday - 1) % 7;
    final totalCells = leadingEmptyCells + daysInMonth;

    final weekdayHeaders = isAr
        ? const ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح']
        : (isFr
            ? const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
            : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);

    return Scaffold(
      appBar: TadarrujAppBar(title: l10n.navCalendar),
      body: tasksMapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            isAr
                ? 'تعذر تحميل سجل المواظبة حالياً.'
                : (isFr
                    ? 'Impossible de charger le calendrier.'
                    : 'Unable to load calendar.'),
          ),
        ),
        data: (rawMap) {
          final tasksByDate = Map<String, List<CalendarTaskModel>>.from(rawMap);
          final dailyStats = _buildDailyStats(tasksByDate);

          final rate7 = _consistencyRate(dailyStats, 7);
          final rate30 = _consistencyRate(dailyStats, 30);
          final rate90 = _consistencyRate(dailyStats, 90);

          final selectedKey = _isoKey(_selectedDate);
          final selectedTasks = tasksByDate[selectedKey] ?? [];
          final selectedStats =
              dailyStats[selectedKey] ?? const _DayActivityStats();
          final isResumeDay = _isGentleResumeDay(_selectedDate, dailyStats);

          final selectedDateFormatted =
              DateFormat.yMMMMEEEEd(localeCode).format(_selectedDate);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            children: [
              // 1. Philosophie & Taux de constance sur 7, 30 et 90 jours
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isAr
                            ? 'الثبات قبل الكثرة'
                            : (isFr
                                ? 'La constance avant la quantité'
                                : 'Consistency before quantity'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr
                            ? 'كل يوم تعود فيه إلى القرآن هو خطوة مباركة، دون ضغط أو لوم.'
                            : (isFr
                                ? 'Chaque jour consacré au Coran compte, même quelques minutes, à ton propre rythme.'
                                : 'Every day spent with the Quran counts, even a few minutes, at your own pace.'),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ConsistencyPill(
                              period: isAr
                                  ? '٧ أيام'
                                  : (isFr ? '7 jours' : '7 days'),
                              rate: isAr
                                  ? '${_toArDigits(rate7)}٪'
                                  : '$rate7%',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ConsistencyPill(
                              period: isAr
                                  ? '٣٠ يوماً'
                                  : (isFr ? '30 jours' : '30 days'),
                              rate: isAr
                                  ? '${_toArDigits(rate30)}٪'
                                  : '$rate30%',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ConsistencyPill(
                              period: isAr
                                  ? '٩٠ يوماً'
                                  : (isFr ? '90 jours' : '90 days'),
                              rate: isAr
                                  ? '${_toArDigits(rate90)}٪'
                                  : '$rate90%',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Calendrier Heatmap mensuel
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month - 1,
                                  1,
                                );
                              });
                            },
                          ),
                          Text(
                            capitalizedMonth,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month + 1,
                                  1,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: weekdayHeaders
                            .map(
                              (label) => Expanded(
                                child: Center(
                                  child: Text(
                                    label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalCells,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 1.45,
                        ),
                        itemBuilder: (context, index) {
                          if (index < leadingEmptyCells) {
                            return const SizedBox.shrink();
                          }

                          final dayNumber = index - leadingEmptyCells + 1;
                          final cellDate = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month,
                            dayNumber,
                          );
                          final key = _isoKey(cellDate);
                          final isSelected =
                              _isSameDay(cellDate, _selectedDate);
                          final isToday = _isSameDay(cellDate, todayDate);
                          final mins = dailyStats[key]?.minutes ?? 0;
                          final hasPlanned =
                              (tasksByDate[key] ?? []).isNotEmpty;
                          final resumeBadge =
                              _isGentleResumeDay(cellDate, dailyStats);

                          final bgColor = _heatmapCellColor(mins, isSelected);
                          final bool darkText =
                              !isSelected && mins < 25;

                          return GestureDetector(
behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                setState(() => _selectedDate = cellDate),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: resumeBadge
                                      ? TadarrujColors.goldAccent
                                      : (isToday
                                          ? TadarrujColors.emeraldDeep
                                          : TadarrujColors.cardBorder
                                              .withValues(alpha: 0.6)),
                                  width: resumeBadge || isToday ? 1.4 : 0.8,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isAr
                                        ? _toArDigits(dayNumber)
                                        : '$dayNumber',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected || isToday
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: darkText
                                          ? TadarrujColors.inkPrimary
                                          : Colors.white,
                                    ),
                                  ),
                                  if (hasPlanned && mins == 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: TadarrujColors.goldAccent,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Légende discrète de la heatmap
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            isAr ? 'أقل' : (isFr ? 'Moins' : 'Less'),
                            style: TextStyle(
                                fontSize: 11, color: TadarrujColors.warmGrey),
                          ),
                          const SizedBox(width: 6),
                          for (final c in [
                            TadarrujColors.parchment,
                            TadarrujColors.sageSoft,
                            TadarrujColors.sageMedium,
                            TadarrujColors.sageGreen,
                          ])
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                    color: TadarrujColors.cardBorder),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Text(
                            isAr ? 'أكثر' : (isFr ? 'Plus' : 'More'),
                            style: TextStyle(
                                fontSize: 11, color: TadarrujColors.warmGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3. Détail du jour sélectionné
              Text(
                selectedDateFormatted,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),

              if (isResumeDay) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TadarrujColors.sageSoft.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TadarrujColors.goldAccent),
                  ),
                  child: Text(
                    isAr
                        ? 'عودة مباركة بعد فترة انقطاع — الاستئناف التدريجي هو سر الاستمرار.'
                        : (isFr
                            ? 'Reprise en douceur après une pause — reprendre sereinement est la vraie force.'
                            : 'Gentle return after a break — resuming calmly is the true strength.'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              if (selectedStats.minutes > 0) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DayStatItem(
                          value: isAr
                              ? '${_toArDigits(selectedStats.minutes)} د'
                              : '${selectedStats.minutes} min',
                          label: isAr
                              ? 'الوقت المخصص'
                              : (isFr ? 'Temps consacré' : 'Time spent'),
                        ),
                        _DayStatItem(
                          value: isAr
                              ? _toArDigits(selectedStats.newVerses)
                              : '${selectedStats.newVerses}',
                          label: isAr
                              ? 'آيات محفوظة'
                              : (isFr ? 'Nouveaux versets' : 'New verses'),
                        ),
                        _DayStatItem(
                          value: isAr
                              ? _toArDigits(selectedStats.reviewVerses)
                              : '${selectedStats.reviewVerses}',
                          label: isAr
                              ? 'آيات مراجعة'
                              : (isFr ? 'Versets révisés' : 'Reviewed'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (selectedTasks.isEmpty && selectedStats.minutes == 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      isAr
                          ? 'يوم هادئ بدون جلسات مسجلة.'
                          : (isFr
                              ? 'Journée calme sans séance enregistrée.'
                              : 'Quiet day with no recorded session.'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...selectedTasks.map((task) {
                  final startSurah =
                      QuranMetadata.getSurahForPage(task.startPage);
                  final endSurah = QuranMetadata.getSurahForPage(task.endPage);
                  final bool isDone = task.status == 'done';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          color: isDone
                              ? TadarrujColors.sageGreen
                              : TadarrujColors.warmGrey,
                        ),
                        title: Text(
                          isAr
                              ? (startSurah.number == endSurah.number
                                  ? 'سورة ${startSurah.nameArabic}'
                                  : 'سورة ${startSurah.nameArabic} ← ${endSurah.nameArabic}')
                              : (startSurah.number == endSurah.number
                                  ? startSurah.nameTranslit
                                  : '${startSurah.nameTranslit} → ${endSurah.nameTranslit}'),
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          isAr
                              ? _toArDigits(
                                  'الصفحات ${task.startPage}–${task.endPage}')
                              : 'Pages ${task.startPage}–${task.endPage}',
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _ConsistencyPill extends StatelessWidget {
  final String period;
  final String rate;
  const _ConsistencyPill({required this.period, required this.rate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            rate,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            period,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStatItem extends StatelessWidget {
  final String value;
  final String label;
  const _DayStatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
