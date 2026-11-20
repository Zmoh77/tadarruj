import '../../core/tadarruj_brand.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/quran_metadata.dart';
import '../../l10n/app_localizations.dart';
import 'quran_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _openPage(int page) {
    final validPage = page.clamp(1, 604);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuranReaderScreen(initialPage: validPage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final filteredSurahs = QuranMetadata.surahs.where((s) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return s.nameTranslit.toLowerCase().contains(q) ||
          s.nameArabic.contains(_query) ||
          '${s.number}' == q;
    }).toList();

    return Scaffold(
      appBar: TadarrujAppBar(title: l10n.navQuran),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _query = val.trim()),
                    decoration: InputDecoration(
                      hintText: l10n.quranSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 118,
                  child: TextField(
                    controller: _pageController,
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      final p = int.tryParse(val.trim());
                      if (p != null && p >= 1 && p <= 604) {
                        _openPage(p);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: l10n.quranGoToPageHint,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: l10n.quranOpenButton,
                        onPressed: () {
                          final p = int.tryParse(_pageController.text.trim());
                          if (p != null && p >= 1 && p <= 604) {
                            _openPage(p);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 32),
              itemCount: filteredSurahs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final surah = filteredSurahs[index];
                return Card(
                  child: ListTile(
                    onTap: () => _openPage(surah.startPage),
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.14),
                      foregroundColor: theme.colorScheme.primary,
                      child: Text(
                        '${surah.number}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      surah.nameTranslit,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('Page ${surah.startPage}'),
                    trailing: Text(
                      surah.nameArabic,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
