import 'package:shared_preferences/shared_preferences.dart';
// Chemin : lib/app/locale_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gère la langue active de l'interface (français par défaut).
final localeProvider = StateProvider<Locale>((ref) {
  return const Locale('fr');
});