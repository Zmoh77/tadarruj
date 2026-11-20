import 'app/theme_provider.dart';
// Chemin : lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_router.dart';
import 'app/app_theme.dart';
import 'app/locale_provider.dart';
import 'l10n/app_localizations.dart';

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;

  try {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw Exception('MISSING_KEYS');
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  } catch (e) {
    initError = e.toString();
  }

  runApp(
    ProviderScope(
      child: TadarrujApp(initError: initError),
    ),
  );
}

class TadarrujApp extends ConsumerWidget {
  final String? initError;

  const TadarrujApp({super.key, this.initError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    if (initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        locale: locale,
        supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            final message = initError!.contains('MISSING_KEYS')
                ? l10n.errorMissingKeys
                : l10n.errorGeneric;
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(24.0),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              ),
            );
          },
        ),
      );
    }

    return MaterialApp.router(
      title: 'TADARRUJ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      locale: locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}