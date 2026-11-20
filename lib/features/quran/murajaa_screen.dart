import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/quran_metadata.dart';
import '../../core/tadarruj_brand.dart';
import '../goals/goals_repository.dart';
import '../progress/memory_health_repository.dart';

enum MurajaaMethod {
  continueVerse, // A. Continuer un verset
  previousVerse, // B. Retrouver le verset précédent
  nextVerse,     // C. Retrouver le verset suivant
  blindRecite,   // D. Récitation sans texte
  randomPassage, // E. Passage aléatoire
  targetedWeak,  // F. Révision ciblée (fragiles)
}

class _AyahItem {
  final int surahNumber;
  final int ayahNumber;
  final String textArabic;
  const _AyahItem({
    required this.surahNumber,
    required this.ayahNumber,
    required this.textArabic,
  });
}

class MurajaaScreen extends ConsumerStatefulWidget {
  final MurajaaMethod initialMethod;
  final int? initialSurah;

  const MurajaaScreen({
    super.key,
    this.initialMethod = MurajaaMethod.continueVerse,
    this.initialSurah,
  });

  @override
  ConsumerState<MurajaaScreen> createState() => _MurajaaScreenState();
}

class _MurajaaScreenState extends ConsumerState<MurajaaScreen> {
  late MurajaaMethod _method;
  int _selectedSurah = 67; // Al-Mulk par défaut si aucun passage encore enregistré
  bool _loading = false;
  bool _revealed = false;
  String? _error;

