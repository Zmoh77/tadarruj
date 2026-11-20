import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/quran_metadata.dart';
import '../../core/tadarruj_brand.dart';
import '../../l10n/app_localizations.dart';

enum MushafViewMode { arabic, phonetic, translation, all }

class _MushafVerse {
  final int numberInSurah;
  final int surahNumber;
  final String surahNameAr;
  final String surahNameEn;
  final String arabic;
  final String phonetic;
  final String translation;

  const _MushafVerse({
    required this.numberInSurah,
    required this.surahNumber,
    required this.surahNameAr,
    required this.surahNameEn,
    required this.arabic,
    required this.phonetic,
    required this.translation,
  });

  String get key => '$surahNumber:$numberInSurah';
}

class QuranReaderScreen extends StatefulWidget {
  final int initialPage;

  const QuranReaderScreen({super.key, required this.initialPage});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  static final Map<String, List<_MushafVerse>> _pageCache = {};

  AudioPlayer? _audioPlayer;
  AudioPlayer get _player => _audioPlayer ??= AudioPlayer();

  String _reciterId = 'Alafasy_128kbps';
  int? _playingVerseIndex;
  bool _isPlaying = false;

  // Paramètres avancés de répétition (Tikrar)
  int _selectedSurahNum = 1;
  int _rangeStartAyah = 1;
  int _rangeEndAyah = 7;
  int _verseRepeatTarget = 1; // 1..20 ou -1 pour infini (∞)
  int _selectionRepeatTarget = 1; // 0 = aucune boucle, 1..20, ou -1 pour infini (∞)

  int _currentVerseRepeatDone = 0;
  int _currentSelectionRepeatDone = 0;
  bool _isRangePlaybackActive = false;

  late int _currentPage;
  MushafViewMode _mode = MushafViewMode.arabic;
  double _fontScale = 1.0;
  double _lineHeight = 2.15;
  bool _isLoading = true;
  bool _immersiveMode = false;
  bool _memoryTestMode = false;
  bool _savingPage = false;
  final Set<int> _revealedVerses = {};
  String? _error;
  List<_MushafVerse> _verses = [];

