import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/quran_metadata.dart';
import '../../core/tadarruj_brand.dart';
import '../goals/goals_repository.dart';
import '../quran/murajaa_screen.dart';
import '../quran/quran_reader_screen.dart';
import 'memory_health_repository.dart';

enum SurahHifzVisualState {
  notStarted,    // Gris / neutre : non mémorisé
  inProgress,    // Beige doux : mémorisation en cours
  fragile,       // Vert clair : mémorisation fragile
  consolidating, // Vert moyen : en consolidation
  stable,        // Vert profond : mémorisation stable / solide
}

class HifzMapScreen extends ConsumerStatefulWidget {
  const HifzMapScreen({super.key});

  @override
  ConsumerState<HifzMapScreen> createState() => _HifzMapScreenState();
}

class _HifzMapScreenState extends ConsumerState<HifzMapScreen> {
  int? _selectedJuz;  // null = Tout le Coran (114 sourates), 1..30 = filtre Juz
  int? _selectedHizb; // null = tous les Hizb du Juz, 1..60 = filtre Hizb

  int _juzOf(SurahInfo s) => ((s.startPage - 1) ~/ 20 + 1).clamp(1, 30);

  String _toArDigits(Object v) {
    const w = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const e = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var s = v.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(w[i], e[i]);
    }
    return s;
  }

  SurahHifzVisualState _computeSurahState(
    SurahInfo surah,
    List<GoalModel> goals,
    List<PassageMasteryRecord> records,
  ) {
    final surahRecords =
        records.where((r) => r.surahNumber == surah.number).toList();
    if (surahRecords.isNotEmpty) {
      if (surahRecords.any((r) => r.level == MasteryLevel.fragile)) {
        return SurahHifzVisualState.fragile;
      }
      if (surahRecords.any((r) => r.level == MasteryLevel.consolidating)) {
        return SurahHifzVisualState.consolidating;
      }
      return SurahHifzVisualState.stable;
    }

    final coveredByGoal = goals.any((g) =>
        surah.endPage >= g.startPage && surah.startPage <= g.endPage);
    if (coveredByGoal) {
      return SurahHifzVisualState.inProgress;
    }
    return SurahHifzVisualState.notStarted;
  }

  bool _hasRecentReview(int surahNumber, List<PassageMasteryRecord> records) {
    final now = DateTime.now();
    return records.any((r) =>
        r.surahNumber == surahNumber &&
        now.difference(r.lastReviewedAt).inDays <= 7);
  }

  Color _tileFillColor(SurahHifzVisualState state) {
    switch (state) {
      case SurahHifzVisualState.notStarted:
        return const Color(0xFFEDEAE2);
      case SurahHifzVisualState.inProgress:
        return TadarrujColors.beigeSoft;
      case SurahHifzVisualState.fragile:
        return TadarrujColors.sageSoft;
      case SurahHifzVisualState.consolidating:
        return TadarrujColors.sageMedium;
      case SurahHifzVisualState.stable:
        return TadarrujColors.emeraldDeep;
    }
  }

  Color _tileTextColor(SurahHifzVisualState state) {
    return state == SurahHifzVisualState.stable
        ? Colors.white
        : TadarrujColors.inkPrimary;
  }

  void _openSurahDetailSheet(
    SurahInfo surah,
    SurahHifzVisualState state,
    List<PassageMasteryRecord> records,
    bool isAr,
    bool isFr,
  ) {
    final surahRecs =
        records.where((r) => r.surahNumber == surah.number).toList();
    final totalReviews =
        surahRecs.fold<int>(0, (sum, r) => sum + r.reviewCount);
    final fragileCount =
        surahRecs.where((r) => r.level == MasteryLevel.fragile).length;
    final solidCount = surahRecs
        .where((r) =>
            r.level == MasteryLevel.stable || r.level == MasteryLevel.solid)
        .length;
    final difficulties = surahRecs
        .map((r) => r.difficultyType)
        .whereType<String>()
        .toSet()
        .toList();

    DateTime? lastRev;
    DateTime? nextRev;
    for (final r in surahRecs) {
      if (lastRev == null || r.lastReviewedAt.isAfter(lastRev)) {
        lastRev = r.lastReviewedAt;
      }
      if (nextRev == null || r.nextReviewAt.isBefore(nextRev)) {
        nextRev = r.nextReviewAt;
      }
    }

    String fmtDate(DateTime? d) {
      if (d == null) return '—';
      final raw =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      return isAr ? _toArDigits(raw) : raw;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TadarrujColors.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isAr
                          ? '${_toArDigits(surah.number)}. سورة ${surah.nameArabic}'
                          : '${surah.number}. ${surah.nameTranslit} • ${surah.nameArabic}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                isAr
                    ? _toArDigits(
                        'الجزء ${_juzOf(surah)} • الصفحات ${surah.startPage}–${surah.endPage}')
                    : 'Juz ${_juzOf(surah)} • Pages ${surah.startPage}–${surah.endPage}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 22),
              _DetailRow(
                label: isAr
                    ? 'المقاطع المتقنة / الثابتة'
                    : (isFr ? 'Passages solides' : 'Solid passages'),
                value: isAr ? _toArDigits(solidCount) : '$solidCount',
              ),
              _DetailRow(
                label: isAr
                    ? 'المقاطع الضعيفة'
                    : (isFr ? 'Passages fragiles' : 'Fragile passages'),
                value: isAr ? _toArDigits(fragileCount) : '$fragileCount',
              ),
              _DetailRow(
                label: isAr
                    ? 'عدد المراجعات المنجزة'
                    : (isFr ? 'Nombre de révisions' : 'Review count'),
                value: isAr ? _toArDigits(totalReviews) : '$totalReviews',
              ),
              _DetailRow(
                label: isAr
                    ? 'تاريخ آخر مراجعة'
                    : (isFr ? 'Dernière révision' : 'Last review'),
                value: fmtDate(lastRev),
              ),
              _DetailRow(
                label: isAr
                    ? 'المراجعة القادمة المبرمجة'
                    : (isFr ? 'Prochaine révision' : 'Next scheduled review'),
                value: fmtDate(nextRev),
              ),
              if (difficulties.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  isAr
                      ? 'الصعوبات المسجلة:'
                      : (isFr
                          ? 'Difficultés identifiées :'
                          : 'Identified difficulties:'),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: difficulties
                      .map((d) => Chip(
                            backgroundColor: TadarrujColors.beigeSoft,
                            label: Text(d, style: TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                QuranReaderScreen(initialPage: surah.startPage),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text(
                        isAr
                            ? 'المصحف'
                            : (isFr ? 'Ouvrir Mushaf' : 'Open Mushaf'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MurajaaScreen(
                              initialMethod: MurajaaMethod.continueVerse,
                              initialSurah: surah.number,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.psychology_outlined, size: 18),
                      label: Text(
                        isAr
                            ? 'مراجعة ذكية'
                            : (isFr ? 'Réviser (Murāja’a)' : 'Revise'),
                      ),
                    ),
                  ),
                ],
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

    final goals = ref.watch(goalsListProvider).valueOrNull ?? [];
    final records = ref.watch(passageMasteryListProvider).valueOrNull ?? [];

    // Navigation progressive : Coran (114) -> Juz -> Hizb -> Sourates
    final filteredSurahs = QuranMetadata.surahs.where((s) {
      if (_selectedJuz != null && _juzOf(s) != _selectedJuz) return false;
      if (_selectedHizb != null) {
        final hizbStartPage = ((_selectedHizb! - 1) * 10) + 1;
        final hizbEndPage = (_selectedHizb! * 10).clamp(1, 604);
        if (s.endPage < hizbStartPage || s.startPage > hizbEndPage) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr
              ? 'خريطة حفظي (١١٤ سورة)'
              : (isFr ? 'Carte de mon Hifz' : 'My Hifz Map'),
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          // Fil d'Ariane de navigation progressive : Coran -> Juz -> Hizb
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RawChip(showCheckmark: false, 
                selected: _selectedJuz == null,
                selectedColor: TadarrujColors.emeraldDeep,
                labelStyle: TextStyle(
                  color: _selectedJuz == null
                      ? Colors.white
                      : TadarrujColors.inkPrimary,
                  fontWeight: FontWeight.w700,
                ),
                label: Text(
                  isAr
                      ? 'القرآن كاملاً (١١٤)'
                      : (isFr ? 'Coran entier (114)' : 'Full Quran (114)'),
                ),
                onSelected: (_) => setState(() {
                  _selectedJuz = null;
                  _selectedHizb = null;
                }),
              ),
              DropdownButton<int>(
                value: _selectedJuz,
                hint: Text(isAr ? 'اختر الجزء' : 'Juz’ (1–30)'),
                underline: const SizedBox.shrink(),
                items: List.generate(30, (i) => i + 1)
                    .map((j) => DropdownMenuItem(
                          value: j,
                          child: Text(isAr
                              ? 'الجزء ${_toArDigits(j)}'
                              : 'Juz’ $j'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() {
                  _selectedJuz = val;
                  _selectedHizb = null;
                }),
              ),
              if (_selectedJuz != null)
                DropdownButton<int>(
                  value: _selectedHizb,
                  hint: Text(isAr ? 'الحزب' : 'Hizb'),
                  underline: const SizedBox.shrink(),
                  items: [(_selectedJuz! * 2) - 1, _selectedJuz! * 2]
                      .map((h) => DropdownMenuItem(
                            value: h,
                            child: Text(isAr
                                ? 'الحزب ${_toArDigits(h)}'
                                : 'Hizb $h'),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedHizb = val),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Légende sobre des 5 états + accent révision récente
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _LegendItem(
                color: const Color(0xFFEDEAE2),
                label: isAr
                    ? 'غير محفوظ'
                    : (isFr ? 'Non mémorisé' : 'Not started'),
              ),
              _LegendItem(
                color: TadarrujColors.beigeSoft,
                label: isAr ? 'قيد الحفظ' : (isFr ? 'En cours' : 'In progress'),
              ),
              _LegendItem(
                color: TadarrujColors.sageSoft,
                label: isAr ? 'ضعيف' : (isFr ? 'Fragile' : 'Fragile'),
              ),
              _LegendItem(
                color: TadarrujColors.sageMedium,
                label: isAr
                    ? 'قيد التثبيت'
                    : (isFr ? 'En consolidation' : 'Consolidating'),
              ),
              _LegendItem(
                color: TadarrujColors.emeraldDeep,
                label: isAr ? 'مستقر' : (isFr ? 'Stable' : 'Stable'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grille visuelle des Sourates
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.35,
            ),
            itemCount: filteredSurahs.length,
            itemBuilder: (context, index) {
              final surah = filteredSurahs[index];
              final st = _computeSurahState(surah, goals, records);
              final recent = _hasRecentReview(surah.number, records);

              return GestureDetector(
behavior: HitTestBehavior.opaque,
                onTap: () =>
                    _openSurahDetailSheet(surah, st, records, isAr, isFr),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _tileFillColor(st),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: recent
                          ? TadarrujColors.goldAccent
                          : TadarrujColors.cardBorder,
                      width: recent ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isAr
                            ? _toArDigits(surah.number)
                            : '${surah.number}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _tileTextColor(st).withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAr ? surah.nameArabic : surah.nameTranslit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _tileTextColor(st),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: TadarrujColors.cardBorder),
          ),
        ),
        const SizedBox(width: 5),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
