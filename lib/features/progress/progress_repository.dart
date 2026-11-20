import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class StudyLogEntry {
  final String id;
  final String dateKey;
  final String activity;
  final int lines;
  final String? goalId;

  const StudyLogEntry({
    required this.id,
    required this.dateKey,
    required this.activity,
    required this.lines,
    this.goalId,
  });

  double get pages => lines / 15.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dateKey,
        'activity': activity,
        'lines': lines,
        'goal_id': goalId,
      };

  factory StudyLogEntry.fromJson(Map<String, dynamic> map) {
    return StudyLogEntry(
      id: (map['id'] as String?) ?? '',
      dateKey: (map['date'] as String?) ?? '',
      activity: (map['activity'] as String?) ?? 'memorisation',
      lines: (map['lines'] as num?)?.toInt() ?? 0,
      goalId: map['goal_id'] as String?,
    );
  }
}

class GoalProgressItem {
  final String id;
  final String title;
  final String activity;
  final int startPage;
  final int endPage;
  final int totalPages;
  final double completedPages;
  final DateTime? targetDate;

  const GoalProgressItem({
    required this.id,
    required this.title,
    required this.activity,
    required this.startPage,
    required this.endPage,
    required this.totalPages,
    required this.completedPages,
    this.targetDate,
  });

  double get ratio =>
      totalPages > 0 ? (completedPages / totalPages).clamp(0.0, 1.0) : 0.0;

  int get percent => (ratio * 100).round();

  double get remainingPages =>
      (totalPages - completedPages).clamp(0.0, totalPages.toDouble());

  int get totalLines => totalPages * 15;
  int get completedLines => (completedPages * 15).round();
}

class ProgressSummary {
  final double totalPagesDone;
  final int totalTargetPages;
  final int totalSessionsDone;
  final int totalSessionsPlanned;
  final int currentStreak;
  final double pagesLast7Days;
  final double pagesLast30Days;
  final int daysRemainingMax;
  final DateTime? targetDeadline;
  final Map<String, double> pagesByDate;
  final Set<String> plannedDates;
  final List<GoalProgressItem> goals;
  final List<StudyLogEntry> recentLogs;

  const ProgressSummary({
    required this.totalPagesDone,
    required this.totalTargetPages,
    required this.totalSessionsDone,
    required this.totalSessionsPlanned,
    required this.currentStreak,
    required this.pagesLast7Days,
    required this.pagesLast30Days,
    required this.daysRemainingMax,
    required this.targetDeadline,
    required this.pagesByDate,
    required this.plannedDates,
    required this.goals,
    required this.recentLogs,
  });

  int get totalLinesDone => (totalPagesDone * 15).round();
}

class ProgressRepository {
  final SupabaseClient _client;

