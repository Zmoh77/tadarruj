import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class TodayTaskModel {
  final String id;
  final String goalId;
  final String goalTitle;
  final String activity; // 'lecture', 'memorisation', 'revision'
  final int startPage;
  final int endPage;
  final double posFrom;
  final double posTo;
  final String status; // 'planned', 'done', etc.

  const TodayTaskModel({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    required this.activity,
    required this.startPage,
    required this.endPage,
    required this.posFrom,
    required this.posTo,
    required this.status,
  });

  bool get isDone => status == 'done';

  int get estimatedLines =>
      (((posTo - posFrom).abs().clamp(0.1, 604.0)) * 15).round().clamp(1, 9060);

  bool get supportsSpacedReview =>
      activity == 'memorisation' || activity == 'revision';

  factory TodayTaskModel.fromMap(Map<String, dynamic> map) {
    final posFrom = (map['pos_from'] as num?)?.toDouble() ?? 0.0;
    final posTo = (map['pos_to'] as num?)?.toDouble() ?? 1.0;
    final goalData = map['goals'];
    final goalTitle = goalData is Map<String, dynamic>
        ? ((goalData['title'] as String?) ?? '')
        : '';

    return TodayTaskModel(
      id: map['id'] as String,
      goalId: (map['goal_id'] as String?) ?? '',
      goalTitle: goalTitle,
      activity: (map['activity'] as String?) ?? 'lecture',
      startPage: ((posFrom < posTo ? posFrom : posTo).floor() + 1).clamp(1, 604),
      endPage: (posFrom < posTo ? posTo : posFrom).ceil().clamp(1, 604),
      posFrom: posFrom,
      posTo: posTo,
      status: (map['status'] as String?) ?? 'planned',
    );
  }
}

class TodayRepository {
  final SupabaseClient _client;

  TodayRepository(this._client);

  String _formatIsoDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<List<TodayTaskModel>> fetchTodayTasks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final todayStr = _formatIsoDate(DateTime.now());
    try {
      final response = await _client
          .from('tasks')
          .select('*, goals!inner(title, status)')
          .eq('user_id', userId)
          .eq('task_date', todayStr)
          .eq('goals.status', 'active');

      return (response as List)
          .map((row) =>
              TodayTaskModel.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      final fallback = await _client
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .eq('task_date', todayStr);

      return (fallback as List)
          .map((row) =>
              TodayTaskModel.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    }
  }

  Future<int?> completeTask(TodayTaskModel task, {bool? isFluent}) async {
    final quantity = (task.posTo - task.posFrom).abs().clamp(0.1, 604.0);

    await _client.from('tasks').update({
      'status': 'done',
      'done_quantity': quantity,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', task.id);

    if (task.goalId.isNotEmpty) {
      await _client.from('goals').update({
        'current_pos': task.posTo,
      }).eq('id', task.goalId);
    }

    // Synchronisation automatique avec les logs de Progression
    final user = _client.auth.currentUser;
    if (user != null) {
      final todayStr = _formatIsoDate(DateTime.now());
      final rawLogs = user.userMetadata?['study_logs'];
      final List existingLogs =
          rawLogs is List ? List.from(rawLogs) : [];
      existingLogs.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'date': todayStr,
        'activity': task.activity,
        'lines': task.estimatedLines,
        'goal_id': task.goalId.isNotEmpty ? task.goalId : null,
      });
      await _client.auth.updateUser(
        UserAttributes(data: {'study_logs': existingLogs}),
      );
    }

    final userId = _client.auth.currentUser?.id;
    if (userId != null && task.supportsSpacedReview && isFluent != null) {
      final intervalDays = isFluent ? 3 : 1;
      final nextReviewDate =
          _formatIsoDate(DateTime.now().add(Duration(days: intervalDays)));

      await _client.from('tasks').insert({
        'user_id': userId,
        'goal_id': task.goalId.isNotEmpty ? task.goalId : null,
        'task_date': nextReviewDate,
        'activity': 'revision',
        'origin': 'plan',
        'pos_from': task.posFrom,
        'pos_to': task.posTo,
        'status': 'planned',
      });

      return intervalDays;
    }

    return null;
  }
}

final todayRepositoryProvider = Provider<TodayRepository>((ref) {
  return TodayRepository(ref.watch(supabaseClientProvider));
});

final todayTasksProvider = FutureProvider<List<TodayTaskModel>>((ref) async {
  return ref.watch(todayRepositoryProvider).fetchTodayTasks();
});
