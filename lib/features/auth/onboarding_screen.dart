import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/locale_provider.dart';
import '../../core/tadarruj_brand.dart';
import '../../l10n/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final isAr = currentLocale.languageCode == 'ar';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const IslamicPatternOverlay(opacity: 0.035),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const TadarrujLogo(size: 32, showTitle: false),
                      const SizedBox(width: 10),
                      Text(
                        isAr ? 'تَدَرُّج' : 'Tadarruj',
                        style: GoogleFonts.elMessiri(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? TadarrujColors.goldSoft
                              : TadarrujColors.emeraldDeep,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/auth'),
                        child: Text(
                          isAr
                              ? 'تخطي'
                              : (currentLocale.languageCode == 'fr'
                                  ? 'Passer'
                                  : 'Skip'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      children: [
                        _OnboardingPage(
                          useLogo: true,
                          icon: Icons.spa_outlined,
                          title: l10n.onboardingTitle1,
                          description: l10n.onboardingDesc1,
                        ),
                        _OnboardingPage(
                          icon: Icons.language_outlined,
                          title: l10n.onboardingTitle2,
                          description: l10n.onboardingDesc2,
                          extraContent: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'fr', label: Text('Français')),
                              ButtonSegment(
                                  value: 'en', label: Text('English')),
                              ButtonSegment(
                                  value: 'ar', label: Text('العربية')),
                            ],
                            selected: {
                              ['fr', 'en', 'ar']
                                      .contains(currentLocale.languageCode)
                                  ? currentLocale.languageCode
                                  : 'fr'
                            },
                            onSelectionChanged: (selection) {
                              ref.read(localeProvider.notifier).state =
                                  Locale(selection.first);
                            },
                          ),
                        ),
                        _OnboardingPage(
                          icon: Icons.auto_stories_outlined,
                          title: l10n.onboardingTitle3,
                          description: l10n.onboardingDesc3,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isSelected ? 24 : 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary
                                  .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _nextStep,
                      child: Text(
                        _currentPage < 2 ? l10n.nextButton : l10n.startButton,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final bool useLogo;
  final IconData icon;
  final String title;
  final String description;
  final Widget? extraContent;

  const _OnboardingPage({
    this.useLogo = false,
    required this.icon,
    required this.title,
    required this.description,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (useLogo)
          TadarrujLogo(
            size: 76,
            showTitle: true,
            titleColor:
                isDark ? TadarrujColors.goldSoft : TadarrujColors.emeraldDeep,
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: TadarrujColors.goldAccent.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              icon,
              size: 52,
              color: theme.colorScheme.primary,
            ),
          ),
        const SizedBox(height: 28),
        Text(
          title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(
          description,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (extraContent != null) ...[
          const SizedBox(height: 26),
          extraContent!,
        ],
      ],
    );
  }
}
