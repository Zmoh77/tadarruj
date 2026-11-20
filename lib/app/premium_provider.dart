import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final isPremiumProvider = StateProvider<bool>((ref) {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
  return meta['is_premium'] == true;
});

class HalaqaGroupsNotifier extends StateNotifier<List> {
  HalaqaGroupsNotifier() : super([]) {
    _load();
  }

  static const _storageKey = 'tadarruj_halaqa_groups_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          state = decoded;
          return;
        }
      } catch (_) {}
    }
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    final saved = meta['halaqa_groups'];
    if (saved is List && saved.isNotEmpty) {
      state = List.from(saved);
    }
  }

  Future<void> saveGroups(List updated) async {
    state = List.from(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state));
  }
}

final halaqaGroupsProvider =
    StateNotifierProvider<HalaqaGroupsNotifier, List>((ref) {
  return HalaqaGroupsNotifier();
});
