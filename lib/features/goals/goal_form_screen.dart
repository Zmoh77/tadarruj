import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_mapper.dart';
import '../../core/hizb_divisions.dart';
import '../../core/quran_metadata.dart';
import '../../core/tadarruj_brand.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_repository.dart';
import '../progress/progress_repository.dart';
import '../today/today_repository.dart';
import 'goals_repository.dart';

enum GoalScopeType { surahVerse, hizb, pages }

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key});

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  String _activity = 'memorisation';
  GoalScopeType _scopeType = GoalScopeType.surahVerse;

  // Mode Sourate & Verset
  int _startSurah = 2; // Al-Baqara
  int _startVerse = 1;
  int _endSurah = 2;
  int _endVerse = 141;

  // Mode Hizb
  int _startHizb = 1;
  int _endHizb = 2;

  // Mode Pages
  int _startPage = 1;
  int _endPage = 20;

  DateTime _targetDate = DateTime.now().add(const Duration(days: 30));
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// Calcule la plage exacte (startPos, endPos, pages, lignes, hizbLabel)
  ({
    double startPos,
    double endPos,
    double totalPages,
    int totalLines,
    double totalHizb,
    String hizbRangeText,
    String autoTitle,
    bool isReverse,
  }) _computeCalculation(bool isFr) {
    double sPos = 0.0;
    double ePos = 10.0;
    String autoTitle = '';
    bool isReverse = false;

    if (_scopeType == GoalScopeType.surahVerse) {
      final s1 = QuranMetadata.getSurahByNumber(_startSurah);
      final s2 = QuranMetadata.getSurahByNumber(_endSurah);
      final v1 = _startVerse.clamp(1, s1.verseCount);
      final v2 = _endVerse.clamp(1, s2.verseCount);

      isReverse = (_startSurah > _endSurah) || (_startSurah == _endSurah && v1 > v2);
      if (!isReverse) {
        sPos = QuranMetadata.getPositionForSurahVerse(
          surahNumber: s1.number,
          verseNumber: v1,
          isEnd: false,
        );
        ePos = QuranMetadata.getPositionForSurahVerse(
          surahNumber: s2.number,
          verseNumber: v2,
          isEnd: true,
        );
        if (ePos <= sPos) ePos = (sPos + 0.5).clamp(0.1, 604.0);
      } else {
        sPos = QuranMetadata.getPositionForSurahVerse(
          surahNumber: s1.number,
          verseNumber: v1,
          isEnd: true,
        );
        ePos = QuranMetadata.getPositionForSurahVerse(
          surahNumber: s2.number,
          verseNumber: v2,
          isEnd: false,
        );
        if (sPos <= ePos) ePos = (sPos - 0.5).clamp(0.0, 603.5);
      }

      autoTitle = s1.number == s2.number
          ? '${s1.nameTranslit} ($v1 → $v2)'
          : '${s1.nameTranslit} (${s1.number}:$v1) → ${s2.nameTranslit} (${s2.number}:$v2)';
    } else if (_scopeType == GoalScopeType.hizb) {
      final h1 = HizbDivisions.all[(_startHizb - 1).clamp(0, 59)];
      final h2 = HizbDivisions.all[(_endHizb - 1).clamp(0, 59)];
      isReverse = _startHizb > _endHizb;
      if (!isReverse) {
        sPos = (h1.startPage - 1).toDouble();
        ePos = h2.endPage.toDouble();
        if (ePos <= sPos) ePos = (sPos + 10.0).clamp(1.0, 604.0);
      } else {
        sPos = h1.endPage.toDouble();
        ePos = (h2.startPage - 1).toDouble();
      }
      autoTitle = h1.number == h2.number
          ? 'Hizb ${h1.number} (${h1.rangeLabel})'
          : 'Hizb ${h1.number} → ${h2.number}';
    } else {
      isReverse = _startPage > _endPage;
      if (!isReverse) {
        sPos = (_startPage - 1).clamp(0, 603).toDouble();
        ePos = _endPage.clamp(1, 604).toDouble();
      } else {
        sPos = _startPage.clamp(1, 604).toDouble();
        ePos = (_endPage - 1).clamp(0, 603).toDouble();
      }
      autoTitle = isFr
          ? 'Pages $_startPage → $_endPage'
          : 'Pages $_startPage → $_endPage';
    }

    final double totalPages = (ePos - sPos).abs().clamp(0.1, 604.0);
    final int totalLines = (totalPages * 15).round().clamp(1, 9060);
    final double totalHizb = totalPages / 10.06;

    final double lowPos = sPos < ePos ? sPos : ePos;
    final double highPos = sPos < ePos ? ePos : sPos;
    final int pLow = (lowPos.floor() + 1).clamp(1, 604);
    final int pHigh = highPos.ceil().clamp(1, 604);
    final hStart = HizbDivisions.getForPage(isReverse ? pHigh : pLow).number;
    final hEnd = HizbDivisions.getForPage(isReverse ? pLow : pHigh).number;
    final hizbRangeText = hStart == hEnd ? 'Hizb $hStart' : 'Hizb $hStart → $hEnd';

    return (
      startPos: sPos,
      endPos: ePos,
      totalPages: totalPages,
      totalLines: totalLines,
      totalHizb: totalHizb,
      hizbRangeText: hizbRangeText,
      autoTitle: autoTitle,
      isReverse: isReverse,
    );
  }

  int _countStudyDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime cursor = DateTime(start.year, start.month, start.day);
    final limit = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(limit)) {
      if (_selectedDays.contains(cursor.weekday)) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count > 0 ? count : 1;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final isFr = Localizations.localeOf(context).languageCode != 'en';

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((isFr ? 'Sélectionne au moins un jour d’étude.' : 'Select at least one study day.'))),
      );
      return;
    }

    final calc = _computeCalculation(isFr);
    final finalTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : calc.autoTitle;

    setState(() => _isSaving = true);
    try {
      await ref.read(goalsRepositoryProvider).createGoalAndSchedule(
            title: finalTitle,
            activity: _activity,
            startPos: calc.startPos,
            endPos: calc.endPos,
            targetDate: _targetDate,
            weekdays: _selectedDays.toList()..sort(),
          );
      ref.invalidate(goalsListProvider);
      ref.invalidate(todayTasksProvider);
      ref.invalidate(calendarTasksByDateProvider);
      ref.invalidate(progressSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TadarrujColors.emeraldPrimary,
            content: Text((isFr ? 'Objectif créé et planifié avec succès !' : 'Goal created and scheduled successfully!')),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapAuthError(e, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFr = Localizations.localeOf(context).languageCode != 'en';
    final calc = _computeCalculation(isFr);
    final studyDays = _countStudyDays(DateTime.now(), _targetDate);
    final dailyLines = (calc.totalLines / studyDays).ceil();
    final dailyPages = calc.totalPages / studyDays;

    final dayLabels = [
      (1, (isFr ? 'Lun' : 'Mon')),
      (2, (isFr ? 'Mar' : 'Tue')),
      (3, (isFr ? 'Mer' : 'Wed')),
      (4, (isFr ? 'Jeu' : 'Thu')),
      (5, (isFr ? 'Ven' : 'Fri')),
      (6, (isFr ? 'Sam' : 'Sat')),
      (7, (isFr ? 'Dim' : 'Sun')),
    ];

    return Scaffold(
      appBar: TadarrujAppBar(title: (isFr ? 'Nouvel objectif' : 'New goal')),
      body: Stack(
        children: [
          const IslamicPatternOverlay(opacity: 0.04),
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // 1. Activité
                Text(
                  (isFr ? 'Type d’activité' : 'Activity type'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'lecture',
                      label: Text((isFr ? 'Lecture' : 'Reading')),
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                    ButtonSegment(
                      value: 'memorisation',
                      label: Text((isFr ? 'Mémorisation' : 'Memorization')),
                      icon: const Icon(Icons.psychology_outlined),
                    ),
                    ButtonSegment(
                      value: 'revision',
                      label: Text((isFr ? 'Révision' : 'Revision')),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                  selected: {_activity},
                  onSelectionChanged: (sel) =>
                      setState(() => _activity = sel.first),
                ),
                const SizedBox(height: 18),

                // 2. Mode de sélection : Sourate & Verset | Hizb | Pages
                Text(
                  isFr ? 'Définir le passage par :' : 'Select range by:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                SegmentedButton<GoalScopeType>(
                  segments: [
                    ButtonSegment(
                      value: GoalScopeType.surahVerse,
                      label: Text(isFr ? 'Sourate & Verset' : 'Surah & Verse'),
                    ),
                    ButtonSegment(
                      value: GoalScopeType.hizb,
                      label: const Text('Hizb'),
                    ),
                    ButtonSegment(
                      value: GoalScopeType.pages,
                      label: Text(isFr ? 'Pages' : 'Pages'),
                    ),
                  ],
                  selected: {_scopeType},
                  onSelectionChanged: (sel) =>
                      setState(() => _scopeType = sel.first),
                ),
                const SizedBox(height: 16),

                // 3. Sélecteurs dynamiques selon le mode choisi
                if (_scopeType == GoalScopeType.surahVerse)
                  _buildSurahVerseSelectors(isFr)
                else if (_scopeType == GoalScopeType.hizb)
                  _buildHizbSelectors(isFr)
                else
                  _buildPageSelectors(isFr),

                const SizedBox(height: 16),

                // 4. Carte de calcul automatique en temps réel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF155740),
                        Color(0xFF287D5C),
                      ],
                    ),
                    border: Border.all(
                      color: TadarrujColors.goldAccent.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_rounded,
                              color: TadarrujColors.goldSoft, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isFr
                                ? 'CALCUL AUTOMATIQUE DU PASSAGE'
                                : 'AUTOMATIC RANGE CALCULATION',
                            style: const TextStyle(
                              color: TadarrujColors.goldSoft,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        calc.autoTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _CalcChip(
                            label:
                                '${calc.totalPages.toStringAsFixed(1)} pages',
                          ),
                          _CalcChip(
                            label: '${calc.totalLines} lignes',
                          ),
                          _CalcChip(
                            label:
                                '${calc.totalHizb.toStringAsFixed(2)} hizb (${calc.hizbRangeText})',
                          ),
                          _CalcChip(
                            label: calc.isReverse
                                ? (isFr ? 'Sens inversé (Fin → Début)' : 'Reverse order (End → Start)')
                                : (isFr ? 'Sens croissant (Début → Fin)' : 'Forward order (Start → End)'),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Text(
                        isFr
                            ? 'Rythme conseillé sur $studyDays jour(s) d’étude : $dailyLines lignes / jour (≈ ${dailyPages.toStringAsFixed(1)} p./j)'
                            : 'Recommended pace over $studyDays study day(s): $dailyLines lines/day (≈ ${dailyPages.toStringAsFixed(1)} p./d)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Titre personnalisé (optionnel, rempli automatiquement sinon)
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: isFr
                        ? 'Titre de l’objectif (optionnel)'
                        : 'Goal title (optional)',
                    hintText: calc.autoTitle,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Date cible
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  leading: const Icon(Icons.event_outlined),
                  title: Text((isFr ? 'Date cible' : 'Target date')),
                  subtitle: Text(
                    '${_targetDate.day.toString().padLeft(2, '0')}/${_targetDate.month.toString().padLeft(2, '0')}/${_targetDate.year}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),

                // 7. Jours de la semaine
                Text(
                  (isFr ? 'Jours d’étude par semaine' : 'Study days per week'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dayLabels.map((entry) {
                    final dayNum = entry.$1;
                    final label = entry.$2;
                    final selected = _selectedDays.contains(dayNum);
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedDays.add(dayNum);
                          } else {
                            _selectedDays.remove(dayNum);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      (isFr ? 'Créer et planifier l’objectif' : 'Create and schedule goal'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahVerseSelectors(bool isFr) {
    final sStart = QuranMetadata.getSurahByNumber(_startSurah);
    final sEnd = QuranMetadata.getSurahByNumber(_endSurah);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFr ? 'DEPUIS (Sourate & Verset)' : 'FROM (Surah & Verse)',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: TadarrujColors.goldAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    value: _startSurah,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isFr ? 'Sourate début' : 'Start surah',
                      border: const OutlineInputBorder(),
                    ),
                    items: QuranMetadata.surahs.map((s) {
                      return DropdownMenuItem<int>(
                        value: s.number,
                        child: Text(
                          '${s.number}. ${s.nameTranslit} (${s.verseCount} v.)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _startSurah = val;
                        _startVerse = 1;

                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _startVerse.clamp(1, sStart.verseCount),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isFr ? 'Verset' : 'Verse',
                      border: const OutlineInputBorder(),
                    ),
                    items: List.generate(sStart.verseCount, (i) => i + 1)
                        .map((v) => DropdownMenuItem<int>(
                              value: v,
                              child: Text('Verset $v'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _startVerse = val;

                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isFr ? 'JUSQU’À (Sourate & Verset)' : 'TO (Surah & Verse)',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: TadarrujColors.goldAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    value: _endSurah,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isFr ? 'Sourate fin' : 'End surah',
                      border: const OutlineInputBorder(),
                    ),
                    items: QuranMetadata.surahs
                        .map((s) {
                      return DropdownMenuItem<int>(
                        value: s.number,
                        child: Text(
                          '${s.number}. ${s.nameTranslit} (${s.verseCount} v.)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final targetS = QuranMetadata.getSurahByNumber(val);
                      setState(() {
                        _endSurah = val;
                        _endVerse = targetS.verseCount;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _endVerse.clamp(1, sEnd.verseCount),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isFr ? 'Verset' : 'Verse',
                      border: const OutlineInputBorder(),
                    ),
                    items: List.generate(sEnd.verseCount, (i) => i + 1)
                        .map((v) => DropdownMenuItem<int>(
                              value: v,
                              child: Text('Verset $v'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _endVerse = val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHizbSelectors(bool isFr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: _startHizb,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isFr ? 'Hizb de début' : 'Start Hizb',
                border: const OutlineInputBorder(),
              ),
              items: HizbDivisions.all.map((h) {
                return DropdownMenuItem<int>(
                  value: h.number,
                  child: Text(
                    'Hizb ${h.number} • ${h.rangeLabel}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _startHizb = val;
                    
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _endHizb,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isFr ? 'Hizb de fin' : 'End Hizb',
                border: const OutlineInputBorder(),
              ),
              items: HizbDivisions.all
                      .map((h) {
                return DropdownMenuItem<int>(
                  value: h.number,
                  child: Text(
                    'Hizb ${h.number} • ${h.rangeLabel}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _endHizb = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageSelectors(bool isFr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _startPage,
                decoration: InputDecoration(
                  labelText: isFr ? 'Page début' : 'Start page',
                  border: const OutlineInputBorder(),
                ),
                items: List.generate(604, (i) => i + 1)
                    .map((p) => DropdownMenuItem<int>(
                          value: p,
                          child: Text('Page $p'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _startPage = val;
                      
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _endPage,
                decoration: InputDecoration(
                  labelText: isFr ? 'Page fin' : 'End page',
                  border: const OutlineInputBorder(),
                ),
                items: List.generate(604, (i) => i + 1)
                    .map((p) => DropdownMenuItem<int>(
                          value: p,
                          child: Text('Page $p'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _endPage = val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalcChip extends StatelessWidget {
  final String label;
  const _CalcChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
