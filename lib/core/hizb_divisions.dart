class HizbDivision {
  final int number;
  final int startSurah;
  final String startSurahName;
  final int startVerse;
  final int endSurah;
  final String endSurahName;
  final int endVerse;
  final int startPage;
  final int endPage;

  const HizbDivision({
    required this.number,
    required this.startSurah,
    required this.startSurahName,
    required this.startVerse,
    required this.endSurah,
    required this.endSurahName,
    required this.endVerse,
    required this.startPage,
    required this.endPage,
  });

  int get totalPages => (endPage - startPage + 1).clamp(1, 30);
  int get totalLines => totalPages * 15;

  String get rangeLabel => startSurah == endSurah
      ? '$startSurahName ($startSurah:$startVerse → $endVerse)'
      : '$startSurahName ($startSurah:$startVerse) → $endSurahName ($endSurah:$endVerse)';
}

class HizbDivisions {
  static const List<HizbDivision> all = [
    HizbDivision(number: 1, startSurah: 1, startSurahName: 'Al-Fatiha', startVerse: 1, endSurah: 2, endSurahName: 'Al-Baqara', endVerse: 74, startPage: 1, endPage: 11),
    HizbDivision(number: 2, startSurah: 2, startSurahName: 'Al-Baqara', startVerse: 75, endSurah: 2, endSurahName: 'Al-Baqara', endVerse: 141, startPage: 12, endPage: 21),
    HizbDivision(number: 3, startSurah: 2, startSurahName: 'Al-Baqara', startVerse: 142, endSurah: 2, endSurahName: 'Al-Baqara', endVerse: 202, startPage: 22, endPage: 31),
    HizbDivision(number: 4, startSurah: 2, startSurahName: 'Al-Baqara', startVerse: 203, endSurah: 2, endSurahName: 'Al-Baqara', endVerse: 252, startPage: 32, endPage: 41),
    HizbDivision(number: 5, startSurah: 2, startSurahName: 'Al-Baqara', startVerse: 253, endSurah: 3, endSurahName: 'Ali Imran', endVerse: 14, startPage: 42, endPage: 51),
    HizbDivision(number: 6, startSurah: 3, startSurahName: 'Ali Imran', startVerse: 15, endSurah: 3, endSurahName: 'Ali Imran', endVerse: 92, startPage: 52, endPage: 61),
    HizbDivision(number: 7, startSurah: 3, startSurahName: 'Ali Imran', startVerse: 93, endSurah: 3, endSurahName: 'Ali Imran', endVerse: 170, startPage: 62, endPage: 71),
    HizbDivision(number: 8, startSurah: 3, startSurahName: 'Ali Imran', startVerse: 171, endSurah: 4, endSurahName: 'An-Nisa', endVerse: 23, startPage: 72, endPage: 81),
    HizbDivision(number: 9, startSurah: 4, startSurahName: 'An-Nisa', startVerse: 24, endSurah: 4, endSurahName: 'An-Nisa', endVerse: 87, startPage: 82, endPage: 91),
    HizbDivision(number: 10, startSurah: 4, startSurahName: 'An-Nisa', startVerse: 88, endSurah: 4, endSurahName: 'An-Nisa', endVerse: 147, startPage: 92, endPage: 101),
    HizbDivision(number: 11, startSurah: 4, startSurahName: 'An-Nisa', startVerse: 148, endSurah: 5, endSurahName: 'Al-Ma-ida', endVerse: 26, startPage: 102, endPage: 111),
    HizbDivision(number: 12, startSurah: 5, startSurahName: 'Al-Ma-ida', startVerse: 27, endSurah: 5, endSurahName: 'Al-Ma-ida', endVerse: 81, startPage: 112, endPage: 121),
    HizbDivision(number: 13, startSurah: 5, startSurahName: 'Al-Ma-ida', startVerse: 82, endSurah: 6, endSurahName: 'Al-Anam', endVerse: 35, startPage: 122, endPage: 131),
    HizbDivision(number: 14, startSurah: 6, startSurahName: 'Al-Anam', startVerse: 36, endSurah: 6, endSurahName: 'Al-Anam', endVerse: 110, startPage: 132, endPage: 141),
    HizbDivision(number: 15, startSurah: 6, startSurahName: 'Al-Anam', startVerse: 111, endSurah: 6, endSurahName: 'Al-Anam', endVerse: 165, startPage: 142, endPage: 150),
    HizbDivision(number: 16, startSurah: 7, startSurahName: 'Al-Araf', startVerse: 1, endSurah: 7, endSurahName: 'Al-Araf', endVerse: 87, startPage: 151, endPage: 161),
    HizbDivision(number: 17, startSurah: 7, startSurahName: 'Al-Araf', startVerse: 88, endSurah: 7, endSurahName: 'Al-Araf', endVerse: 170, startPage: 162, endPage: 172),
    HizbDivision(number: 18, startSurah: 7, startSurahName: 'Al-Araf', startVerse: 171, endSurah: 8, endSurahName: 'Al-Anfal', endVerse: 40, startPage: 173, endPage: 181),
    HizbDivision(number: 19, startSurah: 8, startSurahName: 'Al-Anfal', startVerse: 41, endSurah: 9, endSurahName: 'At-Tawba', endVerse: 33, startPage: 182, endPage: 191),
    HizbDivision(number: 20, startSurah: 9, startSurahName: 'At-Tawba', startVerse: 34, endSurah: 9, endSurahName: 'At-Tawba', endVerse: 92, startPage: 192, endPage: 201),
    HizbDivision(number: 21, startSurah: 9, startSurahName: 'At-Tawba', startVerse: 93, endSurah: 10, endSurahName: 'Yunus', endVerse: 25, startPage: 202, endPage: 211),
    HizbDivision(number: 22, startSurah: 10, startSurahName: 'Yunus', startVerse: 26, endSurah: 11, endSurahName: 'Hud', endVerse: 5, startPage: 212, endPage: 221),
    HizbDivision(number: 23, startSurah: 11, startSurahName: 'Hud', startVerse: 6, endSurah: 11, endSurahName: 'Hud', endVerse: 83, startPage: 222, endPage: 231),
    HizbDivision(number: 24, startSurah: 11, startSurahName: 'Hud', startVerse: 84, endSurah: 12, endSurahName: 'Yusuf', endVerse: 52, startPage: 232, endPage: 241),
    HizbDivision(number: 25, startSurah: 12, startSurahName: 'Yusuf', startVerse: 53, endSurah: 13, endSurahName: 'Ar-Rad', endVerse: 18, startPage: 242, endPage: 251),
    HizbDivision(number: 26, startSurah: 13, startSurahName: 'Ar-Rad', startVerse: 19, endSurah: 14, endSurahName: 'Ibrahim', endVerse: 52, startPage: 252, endPage: 261),
    HizbDivision(number: 27, startSurah: 15, startSurahName: 'Al-Hijr', startVerse: 1, endSurah: 16, endSurahName: 'An-Nahl', endVerse: 50, startPage: 262, endPage: 271),
    HizbDivision(number: 28, startSurah: 16, startSurahName: 'An-Nahl', startVerse: 51, endSurah: 16, endSurahName: 'An-Nahl', endVerse: 128, startPage: 272, endPage: 281),
    HizbDivision(number: 29, startSurah: 17, startSurahName: 'Al-Isra', startVerse: 1, endSurah: 17, endSurahName: 'Al-Isra', endVerse: 98, startPage: 282, endPage: 291),
    HizbDivision(number: 30, startSurah: 17, startSurahName: 'Al-Isra', startVerse: 99, endSurah: 18, endSurahName: 'Al-Kahf', endVerse: 74, startPage: 292, endPage: 301),
    HizbDivision(number: 31, startSurah: 18, startSurahName: 'Al-Kahf', startVerse: 75, endSurah: 19, endSurahName: 'Maryam', endVerse: 98, startPage: 302, endPage: 311),
    HizbDivision(number: 32, startSurah: 20, startSurahName: 'Ta-Ha', startVerse: 1, endSurah: 20, endSurahName: 'Ta-Ha', endVerse: 135, startPage: 312, endPage: 321),
    HizbDivision(number: 33, startSurah: 21, startSurahName: 'Al-Anbiya', startVerse: 1, endSurah: 21, endSurahName: 'Al-Anbiya', endVerse: 78, startPage: 322, endPage: 331),
    HizbDivision(number: 34, startSurah: 22, startSurahName: 'Al-Hajj', startVerse: 1, endSurah: 22, endSurahName: 'Al-Hajj', endVerse: 78, startPage: 332, endPage: 341),
    HizbDivision(number: 35, startSurah: 23, startSurahName: 'Al-Muminun', startVerse: 1, endSurah: 24, endSurahName: 'An-Nur', endVerse: 20, startPage: 342, endPage: 351),
    HizbDivision(number: 36, startSurah: 24, startSurahName: 'An-Nur', startVerse: 21, endSurah: 25, endSurahName: 'Al-Furqan', endVerse: 20, startPage: 352, endPage: 361),
    HizbDivision(number: 37, startSurah: 25, startSurahName: 'Al-Furqan', startVerse: 21, endSurah: 26, endSurahName: 'Ash-Shuara', endVerse: 110, startPage: 362, endPage: 371),
    HizbDivision(number: 38, startSurah: 26, startSurahName: 'Ash-Shuara', startVerse: 111, endSurah: 27, endSurahName: 'An-Naml', endVerse: 55, startPage: 372, endPage: 381),
    HizbDivision(number: 39, startSurah: 27, startSurahName: 'An-Naml', startVerse: 56, endSurah: 28, endSurahName: 'Al-Qasas', endVerse: 50, startPage: 382, endPage: 391),
    HizbDivision(number: 40, startSurah: 28, startSurahName: 'Al-Qasas', startVerse: 51, endSurah: 29, endSurahName: 'Al-Ankabut', endVerse: 45, startPage: 392, endPage: 401),
    HizbDivision(number: 41, startSurah: 29, startSurahName: 'Al-Ankabut', startVerse: 46, endSurah: 31, endSurahName: 'Luqman', endVerse: 21, startPage: 402, endPage: 412),
    HizbDivision(number: 42, startSurah: 31, startSurahName: 'Luqman', startVerse: 22, endSurah: 33, endSurahName: 'Al-Ahzab', endVerse: 30, startPage: 413, endPage: 421),
    HizbDivision(number: 43, startSurah: 33, startSurahName: 'Al-Ahzab', startVerse: 31, endSurah: 34, endSurahName: 'Saba', endVerse: 23, startPage: 422, endPage: 430),
    HizbDivision(number: 44, startSurah: 34, startSurahName: 'Saba', startVerse: 24, endSurah: 36, endSurahName: 'Ya-Sin', endVerse: 27, startPage: 431, endPage: 441),
    HizbDivision(number: 45, startSurah: 36, startSurahName: 'Ya-Sin', startVerse: 28, endSurah: 37, endSurahName: 'As-Saffat', endVerse: 144, startPage: 442, endPage: 451),
    HizbDivision(number: 46, startSurah: 37, startSurahName: 'As-Saffat', startVerse: 145, endSurah: 39, endSurahName: 'Az-Zumar', endVerse: 31, startPage: 452, endPage: 461),
    HizbDivision(number: 47, startSurah: 39, startSurahName: 'Az-Zumar', startVerse: 32, endSurah: 40, endSurahName: 'Ghafir', endVerse: 40, startPage: 462, endPage: 471),
    HizbDivision(number: 48, startSurah: 40, startSurahName: 'Ghafir', startVerse: 41, endSurah: 41, endSurahName: 'Fussilat', endVerse: 46, startPage: 472, endPage: 481),
    HizbDivision(number: 49, startSurah: 41, startSurahName: 'Fussilat', startVerse: 47, endSurah: 43, endSurahName: 'Az-Zukhruf', endVerse: 23, startPage: 482, endPage: 490),
    HizbDivision(number: 50, startSurah: 43, startSurahName: 'Az-Zukhruf', startVerse: 24, endSurah: 45, endSurahName: 'Al-Jathiya', endVerse: 37, startPage: 491, endPage: 501),
    HizbDivision(number: 51, startSurah: 46, startSurahName: 'Al-Ahqaf', startVerse: 1, endSurah: 48, endSurahName: 'Al-Fath', endVerse: 17, startPage: 502, endPage: 512),
    HizbDivision(number: 52, startSurah: 48, startSurahName: 'Al-Fath', startVerse: 18, endSurah: 51, endSurahName: 'Adh-Dhariyat', endVerse: 30, startPage: 513, endPage: 521),
    HizbDivision(number: 53, startSurah: 51, startSurahName: 'Adh-Dhariyat', startVerse: 31, endSurah: 54, endSurahName: 'Al-Qamar', endVerse: 55, startPage: 522, endPage: 531),
    HizbDivision(number: 54, startSurah: 55, startSurahName: 'Ar-Rahman', startVerse: 1, endSurah: 57, endSurahName: 'Al-Hadid', endVerse: 29, startPage: 532, endPage: 541),
    HizbDivision(number: 55, startSurah: 58, startSurahName: 'Al-Mujadila', startVerse: 1, endSurah: 61, endSurahName: 'As-Saff', endVerse: 14, startPage: 542, endPage: 552),
    HizbDivision(number: 56, startSurah: 62, startSurahName: 'Al-Jumua', startVerse: 1, endSurah: 66, endSurahName: 'At-Tahrim', endVerse: 12, startPage: 553, endPage: 561),
    HizbDivision(number: 57, startSurah: 67, startSurahName: 'Al-Mulk', startVerse: 1, endSurah: 71, endSurahName: 'Nuh', endVerse: 28, startPage: 562, endPage: 571),
    HizbDivision(number: 58, startSurah: 72, startSurahName: 'Al-Jinn', startVerse: 1, endSurah: 77, endSurahName: 'Al-Mursalat', endVerse: 50, startPage: 572, endPage: 581),
    HizbDivision(number: 59, startSurah: 78, startSurahName: 'An-Naba', startVerse: 1, endSurah: 86, endSurahName: 'At-Tariq', endVerse: 17, startPage: 582, endPage: 591),
    HizbDivision(number: 60, startSurah: 87, startSurahName: 'Al-Ala', startVerse: 1, endSurah: 114, endSurahName: 'An-Nas', endVerse: 6, startPage: 592, endPage: 604),
  ];

  static HizbDivision getForPage(int page) {
    final p = page.clamp(1, 604);
    for (final h in all) {
      if (p >= h.startPage && p <= h.endPage) return h;
    }
    return all.last;
  }

  static List<HizbDivision> getInPageRange(int startPage, int endPage) {
    return all
        .where((h) => h.endPage >= startPage && h.startPage <= endPage)
        .toList();
  }
}
