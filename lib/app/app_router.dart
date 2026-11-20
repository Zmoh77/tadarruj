import 'package:flutter/services.dart';
import 'dart:ui';
import '../features/settings/premium_screen.dart';
import '../features/goals/goal_form_screen.dart';
// Chemin : lib/app/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase_client.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/quran/quran_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import '../l10n/app_localizations.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    redirect: (context, state) {
      final session = authState.valueOrNull?.session ?? client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/onboarding' || loc == '/auth';

      // Non connecté -> redirection vers l'accueil Onboarding
      if (!isLoggedIn && !isAuthRoute) {
        return '/onboarding';
      }

      // Connecté -> redirection vers les 5 onglets
      if (isLoggedIn && isAuthRoute) {
        return '/today';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quran',
                builder: (context, state) => const QuranScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/goals/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GoalFormScreen(),
      ),
      GoRoute(
        path: '/premium',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class MainShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIdx = navigationShell.currentIndex;

    final items = [
      {'icon': Icons.today_outlined, 'active': Icons.today_rounded, 'label': l10n.navToday},
      {'icon': Icons.flag_outlined, 'active': Icons.flag_rounded, 'label': l10n.navGoals},
      {'icon': Icons.calendar_month_outlined, 'active': Icons.calendar_month_rounded, 'label': l10n.navCalendar},
      {'icon': Icons.insights_outlined, 'active': Icons.insights_rounded, 'label': l10n.navProgress},
      {'icon': Icons.menu_book_outlined, 'active': Icons.menu_book_rounded, 'label': l10n.navQuran},
    ];

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
                height: 66,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131F1A).withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFC59B27).withValues(alpha: 0.35),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (i) {
                    final selected = i == currentIdx;
                    final item = items[i];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        navigationShell.goBranch(
                          i,
                          initialLocation: i == currentIdx,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: selected ? 14 : 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF0D4A3A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (selected ? item['active'] : item['icon']) as IconData,
                              size: 21,
                              color: selected
                                  ? const Color(0xFFE6C665)
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              Text(
                                item['label'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
            ),
          ),
        ),
      ),
    );
  }
}