  List<_AyahItem> _surahVerses = [];
  int _currentIndex = 0;
  int _reviewedSessionCount = 0;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;
    if (widget.initialSurah != null) {
      _selectedSurah = widget.initialSurah!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSmartSelection();
    });
  }

  String _toArDigits(Object v) {
    const w = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const e = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var s = v.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(w[i], e[i]);
    }
    return s;
  }

  Future<void> _initSmartSelection() async {
    final mastery = ref.read(passageMasteryListProvider).valueOrNull ?? [];
    final goals = ref.read(goalsListProvider).valueOrNull ?? [];

    if (widget.initialSurah == null) {
      final weak = mastery
          .where((m) =>
              m.level == MasteryLevel.fragile ||
              m.level == MasteryLevel.consolidating)
          .toList();
      if (_method == MurajaaMethod.targetedWeak && weak.isNotEmpty) {
        _selectedSurah = weak.first.surahNumber;
      } else if (_method == MurajaaMethod.randomPassage && mastery.isNotEmpty) {
        final pick = mastery[Random().nextInt(mastery.length)];
        _selectedSurah = pick.surahNumber;
      } else if (goals.isNotEmpty) {
        _selectedSurah = QuranMetadata.getSurahForPage(goals.first.startPage).number;
      }
    }
    await _fetchSurahVerses(_selectedSurah);
  }

  Future<void> _fetchSurahVerses(int surahNum) async {
    setState(() {
      _loading = true;
      _error = null;
      _revealed = false;
      _selectedSurah = surahNum;
    });

    try {
      final uri = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_chapter/$surahNum?words=false&fields=text_uthmani&per_page=300',
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (decoded['verses'] as List?) ?? [];

      final parsed = <_AyahItem>[];
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final key = (m['verse_key'] as String?) ?? '$surahNum:1';
        final ayahNum = int.tryParse(key.split(':').last) ?? 1;
        parsed.add(
          _AyahItem(
            surahNumber: surahNum,
            ayahNumber: ayahNum,
            textArabic: ((m['text_uthmani'] as String?) ?? '').trim(),
          ),
        );
      }

      if (!mounted) return;
      int startIdx = 0;
      if (_method == MurajaaMethod.previousVerse && parsed.length > 1) {
        startIdx = 1;
      } else if (_method == MurajaaMethod.randomPassage && parsed.isNotEmpty) {
        startIdx = Random().nextInt(parsed.length);
      }

      setState(() {
        _surahVerses = parsed;
        _currentIndex = startIdx;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _nextExercise() {
    if (_surahVerses.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _revealed = false;
      if (_method == MurajaaMethod.randomPassage) {
        _currentIndex = Random().nextInt(_surahVerses.length);
      } else {
        _currentIndex = (_currentIndex + 1) % _surahVerses.length;
        if (_method == MurajaaMethod.previousVerse && _currentIndex == 0 && _surahVerses.length > 1) {
          _currentIndex = 1;
        }
      }
    });
  }

  Future<void> _submitRating(String rating, bool isAr, bool isFr) async {
    if (_surahVerses.isEmpty) return;
    final current = _surahVerses[_currentIndex];
    HapticFeedback.lightImpact();

    await ref.read(memoryHealthRepositoryProvider).recordReviewEvaluation(
          surahNumber: current.surahNumber,
          ayahFrom: current.ayahNumber,
          ayahTo: current.ayahNumber,
          rating: rating,
          difficultyType: rating == 'mastered'
              ? null
              : (isAr
                  ? 'مراجعة نشطة (Murāja’a)'
                  : (isFr ? 'Rappel actif (Murāja’a)' : 'Active recall (Murāja’a)')),
        );
    ref.invalidate(passageMasteryListProvider);

    setState(() {
      _reviewedSessionCount += 1;
    });
    _nextExercise();
  }

  String _methodTitle(MurajaaMethod m, bool isAr, bool isFr) {
    switch (m) {
      case MurajaaMethod.continueVerse:
        return isAr
            ? 'أ. إكمال الآية'
            : (isFr ? 'A. Continuer un verset' : 'A. Continue verse');
      case MurajaaMethod.previousVerse:
        return isAr
            ? 'ب. الآية السابقة'
            : (isFr ? 'B. Verset précédent' : 'B. Previous verse');
      case MurajaaMethod.nextVerse:
        return isAr
            ? 'ج. الآية التالية'
            : (isFr ? 'C. Verset suivant' : 'C. Next verse');
      case MurajaaMethod.blindRecite:
        return isAr
            ? 'د. تلاوة دون نص'
            : (isFr ? 'D. Récitation sans texte' : 'D. Recite without text');
      case MurajaaMethod.randomPassage:
        return isAr
            ? 'هـ. مقطع عشوائي'
            : (isFr ? 'E. Passage aléatoire' : 'E. Random passage');
      case MurajaaMethod.targetedWeak:
        return isAr
            ? 'و. مراجعة المواضع الضعيفة'
            : (isFr ? 'F. Révision ciblée' : 'F. Targeted review');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final isAr = lang == 'ar';
    final isFr = lang == 'fr';
    final surahMeta = QuranMetadata.getSurahByNumber(_selectedSurah);
    final masteryList = ref.watch(passageMasteryListProvider).valueOrNull ?? [];
    final weakCount = masteryList
        .where((m) =>
            m.level == MasteryLevel.fragile ||
            m.level == MasteryLevel.consolidating)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr
              ? 'المراجعة الذكية (Murāja’a)'
              : (isFr ? 'Révision active (Murāja’a)' : 'Active Revision (Murāja’a)'),
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Sélecteur des 6 méthodes A..F
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: MurajaaMethod.values.map((m) {
                final selected = _method == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: RawChip(showCheckmark: false, 
                    selected: selected,
                    selectedColor: TadarrujColors.emeraldDeep,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : TadarrujColors.inkPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    label: Text(_methodTitle(m, isAr, isFr)),
                    onSelected: (_) {
                      setState(() {
                        _method = m;
                        _revealed = false;
                      });
                      if (m == MurajaaMethod.targetedWeak ||
                          m == MurajaaMethod.randomPassage) {
                        _initSmartSelection();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Sélecteur sobre de Sourate
          DropdownButtonFormField<int>(
            value: _selectedSurah,
            decoration: InputDecoration(
              filled: true,
              fillColor: TadarrujColors.beigeSoft,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: TadarrujColors.cardBorder),
              ),
            ),
            items: QuranMetadata.surahs.map((s) {
              return DropdownMenuItem<int>(
                value: s.number,
                child: Text(
                  isAr
                      ? '${_toArDigits(s.number)}. سورة ${s.nameArabic}'
                      : '${s.number}. ${s.nameTranslit} (${s.nameArabic})',
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _fetchSurahVerses(val);
            },
          ),

          if (_method == MurajaaMethod.targetedWeak && weakCount == 0) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isAr
                      ? 'لا توجد مواضع ضعيفة مسجلة حالياً. قيّم تلاوتك بعد أي جلسة لتظهر هنا تلقائياً.'
                      : (isFr
                          ? 'Aucun passage fragile enregistré pour le moment. Évalue tes récitations pour alimenter ce mode.'
                          : 'No fragile passages recorded yet. Rate your recitations to populate this mode.'),
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      isAr
                          ? 'تعذر تحميل الآيات (وضع عدم الاتصال).'
                          : (isFr
                              ? 'Impossible de charger les versets.'
                              : 'Unable to load verses.'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _fetchSurahVerses(_selectedSurah),
                      child: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_surahVerses.isNotEmpty)
            _buildExerciseCard(surahMeta, isAr, isFr),

          if (_reviewedSessionCount > 0) ...[
            const SizedBox(height: 14),
            Text(
              isAr
                  ? 'تمت مراجعة ${_toArDigits(_reviewedSessionCount)} آية في هذه الجلسة'
                  : (isFr
                      ? '$_reviewedSessionCount verset(s) révisé(s) dans cette séance'
                      : '$_reviewedSessionCount verse(s) reviewed in this session'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseCard(SurahInfo surahMeta, bool isAr, bool isFr) {
    final current = _surahVerses[_currentIndex];
    final prevVerse =
        _currentIndex > 0 ? _surahVerses[_currentIndex - 1] : null;
    final nextVerse = _currentIndex + 1 < _surahVerses.length
        ? _surahVerses[_currentIndex + 1]
        : null;

    String promptInstruction = '';
    String visiblePromptArabic = '';
    String hiddenTargetArabic = current.textArabic;
    int targetAyahNumber = current.ayahNumber;

    switch (_method) {
      case MurajaaMethod.continueVerse:
        promptInstruction = isAr
            ? 'أكمل الآية التالية غيباً ثم اكشف النص للتحقق:'
            : (isFr
                ? 'Poursuis ce verset de mémoire puis révèle le texte :'
                : 'Continue this verse from memory then reveal:');
        final words = current.textArabic.split(' ');
        visiblePromptArabic = words.length > 3
            ? '${words.take(3).join(' ')} ...'
            : current.textArabic;
        hiddenTargetArabic = current.textArabic;
        break;

      case MurajaaMethod.previousVerse:
        promptInstruction = isAr
            ? 'اتلُ الآية التي تسبق هذه الآية مباشرة:'
            : (isFr
                ? 'Récite le verset qui précède immédiatement celui-ci :'
                : 'Recite the verse immediately preceding this one:');
        visiblePromptArabic =
            '${current.textArabic} ﴿${_toArDigits(current.ayahNumber)}﴾';
        hiddenTargetArabic = prevVerse != null
            ? '${prevVerse.textArabic} ﴿${_toArDigits(prevVerse.ayahNumber)}﴾'
            : (isAr ? 'بداية السورة' : 'Début de la sourate');
        targetAyahNumber = prevVerse?.ayahNumber ?? current.ayahNumber;
        break;

      case MurajaaMethod.nextVerse:
        promptInstruction = isAr
            ? 'اتلُ الآية التي تلي هذه الآية مباشرة:'
            : (isFr
                ? 'Récite le verset qui suit immédiatement celui-ci :'
                : 'Recite the verse immediately following this one:');
        visiblePromptArabic =
            '${current.textArabic} ﴿${_toArDigits(current.ayahNumber)}﴾';
        hiddenTargetArabic = nextVerse != null
            ? '${nextVerse.textArabic} ﴿${_toArDigits(nextVerse.ayahNumber)}﴾'
            : (isAr ? 'نهاية السورة' : 'Fin de la sourate');
        targetAyahNumber = nextVerse?.ayahNumber ?? current.ayahNumber;
        break;

      case MurajaaMethod.blindRecite:
        promptInstruction = isAr
            ? 'اتلُ هذا المقطع غيباً دون النظر إلى النص:'
            : (isFr
                ? 'Récite ce passage sans texte puis affiche-le pour vérifier :'
                : 'Recite this passage without text then reveal to check:');
        visiblePromptArabic = isAr
            ? 'سورة ${surahMeta.nameArabic} — الآية ${_toArDigits(current.ayahNumber)}'
            : 'Sourate ${surahMeta.nameTranslit} — Verset ${current.ayahNumber}';
        hiddenTargetArabic =
            '${current.textArabic} ﴿${_toArDigits(current.ayahNumber)}﴾';
        break;

      case MurajaaMethod.randomPassage:
      case MurajaaMethod.targetedWeak:
        promptInstruction = isAr
            ? 'استحضر الآية رقم ${_toArDigits(current.ayahNumber)} من سورة ${surahMeta.nameArabic}:'
            : (isFr
                ? 'Récite le verset ${current.ayahNumber} de ${surahMeta.nameTranslit} :'
                : 'Recite verse ${current.ayahNumber} of ${surahMeta.nameTranslit}:');
        final words = current.textArabic.split(' ');
        visiblePromptArabic = words.length > 2
            ? '${words.take(2).join(' ')} ...'
            : '﴿${_toArDigits(current.ayahNumber)}﴾';
        hiddenTargetArabic =
            '${current.textArabic} ﴿${_toArDigits(current.ayahNumber)}﴾';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  isAr
                      ? 'سورة ${surahMeta.nameArabic}'
                      : surahMeta.nameTranslit,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TadarrujColors.sageGreen,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  isAr
                      ? 'آية ${_toArDigits(targetAyahNumber)}'
                      : 'Verset $targetAyahNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              promptInstruction,
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TadarrujColors.cardBorder),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  _revealed ? hiddenTargetArabic : visiblePromptArabic,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 25,
                    height: 2.0,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (!_revealed)
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _revealed = true);
                },
                icon: const Icon(Icons.visibility_outlined, size: 19),
                label: Text(
                  isAr
                      ? 'إظهار النص للتحقق'
                      : (isFr ? 'Révéler le texte' : 'Reveal text'),
                ),
              )
            else ...[
              Text(
                isAr
                    ? 'كيف كانت قراءتك؟'
                    : (isFr
                        ? 'Comment était ta récitation ?'
                        : 'How was your recitation?'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submitRating('hard', isAr, isFr),
                      child: Text(
                        isAr ? 'صعب' : (isFr ? 'Difficile' : 'Hard'),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submitRating('hesitant', isAr, isFr),
                      child: Text(
                        isAr ? 'متردد' : (isFr ? 'Hésitant' : 'Hesitant'),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _submitRating('mastered', isAr, isFr),
                      child: Text(
                        isAr ? 'متقن' : (isFr ? 'Maîtrisé' : 'Mastered'),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
