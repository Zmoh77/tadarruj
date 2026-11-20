// Chemin : lib/features/calendar/calendar_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class CalendarTaskModel {
  final String id;
  final String goalTitle;
  final String activity;
  final String taskDate; // 'YYYY-MM-DD'
  final int startPage;
  final int endPage;
  final String status;

  const CalendarTaskModel({
    required this.id,
    required this.goalTitle,
    required this.activity,
    required this.taskDate,
    required this.startPage,
    required this.endPage,
    required this.status,
  });

  bool get isDone => status == 'done';

  factory CalendarTaskModel.fromMap(Map<String, dynamic> map) {
    final posFrom = (map['pos_from'] as num?)?.toDouble() ?? 0.0;
    final posTo = (map['pos_to'] as num?)?.toDouble() ?? 1.0;
    final goalData = map['goals'];
    final goalTitle = goalData is Map<String, dynamic>
        ? ((goalData['title'] as String?) ?? '')
        : '';

    return CalendarTaskModel(
      id: map['id'] as String,
      goalTitle: goalTitle,
      activity: (map['activity'] as String?) ?? 'lecture',
      taskDate: (map['task_date'] as String?) ?? '',
      startPage: (posFrom.floor() + 1).clamp(1, 604),
      endPage: posTo.ceil().clamp(1, 604),
      status: (map['status'] as String?) ?? 'planned',
    );
  }
}

class CalendarRepository {
  final SupabaseClient _client;

  CalendarRepository(this._client);

  /// Récupère les tâches de l'utilisateur indexées par date ISO ('YYYY-MM-DD').
  Future fetchTasksByDate() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final response = await _client
        .from('tasks')
        .select('*, goals!inner(title, status)')
        .eq('user_id', userId)
        .eq('goals.status', 'active')
        .order('task_date', ascending: true);

    final Map<String, List<CalendarTaskModel>> grouped = {};
    for (final row in (response as List)) {
      final task = CalendarTaskModel.fromMap(row as Map<String, dynamic>);
      grouped.putIfAbsent(task.taskDate, () => []).add(task);
    }
    return grouped;
  }
}

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(supabaseClientProvider));
});

final calendarTasksByDateProvider =
    FutureProvider((ref) async {
  return ref.watch(calendarRepositoryProvider).fetchTasksByDate();
});