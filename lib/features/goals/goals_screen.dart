import '../../app/premium_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_mapper.dart';
import '../../core/hizb_divisions.dart';
import '../../core/tadarruj_brand.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_repository.dart';
import '../progress/progress_repository.dart';
import '../today/today_repository.dart';
import 'goals_repository.dart';

String _toArNum(Object v) {
  const w = ['0','1','2','3','4','5','6','7','8','9'];
  const e = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  var s = v.toString();
  for (int i = 0; i < 10; i++) { s = s.replaceAll(w[i], e[i]); }
  return s;
}

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  Future<void> _showEditGoalDialog(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
    bool isFr,
  ) async {
    final titleCtrl = TextEditingController(text: goal.title);
    DateTime selectedDate =
        goal.createdAt.add(Duration(days: goal.durationDays));
    if (selectedDate.isBefore(DateTime.now())) {
      selectedDate = DateTime.now().add(const Duration(days: 14));
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isFr ? 'Modifier l’objectif' : 'Edit goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: isFr ? 'Titre de l’objectif' : 'Goal title',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(isFr ? 'Nouvelle date cible' : 'New target date'),
                subtitle: Text(
                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(isFr ? 'Annuler' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(isFr ? 'Enregistrer' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && titleCtrl.text.trim().isNotEmpty) {
      await ref.read(goalsRepositoryProvider).updateGoal(
            goalId: goal.id,
            title: titleCtrl.text.trim(),
            newDueDate: selectedDate,
          );
      ref.invalidate(goalsListProvider);
        ref.invalidate(archivedGoalsListProvider);
        ref.invalidate(todayTasksProvider);
        ref.invalidate(calendarTasksByDateProvider);
        final _ = ref.refresh(progressSummaryProvider);
      ref.invalidate(progressSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TadarrujColors.emeraldPrimary,
            content: Text(isFr ? 'Objectif mis à jour !' : 'Goal updated!'),
          ),
        );
      }
    }
  }

  Future<void> _confirmResetGoal(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
    bool isFr,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFr ? 'Réinitialiser la progression ?' : 'Reset progress?'),
        content: Text(
          isFr
              ? 'La progression de « ${goal.title} » reviendra à 0 %.'
              : 'Progress for "${goal.title}" will be reset to 0%.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isFr ? 'Réinitialiser' : 'Reset'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref
          .read(goalsRepositoryProvider)
          .resetGoalProgress(goal.id, goal.startPage);
      ref.invalidate(goalsListProvider);
        ref.invalidate(archivedGoalsListProvider);
        ref.invalidate(todayTasksProvider);
        ref.invalidate(calendarTasksByDateProvider);
        final _ = ref.refresh(progressSummaryProvider);
      ref.invalidate(todayTasksProvider);
      ref.invalidate(progressSummaryProvider);
    }
  }

  Future<void> _confirmDeleteGoal(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
    bool isFr,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFr ? 'Supprimer cet objectif ?' : 'Delete this goal?'),
        content: Text(
          isFr
              ? 'L’objectif « ${goal.title} » et ses séances planifiées à venir seront supprimés.'
              : 'Goal "${goal.title}" and its upcoming scheduled sessions will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isFr ? 'Supprimer' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(goalsRepositoryProvider).deleteGoal(goal.id);
      ref.invalidate(goalsListProvider);
        ref.invalidate(archivedGoalsListProvider);
        ref.invalidate(todayTasksProvider);
        ref.invalidate(calendarTasksByDateProvider);
        final _ = ref.refresh(progressSummaryProvider);
      ref.invalidate(todayTasksProvider);
      ref.invalidate(calendarTasksByDateProvider);
      ref.invalidate(progressSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TadarrujColors.emeraldPrimary,
            content: Text(isFr ? 'Objectif supprimé.' : 'Goal deleted.'),
          ),
        );
      }
    }
  }

  void _handleCreateGoal(BuildContext context, WidgetRef ref, List activeGoals) {
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium && activeGoals.isNotEmpty) {
      final isFr = Localizations.localeOf(context).languageCode != 'en';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isFr ? 'Objectifs multiples • Tadarruj+' : 'Multiple goals • Tadarruj+'),
          content: Text(
            isFr
                ? 'La version gratuite permet de suivre 1 objectif actif à la fois. Passez à Tadarruj+ pour gérer plusieurs objectifs en parallèle, accéder aux Halaqas et parrainer un étudiant.'
                : 'The free version supports 1 active goal at a time. Upgrade to Tadarruj+ for unlimited parallel goals, Halaqas, and student sponsorship.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isFr ? 'Plus tard' : 'Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/premium');
              },
              child: Text(isFr ? 'Découvrir Tadarruj+' : 'Explore Tadarruj+'),
            ),
          ],
        ),
      );
      return;
    }
    context.push('/goals/new');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final goalsAsync = ref.watch(goalsListProvider);
    final isFr = Localizations.localeOf(context).languageCode != 'en';

    return Scaffold(
      appBar: TadarrujAppBar(
        title: l10n.navGoals,
        extraActions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: TadarrujColors.goldAccent,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _handleCreateGoal(context, ref, goalsAsync.valueOrNull ?? []),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                Localizations.localeOf(context).languageCode == 'ar' ? 'هدف جديد' : (isFr ? 'Nouvel objectif' : 'New goal'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: TadarrujColors.emeraldPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, color: TadarrujColors.goldSoft),
        label: Text(
          Localizations.localeOf(context).languageCode == 'ar' ? 'هدف جديد' : (isFr ? 'Nouvel objectif' : 'New goal'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _handleCreateGoal(context, ref, goalsAsync.valueOrNull ?? []),
      ),
      body: Stack(
        children: [
          const IslamicPatternOverlay(opacity: 0.04),
          goalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(mapAuthError(err, l10n), textAlign: TextAlign.center),
              ),
            ),
            data: (goals) {
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(goalsListProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF155740),
                            Color(0xFF287D5C),
                            Color(0xFF8C9440),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.flag_rounded,
                              color: TadarrujColors.goldSoft,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFr
                                      ? (Localizations.localeOf(context).languageCode == 'ar' ? 'أهدافي القرآنية' : 'Mes objectifs Coran')
                                      : 'My Quran Goals',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isFr
                                      ? (Localizations.localeOf(context).languageCode == 'ar' ? '${_toArNum(goals.length)} هدف نشط • عدّل أو أعد ضبط أو احذف أهدافك أدناه' : '${goals.length} objectif(s) actif(s) • Modifie, réinitialise ou supprime tes objectifs ci-dessous')
                                      : '${goals.length} active goal(s) • Edit, reset or delete your goals below',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (goals.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  size: 46, color: TadarrujColors.goldAccent),
                              const SizedBox(height: 12),
                              Text(
                                isFr
                                    ? 'Aucun objectif actif'
                                    : 'No active goals',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => _handleCreateGoal(context, ref, goalsAsync.valueOrNull ?? []),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(
                                  isFr
                                      ? 'Créer mon premier objectif'
                                      : 'Create my first goal',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...goals.map((g) {
                        final totalPages =
                            (g.endPage - g.startPage + 1).clamp(1, 604);
                        final totalLines = totalPages * 15;
                        final h1 = HizbDivisions.getForPage(g.startPage).number;
                        final h2 = HizbDivisions.getForPage(g.endPage).number;
                        final hizbText =
                            h1 == h2 ? 'Hizb $h1' : 'Hizb $h1 → $h2';

                        Color badgeColor = TadarrujColors.emeraldPrimary;
                        if (g.goalType == 'memorisation') {
                          badgeColor = const Color(0xFF4C6EF5);
                        } else if (g.goalType == 'revision') {
                          badgeColor = const Color(0xFFD97706);
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            badgeColor.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        Localizations.localeOf(context).languageCode == 'ar' ? (g.goalType == 'memorisation' ? 'حفظ' : (g.goalType == 'revision' ? 'مراجعة' : 'تلاوة')) : g.goalType.toUpperCase(),
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '⏱ ${g.durationDays} j • $hizbText',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  g.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Localizations.localeOf(context).languageCode == 'ar' ? 'من صفحة ${_toArNum(g.startPage)} إلى ${_toArNum(g.endPage)} (${_toArNum(totalPages)} صفحة • ${_toArNum(totalLines)} سطراً)' : (isFr ? 'Pages ${g.startPage} à ${g.endPage} ($totalPages p. • $totalLines lignes)' : 'Pages ${g.startPage} to ${g.endPage} ($totalPages p. • $totalLines lines)'),
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                                const Divider(height: 20),
                                // Barre de gestion explicite (Modifier / Réinitialiser / Supprimer)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showEditGoalDialog(
                                          context, ref, g, isFr),
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 16),
                                      label: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'تعديل' : (isFr ? 'Modifier' : 'Edit')),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _confirmResetGoal(
                                          context, ref, g, isFr),
                                      icon: const Icon(Icons.restart_alt_rounded,
                                          size: 16),
                                      label: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'إعادة ضبط' : (isFr ? 'Réinitialiser' : 'Reset')),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(
                                            color: Colors.redAccent),
                                      ),
                                      onPressed: () => _confirmDeleteGoal(
                                          context, ref, g, isFr),
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16),
                                      label: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'حذف' : (isFr ? 'Supprimer' : 'Delete')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 18),
                    Consumer(
                      builder: (context, ref, _) {
                        final archivedAsync = ref.watch(archivedGoalsListProvider);
                        return archivedAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (archived) {
                            if (archived.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      Localizations.localeOf(context).languageCode == 'ar' ? 'الأرشيف (${_toArNum(archived.length)})' : 'Archives (${archived.length})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...archived.map((ag) => Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.archive_outlined,
                                          color: Colors.grey,
                                        ),
                                        title: Text(
                                          ag.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        subtitle: Text(
                                          Localizations.localeOf(context).languageCode == 'ar' ? 'من صفحة ${_toArNum(ag.startPage)} إلى ${_toArNum(ag.endPage)}' : (isFr ? 'Pages ${ag.startPage} à ${ag.endPage}' : 'Pages ${ag.startPage} to ${ag.endPage}'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: TextButton.icon(
                                          onPressed: () async {
                                            await ref
                                                .read(goalsRepositoryProvider)
                                                .restoreGoal(ag.id);
                                            ref.invalidate(goalsListProvider);
                                            ref.invalidate(archivedGoalsListProvider);
                                            ref.invalidate(todayTasksProvider);
                                            ref.invalidate(calendarTasksByDateProvider);
                                            final _ = ref.refresh(progressSummaryProvider);
                                          },
                                          icon: const Icon(Icons.unarchive_outlined, size: 16),
                                          label: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'استعادة' : (isFr ? 'Restaurer' : 'Restore')),
                                        ),
                                      ),
                                    )),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
