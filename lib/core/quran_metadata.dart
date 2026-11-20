class SurahInfo {
  final int number;
  final String nameArabic;
  final String nameTranslit;
  final int startPage;
  final int endPage;
  final int verseCount;

  const SurahInfo({
    required this.number,
    required this.nameArabic,
    required this.nameTranslit,
    required this.startPage,
    required this.endPage,
    required this.verseCount,
  });
}

class QuranMetadata {
  static const int totalPages = 604;

  static int countPages(int start, int end) => (end - start + 1).clamp(1, 604);

  static const List<int> _verseCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
    5, 4, 5, 6
  ];

  static const List<List<dynamic>> _raw = [
    [1, 'الفاتحة', 'Al-Fatiha', 1],
    [2, 'البقرة', 'Al-Baqara', 2],
    [3, 'آل عمران', 'Ali Imran', 50],
    [4, 'النساء', 'An-Nisa', 77],
    [5, 'المائدة', 'Al-Ma-ida', 106],
    [6, 'الأنعام', 'Al-Anam', 128],
    [7, 'الأعراف', 'Al-Araf', 151],
    [8, 'الأنفال', 'Al-Anfal', 177],
    [9, 'التوبة', 'At-Tawba', 187],
    [10, 'يونس', 'Yunus', 208],
    [11, 'هود', 'Hud', 221],
    [12, 'يوسف', 'Yusuf', 235],
    [13, 'الرعد', 'Ar-Rad', 249],
    [14, 'إبراهيم', 'Ibrahim', 255],
    [15, 'الحجر', 'Al-Hijr', 262],
    [16, 'النحل', 'An-Nahl', 267],
    [17, 'الإسراء', 'Al-Isra', 282],
    [18, 'الكهف', 'Al-Kahf', 293],
    [19, 'مريم', 'Maryam', 305],
    [20, 'طه', 'Ta-Ha', 312],
    [21, 'الأنبياء', 'Al-Anbiya', 322],
    [22, 'الحج', 'Al-Hajj', 332],
    [23, 'المؤمنون', 'Al-Muminun', 342],
    [24, 'النور', 'An-Nur', 350],
    [25, 'الفرقان', 'Al-Furqan', 359],
    [26, 'الشعراء', 'Ash-Shuara', 367],
    [27, 'النمل', 'An-Naml', 377],
    [28, 'القصص', 'Al-Qasas', 385],
    [29, 'العنكبوت', 'Al-Ankabut', 396],
    [30, 'الروم', 'Ar-Rum', 404],
    [31, 'لقمان', 'Luqman', 411],
    [32, 'السجدة', 'As-Sajda', 415],
    [33, 'الأحزاب', 'Al-Ahzab', 418],
    [34, 'سبأ', 'Saba', 428],
    [35, 'فاطر', 'Fatir', 434],
    [36, 'يس', 'Ya-Sin', 440],
    [37, 'الصافات', 'As-Saffat', 446],
    [38, 'ص', 'Sad', 453],
    [39, 'الزمر', 'Az-Zumar', 458],
    [40, 'غافر', 'Ghafir', 467],
    [41, 'فصلت', 'Fussilat', 477],
    [42, 'الشورى', 'Ash-Shura', 483],
    [43, 'الزخرف', 'Az-Zukhruf', 489],
    [44, 'الدخان', 'Ad-Dukhan', 496],
    [45, 'الجاثية', 'Al-Jathiya', 499],
    [46, 'الأحقاف', 'Al-Ahqaf', 502],
    [47, 'محمد', 'Muhammad', 507],
    [48, 'الفتح', 'Al-Fath', 511],
    [49, 'الحجرات', 'Al-Hujurat', 515],
    [50, 'ق', 'Qaf', 518],
    [51, 'الذاريات', 'Adh-Dhariyat', 520],
    [52, 'الطور', 'At-Tur', 523],
    [53, 'النجم', 'An-Najm', 526],
    [54, 'القمر', 'Al-Qamar', 528],
    [55, 'الرحمن', 'Ar-Rahman', 531],
    [56, 'الواقعة', 'Al-Waqia', 534],
    [57, 'الحديد', 'Al-Hadid', 537],
    [58, 'المجادلة', 'Al-Mujadila', 542],
    [59, 'الحشر', 'Al-Hashr', 545],
    [60, 'الممتحنة', 'Al-Mumtahina', 549],
    [61, 'الصف', 'As-Saff', 551],
    [62, 'الجمعة', 'Al-Jumua', 553],
    [63, 'المنافقون', 'Al-Munafiqun', 554],
    [64, 'التغابن', 'At-Taghabun', 556],
    [65, 'الطلاق', 'At-Talaq', 558],
    [66, 'التحريم', 'At-Tahrim', 560],
    [67, 'الملك', 'Al-Mulk', 562],
    [68, 'القلم', 'Al-Qalam', 564],
    [69, 'الحاقة', 'Al-Haqqa', 566],
    [70, 'المعارج', 'Al-Maarij', 568],
    [71, 'نوح', 'Nuh', 570],
    [72, 'الجن', 'Al-Jinn', 572],
    [73, 'المزمل', 'Al-Muzzammil', 574],
    [74, 'المدثر', 'Al-Muddaththir', 575],
    [75, 'القيامة', 'Al-Qiyama', 577],
    [76, 'الإنسان', 'Al-Insan', 578],
    [77, 'المرسلات', 'Al-Mursalat', 580],
    [78, 'النبأ', 'An-Naba', 582],
    [79, 'النازعات', 'An-Naziat', 583],
    [80, 'عبس', 'Abasa', 585],
    [81, 'التكوير', 'At-Takwir', 586],
    [82, 'الانفطار', 'Al-Infitar', 587],
    [83, 'المطففين', 'Al-Mutaffifin', 587],
    [84, 'الانشقاق', 'Al-Inshiqaq', 589],
    [85, 'البروج', 'Al-Buruj', 590],
    [86, 'الطارق', 'At-Tariq', 591],
    [87, 'الأعلى', 'Al-Ala', 591],
    [88, 'الغاشية', 'Al-Ghashiya', 592],
    [89, 'الفجر', 'Al-Fajr', 593],
    [90, 'البلد', 'Al-Balad', 594],
    [91, 'الشمس', 'Ash-Shams', 595],
    [92, 'الليل', 'Al-Layl', 595],
    [93, 'الضحى', 'Ad-Duhaa', 596],
    [94, 'الشرح', 'Ash-Sharh', 596],
    [95, 'التين', 'At-Tin', 597],
    [96, 'العلق', 'Al-Alaq', 597],
    [97, 'القدر', 'Al-Qadr', 598],
    [98, 'البينة', 'Al-Bayyina', 598],
    [99, 'الزلزلة', 'Az-Zalzala', 599],
    [100, 'العاديات', 'Al-Adiyat', 599],
    [101, 'القارعة', 'Al-Qaria', 600],
    [102, 'التكاثر', 'At-Takathur', 600],
    [103, 'العصر', 'Al-Asr', 601],
    [104, 'الهمزة', 'Al-Humaza', 601],
    [105, 'الفيل', 'Al-Fil', 601],
    [106, 'قريش', 'Quraysh', 602],
    [107, 'الماعون', 'Al-Maun', 602],
    [108, 'الكوثر', 'Al-Kawthar', 602],
    [109, 'الكافرون', 'Al-Kafirun', 603],
    [110, 'النصر', 'An-Nasr', 603],
    [111, 'المسد', 'Al-Masad', 603],
    [112, 'الإخلاص', 'Al-Ikhlas', 604],
    [113, 'الفلق', 'Al-Falaq', 604],
    [114, 'الناس', 'An-Nas', 604],
  ];

  static final List<SurahInfo> surahs = List.generate(_raw.length, (i) {
    final row = _raw[i];
    final start = row[3] as int;
    final nextStart = i + 1 < _raw.length ? (_raw[i + 1][3] as int) : 604;
    final end = nextStart > start ? nextStart - 1 : start;
    return SurahInfo(
      number: row[0] as int,
      nameArabic: row[1] as String,
      nameTranslit: row[2] as String,
      startPage: start,
      endPage: end,
      verseCount: _verseCounts[i],
    );
  });

  static SurahInfo getSurahByNumber(int number) {
    final n = number.clamp(1, 114);
    return surahs[n - 1];
  }

  static SurahInfo getSurahForPage(int page) {
    final p = page.clamp(1, 604);
    SurahInfo current = surahs.first;
    for (final s in surahs) {
      if (s.startPage <= p) {
        current = s;
      } else {
        break;
      }
    }
    return current;
  }

  /// Calcule la position exacte (en pages décimales, 0.0 à 604.0) à partir d'une sourate et d'un verset
  static double getPositionForSurahVerse({
    required int surahNumber,
    required int verseNumber,
    required bool isEnd,
  }) {
    final s = getSurahByNumber(surahNumber);
    final v = verseNumber.clamp(1, s.verseCount);
    final pageSpan = (s.endPage - s.startPage + 1).clamp(1, 50);

    if (!isEnd) {
      final fraction = (v - 1) / s.verseCount;
      return ((s.startPage - 1) + fraction * pageSpan).clamp(0.0, 603.9);
    } else {
      final fraction = v / s.verseCount;
      return ((s.startPage - 1) + fraction * pageSpan).clamp(0.1, 604.0);
    }
  }
}