  static const List<int> _surahVerseCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
    111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
    54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
    49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52,
    44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19,
    26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
    6, 3, 5, 4, 5, 6
  ];

  int _versesInSurah(int surahNum) =>
      _surahVerseCounts[(surahNum - 1).clamp(0, 113)];

  static const _reciters = [
    {'id': 'Alafasy_128kbps', 'nameAr': 'مشاري العفاسي', 'nameLat': 'Alafasy'},
    {'id': 'Husary_128kbps', 'nameAr': 'محمود خليل الحصري', 'nameLat': 'Al-Husary'},
    {'id': 'Minshawy_Murattal_128kbps', 'nameAr': 'محمد صديق المنشاوي', 'nameLat': 'Al-Minshawi'},
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, 604);
    final initSurah = QuranMetadata.getSurahForPage(_currentPage);
    _selectedSurahNum = initSurah.number;
    _rangeStartAyah = 1;
    _rangeEndAyah = _versesInSurah(initSurah.number);

    _player.onPlayerComplete.listen((_) {
      if (!mounted || _playingVerseIndex == null) return;
      _handleVerseAudioCompleted();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPage(_currentPage);
    });
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _handleVerseAudioCompleted() {
    if (_playingVerseIndex == null) return;
    final currentVerse = _verses[_playingVerseIndex!];

    // 1. Vérifier si le verset courant doit encore être répété
    final nextVerseCount = _currentVerseRepeatDone + 1;
    final keepRepeatingVerse = _verseRepeatTarget == -1 ||
        nextVerseCount < _verseRepeatTarget;

    if (keepRepeatingVerse) {
      setState(() => _currentVerseRepeatDone = nextVerseCount);
      _playVerseAt(_playingVerseIndex!, resetVerseCounter: false);
      return;
    }

    // 2. Passer au verset suivant dans la sélection ou sur la page
    if (_isRangePlaybackActive) {
      if (currentVerse.surahNumber == _selectedSurahNum &&
          currentVerse.numberInSurah < _rangeEndAyah) {
        final nextAyah = currentVerse.numberInSurah + 1;
        final idxOnPage = _verses.indexWhere((v) =>
            v.surahNumber == _selectedSurahNum && v.numberInSurah == nextAyah);
        if (idxOnPage != -1) {
          _playVerseAt(idxOnPage, resetVerseCounter: true);
          return;
        }
      }

      // Fin de la plage atteinte : vérifier la répétition de toute la sélection
      final nextSelCount = _currentSelectionRepeatDone + 1;
      final keepRepeatingSelection = _selectionRepeatTarget == -1 ||
          (_selectionRepeatTarget > 0 && nextSelCount < _selectionRepeatTarget);

      if (keepRepeatingSelection) {
        setState(() => _currentSelectionRepeatDone = nextSelCount);
        final startIdx = _verses.indexWhere((v) =>
            v.surahNumber == _selectedSurahNum &&
            v.numberInSurah == _rangeStartAyah);
        if (startIdx != -1) {
          _playVerseAt(startIdx, resetVerseCounter: true);
          return;
        }
      }

      setState(() {
        _isPlaying = false;
        _isRangePlaybackActive = false;
        _playingVerseIndex = null;
      });
      return;
    }

    // Lecture continue standard sur la page
    if (_playingVerseIndex! + 1 < _verses.length) {
      _playVerseAt(_playingVerseIndex! + 1, resetVerseCounter: true);
    } else {
      setState(() {
        _isPlaying = false;
        _playingVerseIndex = null;
      });
    }
  }

  String _toArabicDigits(Object number) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var s = number.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(western[i], eastern[i]);
    }
    return s;
  }

  String _cleanHtmlTags(String raw) {
    return raw
        .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  String _buildEveryAyahUrl(_MushafVerse v) {
    final sPad = v.surahNumber.toString().padLeft(3, '0');
    final aPad = v.numberInSurah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$_reciterId/$sPad$aPad.mp3';
  }

  Future<void> _playVerseAt(int index, {bool resetVerseCounter = true}) async {
    if (index < 0 || index >= _verses.length) return;
    final verse = _verses[index];
    final url = _buildEveryAyahUrl(verse);
    HapticFeedback.selectionClick();
    setState(() {
      _playingVerseIndex = index;
      _isPlaying = true;
      if (resetVerseCounter) _currentVerseRepeatDone = 0;
    });
    try {
      try {
        await _audioPlayer?.stop();
      } catch (_) {}
      await _player.play(UrlSource(url));
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _startConfiguredSelectionPlayback() async {
    final surahMeta = QuranMetadata.getSurahByNumber(_selectedSurahNum);
    if (_currentPage < surahMeta.startPage || _currentPage > surahMeta.endPage) {
      await _loadPage(surahMeta.startPage);
    }
    if (!mounted) return;
    setState(() {
      _isRangePlaybackActive = true;
      _currentSelectionRepeatDone = 0;
      _currentVerseRepeatDone = 0;
    });
    final startIdx = _verses.indexWhere((v) =>
        v.surahNumber == _selectedSurahNum &&
        v.numberInSurah == _rangeStartAyah);
    if (startIdx != -1) {
      await _playVerseAt(startIdx, resetVerseCounter: true);
    } else if (_verses.isNotEmpty) {
      await _playVerseAt(0, resetVerseCounter: true);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_verses.isEmpty) return;
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      try {
        await _audioPlayer?.pause();
      } catch (_) {}
      setState(() => _isPlaying = false);
    } else if (_playingVerseIndex != null) {
      try {
        await _player.resume();
      } catch (_) {}
      setState(() => _isPlaying = true);
    } else {
      await _playVerseAt(0, resetVerseCounter: true);
    }
  }

  String _blankVersePlaceholder(bool isAr) {
    return isAr ? '〔 ٠٠٠٠٠٠٠٠٠٠ 〕' : '〔 •••••••••• 〕';
  }

  Future<void> _loadPage(int page) async {
    final validPage = page.clamp(1, 604);
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
    final langCode =
        mounted ? Localizations.localeOf(context).languageCode : 'fr';
    final transId = langCode == 'en' ? 20 : 136;
    final cacheKey = '$validPage-$transId';

    final sPage = QuranMetadata.getSurahForPage(validPage);

    setState(() {
      _currentPage = validPage;
      _playingVerseIndex = null;
      _isPlaying = false;
      _isRangePlaybackActive = false;
      _currentVerseRepeatDone = 0;
      _currentSelectionRepeatDone = 0;
      _revealedVerses.clear();
      _error = null;
      if (_selectedSurahNum != sPage.number) {
        _selectedSurahNum = sPage.number;
        _rangeStartAyah = 1;
        _rangeEndAyah = _versesInSurah(sPage.number);
      }
      if (_pageCache.containsKey(cacheKey)) {
        _verses = _pageCache[cacheKey]!;
        _isLoading = false;
      } else {
        _isLoading = true;
      }
    });

    if (_pageCache.containsKey(cacheKey)) return;

    final prefs = await SharedPreferences.getInstance();
    final offlineJson = prefs.getString('mushaf_page_$cacheKey');
    if (offlineJson != null && offlineJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(offlineJson) as List<dynamic>;
        final restored = decoded.map<_MushafVerse>((e) {
          final m = e as Map<String, dynamic>;
          return _MushafVerse(
            numberInSurah: m['numberInSurah'] as int,
            surahNumber: m['surahNumber'] as int,
            surahNameAr: (m['surahNameAr'] as String?) ?? '',
            surahNameEn: (m['surahNameEn'] as String?) ?? '',
            arabic: (m['arabic'] as String?) ?? '',
            phonetic: (m['phonetic'] as String?) ?? '',
            translation: (m['translation'] as String?) ?? '',
          );
        }).toList();
        _pageCache[cacheKey] = restored;
        if (mounted && _currentPage == validPage) {
          setState(() {
            _verses = restored;
            _isLoading = false;
          });
        }
        return;
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_page/$validPage?words=false&translations=$transId,57&fields=text_uthmani&per_page=50',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final versesList = decoded['verses'] as List;

      final parsed = <_MushafVerse>[];
      for (final raw in versesList) {
        final v = raw as Map<String, dynamic>;
        final verseKey = (v['verse_key'] as String?) ?? '1:1';
        final parts = verseKey.split(':');
        final sNum = int.tryParse(parts[0]) ?? 1;
        final aNum = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
        final surahMeta = QuranMetadata.getSurahByNumber(sNum);

        String phonetic = '';
        String translation = '';
        final translations = (v['translations'] as List?) ?? [];
        for (final t in translations) {
          final tm = t as Map<String, dynamic>;
          final resId = tm['resource_id'] as int?;
          final txt = _cleanHtmlTags((tm['text'] as String?) ?? '');
          if (resId == 57) {
            phonetic = txt;
          } else {
            translation = txt;
          }
        }

        parsed.add(
          _MushafVerse(
            numberInSurah: aNum,
            surahNumber: sNum,
            surahNameAr: surahMeta.nameArabic,
            surahNameEn: surahMeta.nameTranslit,
            arabic: ((v['text_uthmani'] as String?) ?? '').trim(),
            phonetic: phonetic,
            translation: translation,
          ),
        );
      }

      _pageCache[cacheKey] = parsed;
      try {
        await prefs.setString(
          'mushaf_page_$cacheKey',
          jsonEncode(parsed.map((v) => {
            'numberInSurah': v.numberInSurah,
            'surahNumber': v.surahNumber,
            'surahNameAr': v.surahNameAr,
            'surahNameEn': v.surahNameEn,
            'arabic': v.arabic,
            'phonetic': v.phonetic,
            'translation': v.translation,
          }).toList()),
        );
      } catch (_) {}
      if (mounted && _currentPage == validPage) {
        setState(() {
          _verses = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _currentPage == validPage) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAudioSettingsSheet(bool isAr, bool isFr) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF131F1A) : TadarrujColors.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final surahObj = QuranMetadata.getSurahByNumber(_selectedSurahNum);
            final maxAyah = _versesInSurah(surahObj.number);

            String repeatLabel(int val, {bool allowZero = false}) {
              if (val == -1) return '∞';
              return isAr ? _toArabicDigits(val) : '$val';
            }

            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;
            final accentColor = isDark ? TadarrujColors.goldSoft : TadarrujColors.emeraldDeep;
            final fieldFill = isDark ? const Color(0xFF1B2B24) : Colors.white;
            final textColor = isDark ? const Color(0xFFF5F2EB) : const Color(0xFF16241E);

            final verseOptions = [1, 2, 3, 5, 7, 10, 15, 20, -1];
            final selectionOptions = [0, 1, 2, 3, 5, 10, 20, -1];

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    96 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            color: isDark ? Colors.white : TadarrujColors.emeraldDeep),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isAr
                                ? 'إعدادات التلاوة والتكرار (Tikrar)'
                                : (isFr
                                    ? 'Paramètres Audio & Répétition'
                                    : 'Audio & Repetition Settings'),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16.5,
                              color: isDark ? Colors.white : TadarrujColors.emeraldDeep,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : TadarrujColors.emeraldDeep),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // 1. Récitateur
                    Text(
                      isAr
                          ? 'القارئ'
                          : (isFr ? 'Récitateur' : 'Reciter'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _reciters.map((r) {
                        final selected = _reciterId == r['id'];
                        return RawChip(showCheckmark: false, 
                          selected: selected,
                          selectedColor: isDark ? TadarrujColors.goldSoft : TadarrujColors.emeraldDeep,
                          backgroundColor: fieldFill,
                          side: BorderSide(color: isDark ? TadarrujColors.goldSoft.withValues(alpha: 0.35) : TadarrujColors.cardBorder),
                          labelStyle: TextStyle(
                            color: selected ? (isDark ? const Color(0xFF0F1A16) : Colors.white) : textColor,
                            fontWeight: FontWeight.w700,
                          ),
                          label: Text(isAr ? r['nameAr']! : r['nameLat']!),
                          onSelected: (_) {
                            setModalState(() => _reciterId = r['id']!);
                            setState(() => _reciterId = r['id']!);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 2. Sélection de la Sourate
                    Text(
                      isAr ? 'السورة' : (isFr ? 'Sourate' : 'Surah'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      dropdownColor: fieldFill,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
                      value: _selectedSurahNum,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: QuranMetadata.surahs.map((s) {
                        return DropdownMenuItem<int>(
                          value: s.number,
                          child: Text(
                            isAr
                                ? '${_toArabicDigits(s.number)}. سورة ${s.nameArabic}'
                                : '${s.number}. ${s.nameTranslit} (${s.nameArabic})',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final sNew = QuranMetadata.getSurahByNumber(val);
                        setModalState(() {
                          _selectedSurahNum = val;
                          _rangeStartAyah = 1;
                          _rangeEndAyah = _versesInSurah(sNew.number);
                        });
                        setState(() {
                          _selectedSurahNum = val;
                          _rangeStartAyah = 1;
                          _rangeEndAyah = _versesInSurah(sNew.number);
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 3. Plage de versets (Du verset X au verset Y)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr
                                    ? 'من الآية'
                                    : (isFr ? 'Du verset' : 'From verse'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13, color: textColor),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                      dropdownColor: fieldFill,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
                                value: _rangeStartAyah.clamp(1, maxAyah).toInt(),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: fieldFill,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: List.generate(maxAyah, (i) => i + 1)
                                    .map((a) => DropdownMenuItem(
                                          value: a,
                                          child: Text(isAr
                                              ? _toArabicDigits(a)
                                              : '$a'),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  setModalState(() {
                                    _rangeStartAyah = val;
                                    if (_rangeEndAyah < val) {
                                      _rangeEndAyah = val;
                                    }
                                  });
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr
                                    ? 'إلى الآية'
                                    : (isFr ? 'Au verset' : 'To verse'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13, color: textColor),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                      dropdownColor: fieldFill,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
                                value: _rangeEndAyah.clamp(_rangeStartAyah, maxAyah).toInt(),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: fieldFill,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: List.generate(
                                        maxAyah - _rangeStartAyah + 1,
                                        (i) => _rangeStartAyah + i)
                                    .map((a) => DropdownMenuItem(
                                          value: a,
                                          child: Text(isAr
                                              ? _toArabicDigits(a)
                                              : '$a'),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  setModalState(() => _rangeEndAyah = val);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Répétition de chaque verset (1 à ∞)
                    Text(
                      isAr
                          ? 'تكرار كل آية (١ إلى ∞)'
                          : (isFr
                              ? 'Répétitions par verset (1 à ∞)'
                              : 'Repeat each verse (1 to ∞)'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: verseOptions.map((opt) {
                        final sel = _verseRepeatTarget == opt;
                        return RawChip(showCheckmark: false, 
                          selected: sel,
                          selectedColor: TadarrujColors.emeraldPrimary,
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : textColor,
                            fontWeight: FontWeight.w800,
                          ),
                          label: Text('×${repeatLabel(opt)}'),
                          onSelected: (_) {
                            setModalState(() => _verseRepeatTarget = opt);
                            setState(() => _verseRepeatTarget = opt);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 5. Répétition de toute la sélection (0 à ∞)
                    Text(
                      isAr
                          ? 'تكرار كامل المقطع المختار (٠ إلى ∞)'
                          : (isFr
                              ? 'Répétitions de toute la sélection (0 à ∞)'
                              : 'Repeat entire selection (0 to ∞)'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectionOptions.map((opt) {
                        final sel = _selectionRepeatTarget == opt;
                        return RawChip(showCheckmark: false, 
                          selected: sel,
                          selectedColor: TadarrujColors.goldAccent,
                          labelStyle: TextStyle(
                            color: sel ? Colors.black : textColor,
                            fontWeight: FontWeight.w800,
                          ),
                          label: Text(opt == 0
                              ? (isAr ? '٠ (مرة)' : '0')
                              : '×${repeatLabel(opt, allowZero: true)}'),
                          onSelected: (_) {
                            setModalState(() => _selectionRepeatTarget = opt);
                            setState(() => _selectionRepeatTarget = opt);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: TadarrujColors.emeraldDeep,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startConfiguredSelectionPlayback();
                      },
                      icon: const Icon(Icons.play_circle_filled_rounded),
                      label: Text(
                        isAr
                            ? 'بدء التلاوة المبرمجة'
                            : (isFr
                                ? 'Lancer la récitation configurée'
                                : 'Start configured recitation'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logCurrentPageDone(String langCode) async {
    if (_savingPage) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _savingPage = true);
    HapticFeedback.mediumImpact();
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final rawLogs = user.userMetadata?['study_logs'];
      final List existing = rawLogs is List ? List.from(rawLogs) : [];
      existing.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'date': todayStr,
        'activity': 'lecture',
        'lines': 15,
        'goal_id': null,
      });
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'study_logs': existing}),
      );
      if (mounted) {
        final msg = langCode == 'ar'
            ? '✅ تم تسجيل الصفحة ${_toArabicDigits(_currentPage)} (+١٥ سطراً) في التقدّم!'
            : (langCode == 'en'
                ? '✅ Page $_currentPage (+15 lines) logged to Progress!'
                : '✅ Page $_currentPage (+15 lignes) enregistrée dans Progression !');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TadarrujColors.emeraldPrimary,
            content: Text(msg),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final isFr = langCode == 'fr';
    final surah = QuranMetadata.getSurahForPage(_currentPage);

    return Scaffold(
      backgroundColor: TadarrujColors.parchment,
      appBar: _immersiveMode
          ? null
          : AppBar(
              backgroundColor: TadarrujColors.emeraldDeep,
              foregroundColor: Colors.white,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TadarrujLogo(size: 28, showTitle: false),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr
                              ? 'سورة ${surah.nameArabic}'
                              : '${surah.nameTranslit} • ${surah.nameArabic}',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamilyFallback: const ['NotoNaskhArabic'],
                          ),
                        ),
                        Text(
                          isAr
                              ? 'صفحة ${_toArabicDigits(_currentPage)} / ${_toArabicDigits(604)}'
                              : '${l10n.quranPageLabel(_currentPage)} / 604',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: TadarrujColors.goldSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: isAr
                      ? 'تصغير الخط'
                      : (isFr ? 'Réduire la taille' : 'Decrease font'),
                  icon: const Icon(Icons.text_decrease, size: 20),
                  onPressed: () => setState(
                      () => _fontScale = (_fontScale - 0.1).clamp(0.8, 1.6)),
                ),
                IconButton(
                  tooltip: isAr
                      ? 'تكبير الخط'
                      : (isFr ? 'Agrandir la taille' : 'Increase font'),
                  icon: const Icon(Icons.text_increase, size: 20),
                  onPressed: () => setState(
                      () => _fontScale = (_fontScale + 0.1).clamp(0.8, 1.6)),
                ),
                IconButton(
                  tooltip: isAr
                      ? 'تباعد الأسطر'
                      : (isFr ? 'Espacement des lignes' : 'Line spacing'),
                  icon: const Icon(Icons.format_line_spacing_rounded, size: 20),
                  onPressed: () => setState(() {
                    _lineHeight = _lineHeight >= 2.55
                        ? 1.85
                        : double.parse((_lineHeight + 0.35).toStringAsFixed(2));
                  }),
                ),
              ],
            ),
      body: Column(
        children: [
          if (!_immersiveMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: TadarrujColors.goldAccent.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Center(
                child: SegmentedButton<MushafViewMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: MushafViewMode.arabic,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isAr ? 'عربي' : (isFr ? 'Arabe' : 'Arabic'),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    ButtonSegment(
                      value: MushafViewMode.phonetic,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isAr ? 'صوتي' : (isFr ? 'Phonétique' : 'Phonetic'),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    ButtonSegment(
                      value: MushafViewMode.translation,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isAr ? 'ترجمة' : (isFr ? 'Traduction' : 'Translation'),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    ButtonSegment(
                      value: MushafViewMode.all,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isAr ? 'الكل' : (isFr ? '3 en 1' : 'All 3'),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (sel) =>
                      setState(() => _mode = sel.first),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                const IslamicPatternOverlay(opacity: 0.05),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isAr
                                ? 'تعذر تحميل هذه الصفحة من المصحف.'
                                : (isFr
                                    ? 'Impossible de charger cette page du Mushaf.'
                                    : 'Unable to load this Mushaf page.'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _loadPage(_currentPage),
                            icon: const Icon(Icons.refresh),
                            label: Text(isAr
                                ? 'إعادة المحاولة'
                                : (isFr ? 'Réessayer' : 'Retry')),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_mode == MushafViewMode.arabic)
                  _buildContinuousArabicMushaf(isAr, isFr)
                else
                  _buildVerseListMushaf(isAr, isFr),
              ],
            ),
          ),
          _buildAudioReciterBar(isAr, isFr),
          _buildBottomNavigation(isAr, isFr),
        ],
      ),
    );
  }

  Widget _buildAudioReciterBar(bool isAr, bool isFr) {
    final activeVerse =
        (_playingVerseIndex != null && _playingVerseIndex! < _verses.length)
            ? _verses[_playingVerseIndex!]
            : null;
    final vRepText =
        _verseRepeatTarget == -1 ? '∞' : '${_verseRepeatTarget}';
    final sRepText =
        _selectionRepeatTarget == -1 ? '∞' : '${_selectionRepeatTarget}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D4A3A),
        border: Border(
          top: BorderSide(
            color: TadarrujColors.goldSoft.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Row(
        children: [
          // Bouton visible de paramétrage (Sourate, Versets, Répétitions 0..∞)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: TadarrujColors.goldSoft,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => _openAudioSettingsSheet(isAr, isFr),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(
              isAr
                  ? 'ضبط التلاوة (×$vRepText | ×$sRepText)'
                  : (isFr
                      ? 'Réglages Audio (×$vRepText | ×$sRepText)'
                      : 'Audio Settings (×$vRepText | ×$sRepText)'),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
          const Spacer(),
          if (activeVerse != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                isAr
                    ? 'آية ${_toArabicDigits(activeVerse.numberInSurah)}'
                    : 'v.${activeVerse.numberInSurah}',
                style: const TextStyle(
                  color: TadarrujColors.goldSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: (_playingVerseIndex != null && _playingVerseIndex! > 0)
                ? () => _playVerseAt(_playingVerseIndex! - 1)
                : null,
            icon: const Icon(Icons.skip_previous_rounded,
                color: Colors.white, size: 22),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0D4A3A),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _togglePlayPause,
            icon: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 22,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: (_playingVerseIndex != null &&
                    _playingVerseIndex! + 1 < _verses.length)
                ? () => _playVerseAt(_playingVerseIndex! + 1)
                : null,
            icon: const Icon(Icons.skip_next_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuousArabicMushaf(bool isAr, bool isFr) {
    final List<List<MapEntry<int, _MushafVerse>>> surahGroups = [];
    for (int i = 0; i < _verses.length; i++) {
      final entry = MapEntry(i, _verses[i]);
      if (surahGroups.isEmpty ||
          surahGroups.last.first.value.surahNumber != entry.value.surahNumber) {
        surahGroups.add([entry]);
      } else {
        surahGroups.last.add(entry);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: TadarrujColors.goldAccent.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_memoryTestMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAr
                            ? 'وضع اختبار الحفظ (الآيات مخفية بالكامل): المس رقم الآية لإظهارها'
                            : (isFr
                                ? 'Mode Auto-Test (versets vides) : clique sur un verset après l’avoir récité'
                                : 'Memory Test Mode (blank verses): tap a verse after reciting it'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  ),
                ...surahGroups.map((group) {
                  final first = group.first.value;
                  final startsSurah = first.numberInSurah == 1;
                  final showBasmala = startsSurah &&
                      first.surahNumber != 1 &&
                      first.surahNumber != 9;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (startsSurah) _buildSurahOrnamentHeader(first, isAr),
                      if (showBasmala)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 14),
                          child: Text(
                            'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 23 * _fontScale,
                              fontWeight: FontWeight.w600,
                              color: TadarrujColors.emeraldDeep,
                              height: 1.9,
                            ),
                          ),
                        ),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: RichText(
                          textAlign: TextAlign.justify,
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 25 * _fontScale,
                              color: const Color(0xFF1A1E1C),
                              height: _lineHeight,
                            ),
                            children: group.expand((entry) {
                              final idx = entry.key;
                              final v = entry.value;
                              final isCurrentAudio = _playingVerseIndex == idx;
                              final isHidden = _memoryTestMode &&
                                  !_revealedVerses.contains(idx);
                              final displayedText = isHidden
                                  ? _blankVersePlaceholder(isAr)
                                  : v.arabic;

                              void handleTap() {
                                if (_memoryTestMode) {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (_revealedVerses.contains(idx)) {
                                      _revealedVerses.remove(idx);
                                    } else {
                                      _revealedVerses.add(idx);
                                    }
                                  });
                                } else {
                                  _playVerseAt(idx);
                                }
                              }

                              return [
                                TextSpan(
                                  text: '$displayedText ',
                                  style: TextStyle(
                                    color: isHidden
                                        ? Colors.grey.shade400
                                        : const Color(0xFF1A1E1C),
                                    backgroundColor: isCurrentAudio
                                        ? TadarrujColors.goldSoft
                                            .withValues(alpha: 0.38)
                                        : (isHidden
                                            ? Colors.grey
                                                .withValues(alpha: 0.08)
                                            : null),
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = handleTap,
                                ),
                                TextSpan(
                                  text:
                                      '﴿${_toArabicDigits(v.numberInSurah)}﴾ ',
                                  style: TextStyle(
                                    fontFamily: 'NotoNaskhArabic',
                                    fontSize: 19 * _fontScale,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentAudio
                                        ? Colors.deepOrange
                                        : TadarrujColors.emeraldPrimary,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = handleTap,
                                ),
                              ];
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerseListMushaf(bool isAr, bool isFr) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: _verses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final v = _verses[index];
        final startsSurah = v.numberInSurah == 1;
        final isCurrentAudio = _playingVerseIndex == index;
        final isHidden = _memoryTestMode && !_revealedVerses.contains(index);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (startsSurah) ...[
                  _buildSurahOrnamentHeader(v, isAr),
                  const SizedBox(height: 10),
                ],
                GestureDetector(
behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_memoryTestMode) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_revealedVerses.contains(index)) {
                          _revealedVerses.remove(index);
                        } else {
                          _revealedVerses.add(index);
                        }
                      });
                    } else {
                      _playVerseAt(index);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrentAudio
                          ? TadarrujColors.goldSoft.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrentAudio
                            ? TadarrujColors.emeraldPrimary
                            : TadarrujColors.goldAccent.withValues(alpha: 0.4),
                        width: isCurrentAudio ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: TadarrujColors.emeraldDeep
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isAr
                                    ? '${v.surahNameAr} • ${_toArabicDigits(v.numberInSurah)}'
                                    : '${v.surahNameEn} ${v.surahNumber}:${v.numberInSurah}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: TadarrujColors.emeraldDeep,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _playVerseAt(index),
                              icon: Icon(
                                isCurrentAudio && _isPlaying
                                    ? Icons.volume_up_rounded
                                    : Icons.play_circle_outline_rounded,
                                color: TadarrujColors.emeraldPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_mode == MushafViewMode.arabic ||
                            _mode == MushafViewMode.all)
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              isHidden
                                  ? '${_blankVersePlaceholder(isAr)} ﴿${_toArabicDigits(v.numberInSurah)}﴾'
                                  : '${v.arabic} ﴿${_toArabicDigits(v.numberInSurah)}﴾',
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 24 * _fontScale,
                                color: isHidden
                                    ? Colors.grey.shade400
                                    : const Color(0xFF1A1E1C),
                                height: 2.0,
                              ),
                            ),
                          ),
                        if (!isHidden &&
                            (_mode == MushafViewMode.phonetic ||
                                _mode == MushafViewMode.all) &&
                            v.phonetic.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            v.phonetic,
                            style: TextStyle(
                              fontSize: 14.5 * _fontScale,
                              fontStyle: FontStyle.italic,
                              color: TadarrujColors.emeraldPrimary,
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (!isHidden &&
                            (_mode == MushafViewMode.translation ||
                                _mode == MushafViewMode.all) &&
                            v.translation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            v.translation,
                            style: TextStyle(
                              fontSize: 14.5 * _fontScale,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurahOrnamentHeader(_MushafVerse verse, bool isAr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            TadarrujColors.emeraldDeep,
            TadarrujColors.emeraldPrimary,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TadarrujColors.goldAccent, width: 1.3),
      ),
      child: Row(
        mainAxisAlignment: isAr
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          if (!isAr)
            Text(
              '${verse.surahNumber}. ${verse.surahNameEn}',
              style: const TextStyle(
                color: TadarrujColors.goldSoft,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          Text(
            'سُورَةُ ${verse.surahNameAr}',
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'NotoNaskhArabic',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(bool isAr, bool isFr) {
    final langCode = isAr ? 'ar' : (isFr ? 'fr' : 'en');
    final nextLabel = isAr ? 'التالية' : (isFr ? 'Suiv.' : 'Next');
    final prevLabel = isAr ? 'السابقة' : (isFr ? 'Préc.' : 'Prev.');
    final validateLabel =
        isAr ? 'إتمام ص.' : (isFr ? 'Valider p.' : 'Done p.');
    final pageNumDisplay =
        isAr ? _toArabicDigits(_currentPage) : '$_currentPage';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: TadarrujColors.goldAccent.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: _currentPage < 604
                  ? () {
                      HapticFeedback.selectionClick();
                      _loadPage(_currentPage + 1);
                    }
                  : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              label: Text(nextLabel, style: const TextStyle(fontSize: 12)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: TadarrujColors.emeraldPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => _logCurrentPageDone(langCode),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: Text(
                '$validateLabel $pageNumDisplay',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: isAr
                  ? 'اختبار الحفظ'
                  : (isFr ? 'Auto-test de mémoire' : 'Memory Test'),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _memoryTestMode = !_memoryTestMode;
                  _revealedVerses.clear();
                });
              },
              icon: Icon(
                _memoryTestMode
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: _memoryTestMode
                    ? Colors.deepOrange
                    : TadarrujColors.emeraldPrimary,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: isAr
                  ? 'وضع القراءة الكاملة'
                  : (isFr ? 'Mode lecture pure' : 'Distraction-free mode'),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _immersiveMode = !_immersiveMode);
              },
              icon: Icon(
                _immersiveMode
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                color: TadarrujColors.goldAccent,
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: _currentPage > 1
                  ? () {
                      HapticFeedback.selectionClick();
                      _loadPage(_currentPage - 1);
                    }
                  : null,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: Text(prevLabel, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