  ProgressRepository(this._client);

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<StudyLogEntry> _readUserLogs() {
    final user = _client.auth.currentUser;
    final rawList = user?.userMetadata?['study_logs'];
    if (rawList is! List) return [];
    return rawList
        .whereType()
        .map((e) => StudyLogEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ProgressSummary> fetchProgressSummary() async {
    final user = _client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) {
      return const ProgressSummary(
        totalPagesDone: 0,
        totalTargetPages: 0,
        totalSessionsDone: 0,
        totalSessionsPlanned: 0,
        currentStreak: 0,
        pagesLast7Days: 0,
        pagesLast30Days: 0,
        daysRemainingMax: 0,
        targetDeadline: null,
        pagesByDate: {},
        plannedDates: {},
        goals: [],
        recentLogs: [],
      );
    }

    final goalsRows = await _client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    final tasksRows = await _client
        .from('tasks')
        .select('goal_id, status, pos_from, pos_to, task_date')
        .eq('user_id', userId);

    double totalPagesDone = 0;
    int totalSessionsDone = 0;
    double pagesLast7Days = 0;
    double pagesLast30Days = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final thirtyDaysAgo = today.subtract(const Duration(days: 29));

    final List tasksList = tasksRows as List;
    final int totalSessionsPlanned = tasksList.length;

    final Map<String, double> pagesDoneByGoal = {};
    final Map<String, double> pagesByDate = {};
    final Set<String> plannedDates = {};
    DateTime? latestTaskDate;

    for (final raw in tasksList) {
      final row = raw as Map<String, dynamic>;
      final rawDate = (row['task_date'] as String?) ?? '';
      final dateOnly = rawDate.length >= 10 ? rawDate.substring(0, 10) : '';
      final parsedDate =
          dateOnly.isNotEmpty ? DateTime.tryParse(dateOnly) : null;

      if (parsedDate != null) {
        if (latestTaskDate == null || parsedDate.isAfter(latestTaskDate)) {
          latestTaskDate = parsedDate;
        }
      }

      if (row['status'] == 'done') {
        totalSessionsDone++;
        final posFrom = (row['pos_from'] as num?)?.toDouble() ?? 0.0;
        final posTo = (row['pos_to'] as num?)?.toDouble() ?? 0.0;
        final rawDiff = (posTo - posFrom); final pages = rawDiff > 0 ? rawDiff.clamp(0.01, 604.0) : 0.0;
        totalPagesDone += pages;

        if (dateOnly.isNotEmpty) {
          pagesByDate[dateOnly] = (pagesByDate[dateOnly] ?? 0.0) + pages;
        }
        if (parsedDate != null) {
          if (!parsedDate.isBefore(sevenDaysAgo) &&
              !parsedDate.isAfter(today)) {
            pagesLast7Days += pages;
          }
          if (!parsedDate.isBefore(thirtyDaysAgo) &&
              !parsedDate.isAfter(today)) {
            pagesLast30Days += pages;
          }
        }

        final gId = (row['goal_id'] as String?) ?? '';
        if (gId.isNotEmpty) {
          pagesDoneByGoal[gId] = (pagesDoneByGoal[gId] ?? 0.0) + pages;
        }
      } else if (dateOnly.isNotEmpty) {
        plannedDates.add(dateOnly);
      }
    }

    final logs = _readUserLogs();
    final goalsListRaw = goalsRows as List;
    final String? fallbackGoalId = goalsListRaw.isNotEmpty
        ? (goalsListRaw.first as Map<String, dynamic>)['id'] as String?
        : null;

    for (final entry in logs) {
      totalSessionsDone++;
      final pages = entry.pages;
      totalPagesDone += pages;
      if (entry.dateKey.isNotEmpty) {
        pagesByDate[entry.dateKey] = (pagesByDate[entry.dateKey] ?? 0.0) + pages;
      }
      final parsedDate = DateTime.tryParse(entry.dateKey);
      if (parsedDate != null) {
        if (!parsedDate.isBefore(sevenDaysAgo) && !parsedDate.isAfter(today)) {
          pagesLast7Days += pages;
        }
        if (!parsedDate.isBefore(thirtyDaysAgo) && !parsedDate.isAfter(today)) {
          pagesLast30Days += pages;
        }
      }
      final targetGId = (entry.goalId != null && entry.goalId!.isNotEmpty)
          ? entry.goalId!
          : (fallbackGoalId ?? '');
      if (targetGId.isNotEmpty) {
        pagesDoneByGoal[targetGId] = (pagesDoneByGoal[targetGId] ?? 0.0) + pages;
      }
    }

    int streak = 0;
    DateTime cursor = today;
    if (!pagesByDate.containsKey(_dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (pagesByDate.containsKey(_dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int totalTargetPages = 0;
    final List<GoalProgressItem> goalItems = [];
    for (final raw in goalsListRaw) {
      final g = raw as Map<String, dynamic>;
      final id = g['id'] as String;
      final startPos = (g['start_pos'] as num?)?.toDouble() ?? 0.0;
      final endPos = (g['end_pos'] as num?)?.toDouble() ?? 604.0;
      final startPage = (startPos.floor() + 1).clamp(1, 604);
      final endPage = endPos.ceil().clamp(1, 604);
      final totalPages = (endPage - startPage + 1).clamp(1, 604);
      final doneForGoal =
          (pagesDoneByGoal[id] ?? 0.0).clamp(0.0, totalPages.toDouble());
      final rawTarget = g['target_date'] as String?;
      final parsedTarget =
          rawTarget != null ? DateTime.tryParse(rawTarget) : null;

      if (parsedTarget != null) {
        if (latestTaskDate == null || parsedTarget.isAfter(latestTaskDate)) {
          latestTaskDate = parsedTarget;
        }
      }

      totalTargetPages += totalPages;

      goalItems.add(
        GoalProgressItem(
          id: id,
          title: (g['title'] as String?) ?? '',
          activity: (g['activity'] as String?) ?? 'lecture',
          startPage: startPage,
          endPage: endPage,
          totalPages: totalPages,
          completedPages: doneForGoal,
          targetDate: parsedTarget,
        ),
      );
    }

    final int daysRemainingMax = latestTaskDate != null
        ? latestTaskDate.difference(today).inDays.clamp(0, 3650)
        : 0;

    return ProgressSummary(
      totalPagesDone: totalPagesDone,
      totalTargetPages: totalTargetPages,
      totalSessionsDone: totalSessionsDone,
      totalSessionsPlanned: totalSessionsPlanned,
      currentStreak: streak,
      pagesLast7Days: pagesLast7Days,
      pagesLast30Days: pagesLast30Days,
      daysRemainingMax: daysRemainingMax,
      targetDeadline: latestTaskDate,
      pagesByDate: pagesByDate,
      plannedDates: plannedDates,
      goals: goalItems,
      recentLogs: logs.reversed.toList(),
    );
  }

  Future<void> logQuickLines({
    required String activity,
    required int lines,
    String? goalId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || lines <= 0) return;

    final now = DateTime.now();
    final todayStr = _dateKey(now);
    final existing = _readUserLogs();

    final newEntry = StudyLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateKey: todayStr,
      activity: activity,
      lines: lines,
      goalId: goalId,
    );

    final updated = [...existing, newEntry];
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'study_logs': updated.map((e) => e.toJson()).toList(),
        },
      ),
    );
  }

  Future<void> undoLastTodayLog() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final todayStr = _dateKey(DateTime.now());
    final existing = _readUserLogs();
    final idx = existing.lastIndexWhere((e) => e.dateKey == todayStr);
    if (idx == -1) return;
    existing.removeAt(idx);
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'study_logs': existing.map((e) => e.toJson()).toList(),
        },
      ),
    );
  }

  Future<void> deleteLogById(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final existing = _readUserLogs()..removeWhere((e) => e.id == id);
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'study_logs': existing.map((e) => e.toJson()).toList(),
        },
      ),
    );
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(supabaseClientProvider));
});

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  return ref.watch(progressRepositoryProvider).fetchProgressSummary();
});
