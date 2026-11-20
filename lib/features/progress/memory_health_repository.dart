import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

enum MasteryLevel { fragile, consolidating, stable, solid }

class PassageMasteryRecord {
  final String id;
  final int surahNumber;
  final int ayahFrom;
  final int ayahTo;
  final MasteryLevel level;
  final int reviewCount;
  final String lastRating; // 'hard', 'hesitant', 'mastered'
  final String? difficultyType;
  final DateTime lastReviewedAt;
  final DateTime nextReviewAt;

  const PassageMasteryRecord({
    required this.id,
    required this.surahNumber,
    required this.ayahFrom,
    required this.ayahTo,
    required this.level,
    required this.reviewCount,
    required this.lastRating,
    this.difficultyType,
    required this.lastReviewedAt,
    required this.nextReviewAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'surah_number': surahNumber,
        'ayah_from': ayahFrom,
        'ayah_to': ayahTo,
        'mastery_level': level.name,
        'review_count': reviewCount,
        'last_rating': lastRating,
        'difficulty_type': difficultyType,
        'last_reviewed_at': lastReviewedAt.toIso8601String(),
        'next_review_at': nextReviewAt.toIso8601String(),
      };

  factory PassageMasteryRecord.fromMap(Map<String, dynamic> map) {
    final rawLevel = (map['mastery_level'] as String?) ?? 'fragile';
    final level = MasteryLevel.values.firstWhere(
      (e) => e.name == rawLevel,
      orElse: () => MasteryLevel.fragile,
    );
    return PassageMasteryRecord(
      id: (map['id'] as String?) ??
          '${map['surah_number']}_${map['ayah_from']}_${map['ayah_to']}',
      surahNumber: (map['surah_number'] as num?)?.toInt() ?? 1,
      ayahFrom: (map['ayah_from'] as num?)?.toInt() ?? 1,
      ayahTo: (map['ayah_to'] as num?)?.toInt() ?? 1,
      level: level,
      reviewCount: (map['review_count'] as num?)?.toInt() ?? 1,
      lastRating: (map['last_rating'] as String?) ?? 'hesitant',
      difficultyType: map['difficulty_type'] as String?,
      lastReviewedAt:
          DateTime.tryParse(map['last_reviewed_at']?.toString() ?? '') ??
              DateTime.now(),
      nextReviewAt:
          DateTime.tryParse(map['next_review_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}

class InterruptedSessionState {
  final int page;
  final int surahNumber;
  final String activity;
  final String? taskId;
  final DateTime savedAt;

  const InterruptedSessionState({
    required this.page,
    required this.surahNumber,
    required this.activity,
    this.taskId,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() => {
        'page': page,
        'surah_number': surahNumber,
        'activity': activity,
        'task_id': taskId,
        'saved_at': savedAt.toIso8601String(),
      };

  factory InterruptedSessionState.fromMap(Map<String, dynamic> map) {
    return InterruptedSessionState(
      page: (map['page'] as num?)?.toInt() ?? 1,
      surahNumber: (map['surah_number'] as num?)?.toInt() ?? 1,
      activity: (map['activity'] as String?) ?? 'memorisation',
      taskId: map['task_id'] as String?,
      savedAt: DateTime.tryParse(map['saved_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class MemoryHealthRepository {
  final SupabaseClient _client;
  static const _localMasteryKey = 'tadarruj_passage_mastery_v1';
  static const _interruptedSessionKey = 'tadarruj_interrupted_session_v1';

  MemoryHealthRepository(this._client);

  MasteryLevel _computeNextLevel({
    required MasteryLevel? previous,
    required int nextReviewCount,
    required String rating,
  }) {
    // Basé strictement sur les révisions réellement effectuées
    if (rating == 'hard') return MasteryLevel.fragile;
    if (rating == 'hesitant') {
      if (previous == MasteryLevel.solid || previous == MasteryLevel.stable) {
        return MasteryLevel.consolidating;
      }
      return MasteryLevel.fragile;
    }
    // rating == 'mastered'
    if (nextReviewCount >= 4 &&
        (previous == MasteryLevel.stable || previous == MasteryLevel.solid)) {
      return MasteryLevel.solid;
    }
    if (nextReviewCount >= 2) {
      return MasteryLevel.stable;
    }
    return MasteryLevel.consolidating;
  }

  Future<List<PassageMasteryRecord>> fetchAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localMasteryKey);
    final List<PassageMasteryRecord> localList = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            localList.add(PassageMasteryRecord.fromMap(item));
          }
        }
      } catch (_) {}
    }

    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final rows = await _client
            .from('verse_mastery')
            .select()
            .eq('user_id', userId)
            .order('next_review_at', ascending: true);
        final remoteList = (rows as List)
            .map((r) => PassageMasteryRecord.fromMap(r as Map<String, dynamic>))
            .toList();
        if (remoteList.isNotEmpty) {
          await prefs.setString(
            _localMasteryKey,
            jsonEncode(remoteList.map((e) => e.toMap()).toList()),
          );
          return remoteList;
        }
      } catch (_) {
        // Table verse_mastery non encore migrée : fallback transparent sur le cache local
      }
    }

    localList.sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
    return localList;
  }

  Future<void> recordReviewEvaluation({
    required int surahNumber,
    required int ayahFrom,
    required int ayahTo,
    required String rating, // 'hard' | 'hesitant' | 'mastered'
    String? difficultyType,
  }) async {
    final current = await fetchAllRecords();
    final key = '${surahNumber}_${ayahFrom}_$ayahTo';
    final existingIdx = current.indexWhere((e) => e.id == key);
    final existing = existingIdx != -1 ? current[existingIdx] : null;

    final nextCount = (existing?.reviewCount ?? 0) + 1;
    final nextLevel = _computeNextLevel(
      previous: existing?.level,
      nextReviewCount: nextCount,
      rating: rating,
    );

    final now = DateTime.now();
    final intervalDays = rating == 'hard'
        ? 1
        : (rating == 'hesitant'
            ? 2
            : (nextLevel == MasteryLevel.solid ? 14 : 5));

    final updated = PassageMasteryRecord(
      id: key,
      surahNumber: surahNumber,
      ayahFrom: ayahFrom,
      ayahTo: ayahTo,
      level: nextLevel,
      reviewCount: nextCount,
      lastRating: rating,
      difficultyType: rating == 'mastered' ? null : difficultyType,
      lastReviewedAt: now,
      nextReviewAt: now.add(Duration(days: intervalDays)),
    );

    if (existingIdx != -1) {
      current[existingIdx] = updated;
    } else {
      current.add(updated);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localMasteryKey,
      jsonEncode(current.map((e) => e.toMap()).toList()),
    );

    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _client.from('verse_mastery').upsert({
          'user_id': userId,
          'surah_number': surahNumber,
          'ayah_from': ayahFrom,
          'ayah_to': ayahTo,
          'mastery_level': nextLevel.name,
          'review_count': nextCount,
          'last_rating': rating,
          'difficulty_type': updated.difficultyType,
          'last_reviewed_at': now.toIso8601String(),
          'next_review_at': updated.nextReviewAt.toIso8601String(),
        });
      } catch (_) {}
    }
  }

  Future<void> saveInterruptedSession(InterruptedSessionState session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_interruptedSessionKey, jsonEncode(session.toMap()));
  }

  Future<InterruptedSessionState?> loadInterruptedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_interruptedSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return InterruptedSessionState.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearInterruptedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_interruptedSessionKey);
  }
}

final memoryHealthRepositoryProvider = Provider<MemoryHealthRepository>((ref) {
  return MemoryHealthRepository(ref.watch(supabaseClientProvider));
});

final passageMasteryListProvider =
    FutureProvider<List<PassageMasteryRecord>>((ref) async {
  return ref.watch(memoryHealthRepositoryProvider).fetchAllRecords();
});

final interruptedSessionProvider =
    FutureProvider<InterruptedSessionState?>((ref) async {
  return ref.watch(memoryHealthRepositoryProvider).loadInterruptedSession();
});
