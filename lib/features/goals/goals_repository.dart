import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class GoalModel {
  final String id;
  final String title;
  final String goalType;
  final int startPage;
  final int endPage;
  final int durationDays;
  final String status;
  final DateTime createdAt;

  const GoalModel({
    required this.id,
    required this.title,
    required this.goalType,
    required this.startPage,
    required this.endPage,
    required this.durationDays,
    required this.status,
    required this.createdAt,
  });

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    final start = DateTime.tryParse(map['start_date']?.toString() ?? '');
    final end = DateTime.tryParse(map['due_date']?.toString() ?? '');
    final computedDays = (start != null && end != null)
        ? (end.difference(start).inDays + 1).clamp(1, 3650)
        : 30;

    final startPos = (map['start_pos'] as num?)?.toDouble() ?? 0.0;
    final endPos = (map['end_pos'] as num?)?.toDouble() ?? 604.0;

    return GoalModel(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      goalType: (map['activity'] as String?) ?? 'lecture',
      startPage: startPos <= endPos
          ? (startPos.floor() + 1).clamp(1, 604)
          : startPos.ceil().clamp(1, 604),
      endPage: startPos <= endPos
          ? endPos.ceil().clamp(1, 604)
          : (endPos.floor() + 1).clamp(1, 604),
      durationDays: computedDays,
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class GoalsRepository {
  final SupabaseClient _client;

  GoalsRepository(this._client);

  Future<List<GoalModel>> fetchGoals() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => GoalModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  String _mapActivityToDb(String uiType) {
    switch (uiType) {
      case 'memorisation':
      case 'memorization':
        return 'memorisation';
      case 'revision':
        return 'revision';
      default:
        return 'lecture';
    }
  }

  Future<void> createGoalAndSchedule({
    required String title,
    String? goalType,
    String? activity,
    double? startPos,
    double? endPos,
    int? startPage,
    int? endPage,
    int? durationDays,
    DateTime? targetDate,
    List<int>? weekdays,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('NOT_AUTHENTICATED');

    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    final int resolvedDays = durationDays ??
        (targetDate != null
            ? targetDate.difference(startDate).inDays.clamp(1, 3650)
            : 30);
    final dueDate = targetDate ?? startDate.add(Duration(days: resolvedDays - 1));
    final allowedWeekdays = (weekdays != null && weekdays.isNotEmpty)
        ? weekdays.toSet()
        : {1, 2, 3, 4, 5, 6, 7};

    String formatDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final double resolvedStartPos = startPos ?? ((startPage ?? 1) - 1).toDouble();
    final double resolvedEndPos = endPos ?? (endPage ?? 1).toDouble();
    final bool isReverse = resolvedEndPos < resolvedStartPos;
    final double totalPages = (resolvedEndPos - resolvedStartPos).abs().clamp(0.1, 604.0);
    final String dbActivity = _mapActivityToDb(goalType ?? activity ?? 'memorisation');

    final double dbStartPos = isReverse ? resolvedEndPos : resolvedStartPos;
    final double dbEndPos = isReverse ? resolvedStartPos : resolvedEndPos;

    final insertedGoal = await _client
        .from('goals')
        .insert({
          'user_id': userId,
          'title': title,
          'activity': dbActivity,
          'start_pos': dbStartPos,
          'end_pos': dbEndPos,
          'current_pos': dbStartPos,
          'start_date': formatDate(startDate),
          'due_date': formatDate(dueDate),
          'initial_quota': totalPages / resolvedDays,
          'horizon': resolvedDays <= 30
              ? 'court'
              : (resolvedDays <= 180 ? 'moyen' : 'long'),
          'status': 'active',
        })
        .select()
        .single();

    final goalId = insertedGoal['id'] as String;

    // Lister les jours d'étude valides entre startDate et dueDate
    final List<DateTime> studyDates = [];
    DateTime cursor = startDate;
    final endLimit = DateTime(dueDate.year, dueDate.month, dueDate.day);
    while (!cursor.isAfter(endLimit)) {
      if (allowedWeekdays.contains(cursor.weekday)) {
        studyDates.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    if (studyDates.isEmpty) studyDates.add(startDate);

    final double pagesPerSession = totalPages / studyDates.length;
    double currentPos = resolvedStartPos;
    final tasksToInsert = [];

    for (int i = 0; i < studyDates.length; i++) {
      if (!isReverse && currentPos >= resolvedEndPos) break;
      if (isReverse && currentPos <= resolvedEndPos) break;
      final double nextPos = (i == studyDates.length - 1)
          ? resolvedEndPos
          : (!isReverse
              ? (currentPos + pagesPerSession).clamp(resolvedStartPos, resolvedEndPos)
              : (currentPos - pagesPerSession).clamp(resolvedEndPos, resolvedStartPos));

      final double rawFrom = currentPos < nextPos ? currentPos : nextPos;
      final double rawTo = currentPos < nextPos ? nextPos : currentPos;
      final double safeFrom = double.parse(rawFrom.toStringAsFixed(2));
      final double safeTo = double.parse((rawTo <= rawFrom ? rawFrom + 0.1 : rawTo).toStringAsFixed(2));

      tasksToInsert.add({
        'user_id': userId,
        'goal_id': goalId,
        'activity': dbActivity,
        'origin': 'plan',
        'task_date': formatDate(studyDates[i]),
        'pos_from': safeFrom,
        'pos_to': safeTo,
        'status': 'planned',
      });

      currentPos = nextPos;
    }

    if (tasksToInsert.isNotEmpty) {
      await _client.from('tasks').insert(tasksToInsert);
    }
  }

  Future<void> updateGoal({
    required String goalId,
    required String title,
    required DateTime newDueDate,
  }) async {
    String formatDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await _client.from('goals').update({
      'title': title,
      'due_date': formatDate(newDueDate),
    }).eq('id', goalId);
  }

  Future<void> resetGoalProgress(String goalId, int startPage) async {
    final startPos = (startPage - 1).clamp(0, 603).toDouble();
    await _client.from('goals').update({
      'current_pos': startPos,
    }).eq('id', goalId);
    await _client
        .from('tasks')
        .update({'status': 'planned', 'done_quantity': 0})
        .eq('goal_id', goalId)
        .eq('status', 'done');
  }

  Future<List<GoalModel>> fetchArchivedGoals() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .neq('status', 'active')
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => GoalModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> restoreGoal(String goalId) async {
    await _client.from('goals').update({'status': 'active'}).eq('id', goalId);
  }

  Future<void> deleteGoal(String goalId) async {
    await _client.from('tasks').delete().eq('goal_id', goalId).eq('status', 'planned');
    await _client.from('goals').update({'status': 'archived'}).eq('id', goalId);
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(ref.watch(supabaseClientProvider));
});

final goalsListProvider = FutureProvider<List<GoalModel>>((ref) async {
  return ref.watch(goalsRepositoryProvider).fetchGoals();
});

final archivedGoalsListProvider = FutureProvider<List<GoalModel>>((ref) async {
  return ref.watch(goalsRepositoryProvider).fetchArchivedGoals();
});
