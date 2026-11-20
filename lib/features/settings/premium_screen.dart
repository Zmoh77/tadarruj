import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/premium_provider.dart';
import '../../core/tadarruj_brand.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List _myHalaqas = [];
  String? _selectedHalaqaId;
  List _members = [];
  Map<String, List> _studentGoalsByUserId = {};
  Map<String, List> _studentTasksByUserId = {};
  List _joinedHalaqas = [];
  List _myOwnGoals = [];

  final _halaqaNameCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();
  final _studentDisplayNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = _client.auth.currentUser;
    final defaultName = user?.userMetadata?['full_name']?.toString() ??
        user?.email?.split('@').first ??
        'Élève';
    _studentDisplayNameCtrl.text = defaultName;
    _loadAllData();
  }

  @override
  void dispose() {
    _halaqaNameCtrl.dispose();
    _joinCodeCtrl.dispose();
    _studentDisplayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _loading = true);

    try {
      // Mes propres objectifs (pour soumettre une demande de validation en tant qu'élève)
      final ownGoalsRows = await _client
          .from('goals')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active');
      _myOwnGoals = List.from(ownGoalsRows as List);

      // 1. Halaqas où je suis enseignant
      final teacherRows = await _client
          .from('halaqas')
          .select()
          .eq('teacher_id', userId)
          .order('created_at', ascending: true);
      _myHalaqas = List.from(teacherRows as List);

      if (_myHalaqas.isNotEmpty) {
        _selectedHalaqaId ??= _myHalaqas.first['id'] as String;
        await _loadMembersAndGoals(_selectedHalaqaId!);
      } else {
        _members = [];
        _studentGoalsByUserId = {};
      }

      // 2. Halaqas où je suis élève
      final studentRows = await _client
          .from('halaqa_members')
          .select('*, halaqas(name, invite_code)')
          .eq('student_id', userId);
      _joinedHalaqas = List.from(studentRows as List);
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMembersAndGoals(String halaqaId) async {
    final mRows = await _client
        .from('halaqa_members')
        .select()
        .eq('halaqa_id', halaqaId)
        .order('joined_at', ascending: true);
    _members = List.from(mRows as List);

    final Map<String, List> goalsMap = {};
    final Map<String, List> tasksMap = {};
    for (final m in _members) {
      final sId = (m as Map)['student_id'] as String;
      final gRows = await _client
          .from('goals')
          .select()
          .eq('user_id', sId)
          .eq('status', 'active');
      goalsMap[sId] = List.from(gRows as List);

      try {
        final tRows = await _client
            .from('study_tasks')
            .select()
            .eq('user_id', sId)
            .order('scheduled_date', ascending: false)
            .limit(40);
        tasksMap[sId] = List.from(tRows as List);
      } catch (_) {
        tasksMap[sId] = [];
      }
    }
    _studentGoalsByUserId = goalsMap;
    _studentTasksByUserId = tasksMap;
  }

  Future<void> _activatePremium(bool isFr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tadarruj_is_premium', true);
    ref.read(isPremiumProvider.notifier).state = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TadarrujColors.emeraldPrimary,
          content: Text(
            isFr
                ? '🎉 Mode Enseignant Premium activé !'
                : '🎉 Teacher Premium mode activated!',
          ),
        ),
      );
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return 'TDJ-${List.generate(5, (_) => chars[rnd.nextInt(chars.length)]).join()}';
  }

  Future<void> _createHalaqa(bool isFr) async {
    final name = _halaqaNameCtrl.text.trim();
    final userId = _client.auth.currentUser?.id;
    if (name.isEmpty || userId == null) return;

    try {
      final code = _generateInviteCode();
      final inserted = await _client
          .from('halaqas')
          .insert({
            'teacher_id': userId,
            'name': name,
            'invite_code': code,
          })
          .select()
          .single();

      _halaqaNameCtrl.clear();
      _selectedHalaqaId = inserted['id'] as String;
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TadarrujColors.emeraldPrimary,
            content: Text(
              isFr
                  ? 'Halaqa « $name » créée ! Code : $code'
                  : 'Halaqa "$name" created! Code: $code',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur SQL : $e')),
        );
      }
    }
  }

  Future<void> _joinHalaqaByCode(bool isFr) async {
    final code = _joinCodeCtrl.text.trim().toUpperCase();
    final sName = _studentDisplayNameCtrl.text.trim();
    final userId = _client.auth.currentUser?.id;
    if (code.isEmpty || userId == null) return;

    try {
      final halaqa = await _client
          .from('halaqas')
          .select()
          .eq('invite_code', code)
          .maybeSingle();

      if (halaqa == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                isFr ? 'Code Halaqa introuvable.' : 'Halaqa code not found.',
              ),
            ),
          );
        }
        return;
      }

      await _client.from('halaqa_members').upsert({
        'halaqa_id': halaqa['id'],
        'student_id': userId,
        'student_name': sName.isEmpty ? 'Élève' : sName,
      });

      _joinCodeCtrl.clear();
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TadarrujColors.emeraldPrimary,
            content: Text(
              isFr
                  ? 'Tu as rejoint la Halaqa « ${halaqa['name']} » !'
                  : 'Joined Halaqa "${halaqa['name']}"!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _submitValidationRequest(Map membership, bool isFr) async {
    final noteCtrl = TextEditingController(
      text: _myOwnGoals.isNotEmpty
          ? 'Palier atteint sur : ${(_myOwnGoals.first as Map)['title']}'
          : 'Demande de validation de récitation / mémorisation',
    );

    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFr
            ? 'Demander une validation au professeur'
            : 'Request validation from teacher'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: isFr ? 'Précision sur le palier' : 'Milestone details',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(isFr ? 'Envoyer la demande' : 'Send request'),
          ),
        ],
      ),
    );

    if (send == true) {
      await _client.from('halaqa_members').update({
        'pending_validation': true,
        'pending_note': noteCtrl.text.trim(),
        'validation_status': 'pending',
      }).eq('id', membership['id']);

      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TadarrujColors.emeraldPrimary,
            content: Text(
              isFr
                  ? '📩 Demande envoyée ! Ton professeur a été notifié.'
                  : '📩 Request sent! Your teacher has been notified.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _reviewStudentRequest({
    required Map member,
    required bool approved,
    required bool isFr,
    Map? targetGoal,
  }) async {
    final commCtrl = TextEditingController(
        text: (member['teacher_comment'] as String?) ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          approved
              ? (isFr
                  ? 'Valider le palier de ${member['student_name']}'
                  : 'Approve ${member['student_name']}\'s milestone')
              : (isFr
                  ? 'Demander une révision à ${member['student_name']}'
                  : 'Request revision from ${member['student_name']}'),
        ),
        content: TextField(
          controller: commCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: isFr
                ? 'Commentaire pour l’élève (optionnel)'
                : 'Feedback for student (optional)',
            hintText: approved
                ? 'Ex: MachaAllah, palier validé avec succès !'
                : 'Ex: Revois les règles de Tajwid sur les derniers versets.',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  approved ? const Color(0xFF28A745) : Colors.orangeAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(approved
                ? (isFr ? 'Valider & Envoyer' : 'Approve & Send')
                : (isFr ? 'Envoyer le retour' : 'Send feedback')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentValidatedHizb =
        (member['validated_hizb'] as num?)?.toInt() ?? 0;

    if (approved && targetGoal != null) {
      final startPos = (targetGoal['start_pos'] as num?)?.toDouble() ?? 0.0;
      final endPos = (targetGoal['end_pos'] as num?)?.toDouble() ?? 1.0;
      final currentPos =
          (targetGoal['current_pos'] as num?)?.toDouble() ?? startPos;
      final step = ((endPos - startPos) / 5).clamp(1.0, 20.0);
      final nextPos = (currentPos + step).clamp(startPos, endPos);

      await _client.from('goals').update({
        'current_pos': nextPos,
      }).eq('id', targetGoal['id']);
    }

    await _client.from('halaqa_members').update({
      'pending_validation': false,
      'validation_status': approved ? 'approved' : 'needs_revision',
      'teacher_comment': commCtrl.text.trim(),
      if (approved)
        'validated_hizb': (currentValidatedHizb + 1).clamp(1, 60),
      if (approved)
        'last_validated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', member['id']);

    if (_selectedHalaqaId != null) {
      await _loadMembersAndGoals(_selectedHalaqaId!);
      if (mounted) setState(() {});
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              approved ? TadarrujColors.emeraldPrimary : Colors.orange,
          content: Text(
            approved
                ? (isFr
                    ? '✅ Palier validé et commentaire envoyé à l’élève !'
                    : '✅ Milestone approved and feedback sent!')
                : (isFr
                    ? '📝 Demande de révision envoyée à l’élève.'
                    : '📝 Revision note sent to student.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode != 'en';
    final isPremium = ref.watch(isPremiumProvider);
    final pendingCount =
        _members.where((m) => (m as Map)['pending_validation'] == true).length;

    return Scaffold(
      appBar: TadarrujAppBar(
        title: 'Tadarruj+',
      ),
      body: Stack(
        children: [
          const IslamicPatternOverlay(opacity: 0.04),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: _buildPlansAndSadaqahSection(context, isFr, isSubscribed: isPremium),
                    ),
                  ),
                  if (isPremium) ...[
                    const SizedBox(height: 24),
                    Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0E3B2E),
                          Color(0xFF1B5E48),
                          Color(0xFFC59B27),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium_rounded,
                                color: TadarrujColors.goldSoft, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isFr
                                    ? 'Espace Enseignant (Tadarruj+)'
                                    : 'Teacher Space (Tadarruj+)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            if (pendingCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '🔔 $pendingCount demande(s)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isFr
                              ? 'Reçois les demandes de validation de tes élèves, consulte leurs objectifs, valide ou demande une révision avec commentaire.'
                              : 'Receive validation requests from students, review their goals, approve or request revision with comments.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13,
                          ),
                        ),
                        if (!isPremium) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: TadarrujColors.goldSoft,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () => _activatePremium(isFr),
                              icon: const Icon(Icons.bolt_rounded),
                              label: Text(
                                isFr
                                    ? 'Activer l’abonnement Premium'
                                    : 'Activate Premium subscription',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isPremium) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFr
                                  ? 'Créer une nouvelle Halaqa'
                                  : 'Create a new Halaqa',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _halaqaNameCtrl,
                                    decoration: InputDecoration(
                                      labelText: isFr
                                          ? 'Nom de la Halaqa'
                                          : 'Halaqa name',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.icon(
                                  onPressed: () => _createHalaqa(isFr),
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(isFr ? 'Créer' : 'Create'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_myHalaqas.isNotEmpty) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _myHalaqas.map((h) {
                            final hMap = h as Map;
                            final hId = hMap['id'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: RawChip(showCheckmark: false, 
                                label: Text(hMap['name']?.toString() ?? 'Halaqa'),
                                selected: _selectedHalaqaId == hId,
                                onSelected: (_) async {
                                  _selectedHalaqaId = hId;
                                  await _loadMembersAndGoals(hId);
                                  if (mounted) setState(() {});
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTeacherHalaqaDashboard(isFr),
                    ],
                  ],

                  const Divider(height: 32),

                  // ESPACE ÉLÈVE
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school_rounded,
                                  color: TadarrujColors.emeraldPrimary),
                              const SizedBox(width: 8),
                              Text(
                                isFr
                                    ? 'Espace Élève • Mes Halaqas'
                                    : 'Student Space • My Halaqas',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _studentDisplayNameCtrl,
                                  decoration: InputDecoration(
                                    labelText:
                                        isFr ? 'Ton prénom' : 'Your name',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _joinCodeCtrl,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Code (TDJ-XXXXX)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () => _joinHalaqaByCode(isFr),
                                child: Text(isFr ? 'Rejoindre' : 'Join'),
                              ),
                            ],
                          ),
                          if (_joinedHalaqas.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ..._joinedHalaqas.map((jm) {
                              final row = jm as Map;
                              final hInfo = (row['halaqas'] as Map?) ?? {};
                              final comment =
                                  (row['teacher_comment'] as String?) ?? '';
                              final hizbVal =
                                  (row['validated_hizb'] as num?)?.toInt() ?? 0;
                              final isPending =
                                  row['pending_validation'] == true;
                              final status =
                                  (row['validation_status'] as String?) ??
                                      'none';

                              return Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: TadarrujColors.emeraldPrimary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: TadarrujColors.emeraldPrimary
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '🕌 ${hInfo['name'] ?? 'Halaqa'} • Paliers validés : $hizbVal',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5),
                                          ),
                                        ),
                                        if (status == 'approved')
                                          const Chip(
                                            label: Text('✅ Validé'),
                                            backgroundColor: Color(0xFF28A745),
                                            labelStyle:
                                                TextStyle(color: Colors.white),
                                          )
                                        else if (status == 'needs_revision')
                                          const Chip(
                                            label: Text('🔄 À revoir'),
                                            backgroundColor: Colors.orange,
                                            labelStyle:
                                                TextStyle(color: Colors.white),
                                          ),
                                      ],
                                    ),
                                    if (comment.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '💬 Professeur : « $comment »',
                                        style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: isPending
                                            ? null
                                            : () => _submitValidationRequest(
                                                row, isFr),
                                        icon: Icon(isPending
                                            ? Icons.hourglass_top_rounded
                                            : Icons.send_rounded),
                                        label: Text(
                                          isPending
                                              ? (isFr
                                                  ? 'Demande envoyée (en attente du professeur)'
                                                  : 'Request sent (awaiting teacher)')
                                              : (isFr
                                                  ? 'Soumettre mon palier au professeur'
                                                  : 'Submit milestone to teacher'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeacherHalaqaDashboard(bool isFr) {
    final currentHalaqa = _myHalaqas.firstWhere(
      (h) => (h as Map)['id'] == _selectedHalaqaId,
      orElse: () => _myHalaqas.first,
    ) as Map;

    final code = currentHalaqa['invite_code']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentHalaqa['name']?.toString() ?? 'Halaqa',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: TadarrujColors.goldAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: TadarrujColors.goldAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(behavior: HitTestBehavior.opaque, 
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFr
                                    ? 'Code $code copié ! Partage-le à tes élèves.'
                                    : 'Code $code copied!',
                              ),
                            ),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            if (_members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isFr
                      ? 'Partage le code $code à tes élèves. Dès qu’ils rejoignent, leurs objectifs et demandes apparaîtront ici !'
                      : 'Share code $code with your students.',
                ),
              )
            else
              ..._members.map((m) {
                final member = m as Map;
                final sId = member['student_id'] as String;
                final sName = member['student_name']?.toString() ?? 'Élève';
                final comment = (member['teacher_comment'] as String?) ?? '';
                final vHizb = (member['validated_hizb'] as num?)?.toInt() ?? 0;
                final isPending = member['pending_validation'] == true;
                final pendingNote =
                    (member['pending_note'] as String?) ?? '';
                final sGoals = _studentGoalsByUserId[sId] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.orange.withValues(alpha: 0.08)
                        : null,
                    border: Border.all(
                      color: isPending
                          ? Colors.orangeAccent
                          : TadarrujColors.goldAccent.withValues(alpha: 0.35),
                      width: isPending ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPending) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFr
                                    ? '🔔 DEMANDE DE VALIDATION DE $sName'
                                    : '🔔 VALIDATION REQUEST FROM $sName',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                    color: Colors.deepOrange),
                              ),
                              if (pendingNote.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('« $pendingNote »',
                                    style: const TextStyle(fontSize: 13)),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF28A745),
                                    ),
                                    onPressed: () => _reviewStudentRequest(
                                      member: member,
                                      approved: true,
                                      isFr: isFr,
                                      targetGoal: sGoals.isNotEmpty
                                          ? (sGoals.first as Map)
                                          : null,
                                    ),
                                    icon: const Icon(Icons.check_rounded,
                                        size: 16),
                                    label: Text(isFr
                                        ? 'Valider + Commenter'
                                        : 'Approve + Comment'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _reviewStudentRequest(
                                      member: member,
                                      approved: false,
                                      isFr: isFr,
                                    ),
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: Text(isFr
                                        ? 'Refuser / Réviser'
                                        : 'Reject / Revise'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: TadarrujColors.emeraldPrimary,
                            foregroundColor: Colors.white,
                            child: Text(sName[0].toUpperCase()),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5),
                                ),
                                Text(
                                  'Paliers validés : $vHizb',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _reviewStudentRequest(
                              member: member,
                              approved: true,
                              isFr: isFr,
                              targetGoal: sGoals.isNotEmpty
                                  ? (sGoals.first as Map)
                                  : null,
                            ),
                            icon: const Icon(Icons.comment_outlined, size: 16),
                            label: Text(isFr ? 'Valider / Comm.' : 'Validate'),
                          ),
                        ],
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '💬 Ton commentaire : « $comment »',
                          style: const TextStyle(
                              fontSize: 12.5, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildStudentVisualDashboard(
                        isFr: isFr,
                        sGoals: sGoals,
                        sTasks: _studentTasksByUserId[sId] ?? [],
                        validatedHizb: vHizb,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentVisualDashboard({
    required bool isFr,
    required List sGoals,
    required List sTasks,
    required int validatedHizb,
  }) {
    final now = DateTime.now();
    final List last7DaysBars = List.generate(7, (idx) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - idx));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      final dayLabel = labels[day.weekday - 1];

      int doneCount = 0;
      for (final t in sTasks) {
        final tm = t as Map;
        if (tm['scheduled_date'] == key && tm['status'] == 'done') {
          doneCount++;
        }
      }
      return {'label': dayLabel, 'count': doneCount, 'isToday': idx == 6};
    });

    final int totalDoneTasks =
        sTasks.where((t) => (t as Map)['status'] == 'done').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TadarrujColors.emeraldPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TadarrujColors.emeraldPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 18, color: TadarrujColors.emeraldPrimary),
              const SizedBox(width: 6),
              Text(
                isFr
                    ? 'Tableau de bord analytique de l’élève'
                    : 'Student Visual Analytics',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini-histogramme des 7 derniers jours + KPIs
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFr ? 'Assiduité (7 derniers jours)' : '7-Day Activity',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 62,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: last7DaysBars.map((b) {
                          final int c = b['count'] as int;
                          final bool isToday = b['isToday'] as bool;
                          final double barHeight =
                              c == 0 ? 8.0 : (16.0 + (c * 14.0)).clamp(16.0, 44.0);
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 14,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: c > 0
                                      ? const Color(0xFF28A745)
                                      : Colors.grey.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                b['label'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                                  color: isToday ? TadarrujColors.goldAccent : null,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: TadarrujColors.goldAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$totalDoneTasks',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: TadarrujColors.goldAccent,
                            ),
                          ),
                          Text(
                            isFr ? 'Séances faites' : 'Sessions done',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF28A745).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$validatedHizb',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF28A745),
                            ),
                          ),
                          Text(
                            isFr ? 'Paliers validés' : 'Validated',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Jauges circulaires par objectif
          if (sGoals.isEmpty)
            Text(
              isFr
                  ? 'Aucun objectif actif enregistré par cet élève.'
                  : 'No active goal recorded.',
              style: const TextStyle(fontSize: 12),
            )
          else
            ...sGoals.map((g) {
              final goal = g as Map;
              final startP = (goal['start_pos'] as num?)?.toDouble() ?? 0.0;
              final endP = (goal['end_pos'] as num?)?.toDouble() ?? 1.0;
              final curP = (goal['current_pos'] as num?)?.toDouble() ?? startP;
              final totalP = (endP - startP).clamp(0.1, 604.0);
              final doneP = (curP - startP).clamp(0.0, totalP);
              final double ratio = (doneP / totalP).clamp(0.0, 1.0);
              final int pct = (ratio * 100).round();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 5,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            color: const Color(0xFF28A745),
                          ),
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal['title']?.toString() ?? 'Objectif',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isFr
                                ? '${doneP.toStringAsFixed(1)} / ${totalP.toStringAsFixed(1)} pages accomplies'
                                : '${doneP.toStringAsFixed(1)} / ${totalP.toStringAsFixed(1)} pages completed',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }



  Widget _buildSubscriptionPaywall(BuildContext context, bool isFr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _buildPlansAndSadaqahSection(context, isFr, isSubscribed: false),
        ),
      ),
    );
  }

  Widget _buildPlansAndSadaqahSection(BuildContext context, bool isFr, {required bool isSubscribed}) {
    final rows = [
      (
        isFr ? 'Mushaf complet (604 pages), audio Tikrar & hors-ligne' : 'Full Mushaf (604 pages), Tikrar audio & offline',
        true,
        true,
      ),
      (
        isFr ? 'Objectifs de mémorisation & révision' : 'Memorization & revision goals',
        isFr ? '1 actif' : '1 active',
        isFr ? 'Illimités' : 'Unlimited',
      ),
      (
        isFr ? 'Projection vers le but final' : 'Trajectory to final goal',
        isFr ? '7 jours' : '7 days',
        isFr ? 'Long terme complet' : 'Full long-term',
      ),
      (
        isFr ? 'Accès Halaqas (Élèves, Enseignants & Instituts)' : 'Halaqa access (Students, Teachers & Institutes)',
        false,
        true,
      ),
      (
        isFr ? 'Contribution Fonds Solidaire Étudiant (Sadaqah)' : 'Student Solidarity Fund (Sadaqah)',
        false,
        true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Carte Abonnement Tadarruj+ (7,99 €/mois)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F291E), Color(0xFF173D2D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: TadarrujColors.goldAccent.withValues(alpha: 0.7), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TadarrujColors.goldAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: TadarrujColors.goldSoft, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tadarruj+',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                        ),
                        Text(
                          isFr
                              ? '7,99 € / mois • Halaqas, Instituts & Suivi illimité'
                              : '€7.99 / month • Halaqas, Institutes & Unlimited tracking',
                          style: const TextStyle(color: TadarrujColors.goldSoft, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _planChip(isFr ? 'Mensuel' : 'Monthly', '7,99 € / mois', true),
                  _planChip(isFr ? 'Annuel (-27%)' : 'Yearly (-27%)', '69,99 € / an', false),
                ],
              ),
              const SizedBox(height: 18),
              if (isSubscribed)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: TadarrujColors.goldAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFr ? '✓ Abonnement Tadarruj+ actif' : '✓ Tadarruj+ active',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await _client.auth.updateUser(UserAttributes(data: {'is_premium': false}));
                        ref.read(isPremiumProvider.notifier).state = false;
                      },
                      child: Text(
                        isFr ? 'Tester vue Gratuite (masquer Halaqa)' : 'Test Free view (hide Halaqa)',
                        style: const TextStyle(color: TadarrujColors.goldSoft, fontSize: 12),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: TadarrujColors.goldAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      await _client.auth.updateUser(UserAttributes(data: {'is_premium': true}));
                      ref.read(isPremiumProvider.notifier).state = true;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFr
                                  ? '✨ Tadarruj+ activé ! Votre espace Halaqa est débloqué.'
                                  : '✨ Tadarruj+ activated! Your Halaqa space is unlocked.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(
                      isFr ? 'Souscrire à Tadarruj+ — 7,99 €/mois (Essai Bêta)' : 'Subscribe to Tadarruj+ — €7.99/mo (Beta Trial)',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Tableau Comparatif : Gratuit vs Tadarruj+
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TadarrujColors.emeraldPrimary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr ? 'Comparatif : Gratuit vs Tadarruj+ (7,99 €/mois)' : 'Comparison: Free vs Tadarruj+ (€7.99/mo)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      isFr ? 'Fonctionnalité' : 'Feature',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        isFr ? 'Gratuit' : 'Free',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Center(
                      child: Text(
                        'Tadarruj+',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: TadarrujColors.goldAccent),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(r.$1, style: const TextStyle(fontSize: 12.5, height: 1.3)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: r.$2 is bool
                                ? Icon(
                                    (r.$2 == true) ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                                    size: 18,
                                    color: (r.$2 == true) ? const Color(0xFF28A745) : Colors.grey,
                                  )
                                : Text(
                                    r.$2.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: r.$3 is bool
                                ? Icon(
                                    (r.$3 == true) ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                                    size: 19,
                                    color: TadarrujColors.goldAccent,
                                  )
                                : Text(
                                    r.$3.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: TadarrujColors.emeraldPrimary,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Carte dédiée : Fonds Solidaire Sadaqah (Financer un étudiant)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TadarrujColors.goldAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TadarrujColors.goldAccent.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded, color: TadarrujColors.goldAccent, size: 25),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isFr ? 'Sadaqah • Financer un étudiant du Coran' : 'Sadaqah • Sponsor a Quran Student',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isFr
                    ? 'Une partie de chaque abonnement Tadarruj+ alimente le fonds solidaire. Si vous parrainez (7,99 €/mois ou 69,99 €/an), un accès complet Tadarruj+ sera offert soit à un élève de votre choix, soit à un autre étudiant dans le besoin.'
                    : 'A portion of every Tadarruj+ subscription supports our solidarity fund. If you sponsor (€7.99/mo or €69.99/yr), full Tadarruj+ access will be gifted either to a student of your choice or to another student in need.',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: TadarrujColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFr
                                ? '🤲 JazakAllahu Khayran ! Parrainage étudiant (7,99 €/mois) enregistré.'
                                : '🤲 JazakAllahu Khayran! Monthly student sponsorship (€7.99/mo) recorded.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite_rounded, size: 17, color: TadarrujColors.goldSoft),
                    label: Text(
                      isFr ? 'Parrainer 1 mois (7,99 €)' : 'Sponsor 1 month (€7.99)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TadarrujColors.emeraldPrimary,
                      side: const BorderSide(color: TadarrujColors.emeraldPrimary),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFr
                                ? '🤲 JazakAllahu Khayran ! Parrainage annuel (69,99 €/an) enregistré.'
                                : '🤲 JazakAllahu Khayran! Annual student sponsorship (€69.99/yr) recorded.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.school_rounded, size: 17),
                    label: Text(
                      isFr ? 'Parrainer 1 an (69,99 €)' : 'Sponsor 1 year (€69.99)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planChip(String title, String price, bool highlighted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? TadarrujColors.goldAccent.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? TadarrujColors.goldAccent : Colors.white.withValues(alpha: 0.25),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: TadarrujColors.goldSoft, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(price, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

}
