import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/locale_provider.dart';
import '../../core/supabase_client.dart';
import '../../core/tadarruj_brand.dart';
import '../../l10n/app_localizations.dart';
import 'premium_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _dailyNotifEnabled = true;
  TimeOfDay _notifTime = const TimeOfDay(hour: 8, minute: 0);
  Set<int> _restDays = {}; // 1=Lun .. 7=Dim

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    _dailyNotifEnabled = (meta['daily_notif_enabled'] as bool?) ?? true;
    final hour = (meta['daily_notif_hour'] as int?) ?? 8;
    final minute = (meta['daily_notif_minute'] as int?) ?? 0;
    _notifTime = TimeOfDay(hour: hour, minute: minute);

    final rawRest = meta['rest_days'];
    if (rawRest is List) {
      _restDays = rawRest.map((e) => (e as num).toInt()).toSet();
    }
  }

  Future<void> _savePreferences(bool isFr) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'daily_notif_enabled': _dailyNotifEnabled,
            'daily_notif_hour': _notifTime.hour,
            'daily_notif_minute': _notifTime.minute,
            'rest_days': _restDays.toList(),
          },
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFr
                  ? 'Préférences enregistrées (${_notifTime.format(context)})'
                  : 'Preferences saved (${_notifTime.format(context)})',
            ),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentLocale = ref.watch(localeProvider);
    final client = ref.watch(supabaseClientProvider);
    final user = client.auth.currentUser;

    final displayName =
        (user?.userMetadata?['display_name'] as String?) ?? '';
    final email = user?.email ?? '';
    final isFr = currentLocale.languageCode == 'fr';
    final isAr = currentLocale.languageCode == 'ar';

    const dayLabelsFr = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
    const dayLabelsEn = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    return Scaffold(
      appBar: AppBar(
          foregroundColor: Colors.white,
        title: Row(children: [const TadarrujLogo(size: 30, showTitle: false), const SizedBox(width: 10), Flexible(child: Text(l10n.settingsTitle))]),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 36),
        children: [
          // Bannière TADARRUJ Premium
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  TadarrujColors.emeraldDeep,
                  TadarrujColors.emeraldPrimary,
                ],
              ),
              border: Border.all(
                color: TadarrujColors.goldAccent.withValues(alpha: 0.6),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: const TadarrujLogo(size: 42, showTitle: false),
              title: Text(
                isAr ? 'الترقية إلى تدرّج بلس' : (isFr ? 'Passer à TADARRUJ Premium' : 'Upgrade to TADARRUJ Pro'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                isAr ? 'أهداف غير محدودة، متابعة 60 حزباً ومراجعة ذكية' : (isFr ? 'Objectifs illimités, suivi 60 Hizb & révisions avancées' : 'Unlimited goals, 60-Hizb tracking & smart reviews'),
                style: const TextStyle(
                  color: TadarrujColors.goldSoft,
                  fontSize: 12.5,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: TadarrujColors.goldSoft,
                size: 16,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Compte
          Text(
            l10n.settingsAccountSection,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.14),
                foregroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.person_outline),
              ),
              title: Text(
                displayName.isNotEmpty ? displayName : email,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: displayName.isNotEmpty ? Text(email) : null,
            ),
          ),
          const SizedBox(height: 20),

          // Notifications & Rappels quotidiens
          Text(
            isAr ? 'الإشعارات والتذكير اليومي' : (isFr ? 'Notifications & Rappels quotidiens' : 'Daily Reminders'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: Text(
                    isAr ? 'التذكير اليومي' : (isFr ? 'Rappel quotidien' : 'Daily reminder'),
                  ),
                  subtitle: Text(
                    isAr ? 'استقبال تنبيه لطيف للمتابعة كل يوم' : (isFr ? 'Recevoir une notification douce chaque jour' : 'Receive a gentle daily notification'),
                  ),
                  value: _dailyNotifEnabled,
                  onChanged: (val) {
                    setState(() => _dailyNotifEnabled = val);
                    _savePreferences(isFr);
                  },
                ),
                if (_dailyNotifEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: Text(
                      isAr ? 'وقت التذكير' : (isFr ? 'Heure du rappel' : 'Reminder time'),
                    ),
                    trailing: Chip(
                      label: Text(
                        _notifTime.format(context),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _notifTime,
                      );
                      if (picked != null) {
                        setState(() => _notifTime = picked);
                        _savePreferences(isFr);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Jours de repos hebdomadaires
          Text(
            isAr ? 'أيام الراحة الأسبوعية' : (isFr ? 'Jours de repos chaque semaine' : 'Weekly rest days'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (idx) {
                  final dayNum = idx + 1;
                  final selected = _restDays.contains(dayNum);
                  const dayLabelsAr = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
                  final label = isAr ? dayLabelsAr[idx] : (isFr ? dayLabelsFr : dayLabelsEn)[idx];
                  return FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _restDays.add(dayNum);
                        } else {
                          _restDays.remove(dayNum);
                        }
                      });
                      _savePreferences(isFr);
                    },
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Apparence (Thème Clair / Sombre)
          Text(
            isAr ? 'المظهر (فاتح / داكن)' : (isFr ? 'Apparence (Clair / Sombre)' : 'Appearance (Light / Dark)'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_rounded),
                    label: Text(isAr ? 'فاتح' : (isFr ? 'Clair' : 'Light')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_rounded),
                    label: Text(isAr ? 'داكن' : (isFr ? 'Sombre' : 'Dark')),
                  ),
                ],
                selected: {ref.watch(themeModeProvider)},
                onSelectionChanged: (sel) {
                  ref.read(themeModeProvider.notifier).state = sel.first;
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Langue
          Text(
            isAr ? 'اللغة' : (isFr ? 'Langue' : 'Language'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fr', label: Text('Français')),
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                ],
                selected: {currentLocale.languageCode},
                onSelectionChanged: (sel) {
                  ref
                      .read(localeProvider.notifier)
                      .state = Locale(sel.first);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Déconnexion
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () async {
              await client.auth.signOut();
              if (context.mounted) {
                context.go('/auth');
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(isFr ? 'Se déconnecter' : 'Sign out'),
          ),
        ],
      ),
    );
  }
}


class _DailyReminderCard extends StatefulWidget {
  final bool isFr;
  final bool isAr;
  const _DailyReminderCard({required this.isFr, required this.isAr});

  @override
  State<_DailyReminderCard> createState() => _DailyReminderCardState();
}

class _DailyReminderCardState extends State<_DailyReminderCard> {
  bool _enabled = true;
  String _slot = 'fajr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool('daily_reminder_enabled') ?? true;
      _slot = prefs.getString('daily_reminder_slot') ?? 'fajr';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder_enabled', _enabled);
    await prefs.setString('daily_reminder_slot', _slot);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.isAr
        ? 'التذكير اليومي الهادئ'
        : (widget.isFr ? 'Rituel & Rappel bienveillant' : 'Gentle Daily Reminder');
    final subtitle = widget.isAr
        ? '٥ دقائق مع مصحفك اليوم — يتوقف تلقائياً بعد إتمام وردك'
        : (widget.isFr
            ? '« 5 minutes avec ton Mushaf ? » — désactivé dès que ta séance est validée'
            : '“5 minutes with your Mushaf?” — auto-paused once today’s session is done');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (v) {
                    setState(() => _enabled = v);
                    _save();
                  },
                ),
              ],
            ),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            if (_enabled) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ('fajr', widget.isAr ? 'بعد الفجر' : (widget.isFr ? 'Après Fajr' : 'After Fajr')),
                  ('asr', widget.isAr ? 'بعد العصر' : (widget.isFr ? 'Après ‘Asr' : 'After ‘Asr')),
                  ('isha', widget.isAr ? 'قبل النوم' : (widget.isFr ? 'Le soir' : 'Evening')),
                ].map((item) {
                  final sel = _slot == item.$1;
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(item.$2),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => _slot = item.$1);
                      _save();
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
