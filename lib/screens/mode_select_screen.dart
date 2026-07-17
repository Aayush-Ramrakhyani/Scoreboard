import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../saved_template.dart';
import '../services/firebase_service.dart';
import '../services/template_service.dart';
import 'history_screen.dart';
import 'watch_live_screen.dart';
import 'login_screen.dart';
import 'match_screen.dart';
import 'my_teams_screen.dart';
import 'saved_templates_screen.dart';
import 'tournament_home_screen.dart';
import 'setup_screen.dart';
import 'series_setup_screen.dart';
import 'multi_format_series_setup_screen.dart';
import 'tri_series_setup_screen.dart';
import 'big_tournament_setup_screen.dart';

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  bool _hasSavedMatch = false;
  bool _hasSavedTournament = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _logout() async {
    await FirebaseService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _checkSaved() async {
    final hasMatch = await AppDatabase.hasSavedMatch();
    var hasTournament = await AppDatabase.hasSavedTournament();
    if (!hasTournament) {
      final progress = await TemplateService.loadTournamentProgress();
      hasTournament = progress != null;
    }
    if (mounted) {
      setState(() {
        _hasSavedMatch = hasMatch;
        _hasSavedTournament = hasTournament;
      });
    }
  }

  Future<void> _resumeMatch() async {
    final ms = await AppDatabase.loadMatch();
    if (ms == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchScreen(state: ms, isResuming: true),
      ),
    );
    _checkSaved();
  }

  Future<void> _resumeTournament() async {
    var t = await AppDatabase.loadTournament();
    String? firestoreId;
    if (t == null) {
      final progress = await TemplateService.loadTournamentProgress();
      if (progress != null) {
        (t, firestoreId) = progress;
        await AppDatabase.saveTournament(t);
      }
    }
    if (t == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentHomeScreen(
          tournament: t!,
          firestoreId: firestoreId,
        ),
      ),
    );
    _checkSaved();
  }

  // ── Template launch flow ──────────────────────────────────────────────────

  Future<void> _launch(String type) async {
    final existing = await TemplateService.loadByType(type);
    if (!mounted) return;
    if (existing.isEmpty) {
      final name = await _askSetupName(type);
      if (!mounted) return;
      _openSetup(type, templateName: name);
    } else {
      _showNewOrLoad(type, existing);
    }
  }

  Future<String?> _askSetupName(String type) {
    final label = _typeLabel(type);
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1E),
        title: Text('Name your $label',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.greenAccent)),
          ),
          onSubmitted: (v) =>
              Navigator.pop(ctx, v.trim().isEmpty ? label : v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, label),
              child: const Text('Skip',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(ctx, v.isEmpty ? label : v);
            },
            child: const Text('Continue',
                style: TextStyle(
                    color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNewOrLoad(String type, List<SavedTemplate> existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2B1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => _NewOrLoadSheet(
        type: type,
        templates: existing,
        onNew: () {
          Navigator.pop(ctx);
          _openSetup(type, templateName: null);
        },
        onLoad: (t) async {
          Navigator.pop(ctx);
          await TemplateService.incrementSeason(t);
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/tournament'),
              builder: (_) => TournamentHomeScreen(
                tournament: t.buildTournament(),
                customTitle: '${t.name} – Season ${t.season}',
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSetup(String type, {String? templateName}) {
    switch (type) {
      case 'series':
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => SeriesSetupScreen(templateName: templateName)));
      case 'triseries':
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => TriSeriesSetupScreen(templateName: templateName)));
      case 'multiformat':
        Navigator.push(context, MaterialPageRoute(
            builder: (_) =>
                MultiFormatSeriesSetupScreen(templateName: templateName)));
      case 'tournament':
        Navigator.push(context, MaterialPageRoute(
            builder: (_) =>
                BigTournamentSetupScreen(templateName: templateName)));
    }
  }

  static String _typeLabel(String type) => switch (type) {
        'series' => 'Series',
        'triseries' => 'Tri-Series',
        'tournament' => 'Tournament',
        'multiformat' => 'Multi-Format Series',
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    final hasResume = _hasSavedMatch || _hasSavedTournament;
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Profile bar ────────────────────────────────────────
                  _buildProfileBar(),
                  const SizedBox(height: 24),
                  const Icon(Icons.sports_cricket,
                      color: Colors.greenAccent, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Cricket Scoreboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a match format to begin',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),

                  // ── Resume section ──────────────────────────────────────
                  if (hasResume) ...[
                    const SizedBox(height: 36),
                    const Row(children: [
                      Icon(Icons.history, color: Colors.amber, size: 14),
                      SizedBox(width: 6),
                      Text('RESUME',
                          style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                    ]),
                    const SizedBox(height: 10),
                    if (_hasSavedMatch)
                      _resumeCard(
                        context,
                        icon: Icons.sports_cricket,
                        title: 'Resume Match',
                        subtitle: 'Continue your in-progress game',
                        color: Colors.amber.shade700,
                        onTap: _resumeMatch,
                      ),
                    if (_hasSavedMatch && _hasSavedTournament)
                      const SizedBox(height: 10),
                    if (_hasSavedTournament)
                      _resumeCard(
                        context,
                        icon: Icons.emoji_events,
                        title: 'Resume Tournament',
                        subtitle: 'Continue your in-progress tournament',
                        color: Colors.deepPurple.shade400,
                        onTap: _resumeTournament,
                      ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white12),
                  ],

                  // ── New game section ────────────────────────────────────
                  const SizedBox(height: 28),
                  _modeCard(
                    context,
                    icon: Icons.sports_cricket,
                    title: 'Single Match',
                    subtitle: 'One-off game between two teams',
                    color: Colors.green.shade700,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SetupScreen())),
                  ),
                  const SizedBox(height: 14),
                  _modeCard(
                    context,
                    icon: Icons.replay,
                    title: 'Series',
                    subtitle: 'Multiple matches — winner by most wins',
                    color: Colors.teal.shade700,
                    onTap: () => _launch('series'),
                  ),
                  const SizedBox(height: 14),
                  _modeCard(
                    context,
                    icon: Icons.view_list_rounded,
                    title: 'Multi-Format Series',
                    subtitle:
                        'Mix T20 + ODI + Test · separate winner per format',
                    color: Colors.deepOrange.shade700,
                    onTap: () => _launch('multiformat'),
                  ),
                  const SizedBox(height: 14),
                  _modeCard(
                    context,
                    icon: Icons.group,
                    title: 'Tri-Series',
                    subtitle: '3 teams · 6 league matches · top 2 play Final',
                    color: Colors.indigo.shade600,
                    onTap: () => _launch('triseries'),
                  ),
                  const SizedBox(height: 14),
                  _modeCard(
                    context,
                    icon: Icons.emoji_events,
                    title: 'Big Tournament',
                    subtitle: 'Groups · Super Groups · Semis · Final',
                    color: Colors.amber.shade800,
                    onTap: () => _launch('tournament'),
                  ),
                  const SizedBox(height: 28),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 14),
                  _modeCard(
                    context,
                    icon: Icons.groups,
                    title: 'My Teams',
                    subtitle: 'Save & manage your squads for reuse',
                    color: Colors.purple.shade400,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const MyTeamsScreen())),
                  ),
                  const SizedBox(height: 14),
                  _modeCard(
                    context,
                    icon: Icons.bookmark_outlined,
                    title: 'My Setups',
                    subtitle: 'Saved tournament & series templates · replay seasons',
                    color: Colors.deepPurple.shade400,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const SavedTemplatesScreen())),
                  ),
                  const SizedBox(height: 14),
                  _modeCard(
                    context,
                    icon: Icons.history,
                    title: 'History',
                    subtitle: 'View all past matches & tournaments',
                    color: Colors.blueGrey.shade400,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const HistoryScreen())),
                  ),
                  const SizedBox(height: 14),
                  _modeCard(
                    context,
                    icon: Icons.wifi_tethering,
                    title: 'Watch Live',
                    subtitle: 'View a live match or tournament — enter the code',
                    color: Colors.teal.shade300,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const WatchLiveScreen())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBar() {
    final user = FirebaseAuth.instance.currentUser;
    final label = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? 'Guest');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.green.shade700,
          child: Text(
            label.isNotEmpty ? label[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
          tooltip: 'Sign out',
          onPressed: _logout,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _resumeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha:0.7), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
          ),
          Icon(Icons.play_circle, color: color, size: 28),
        ]),
      ),
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha:0.5)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13)),
                ]),
          ),
          Icon(Icons.chevron_right, color: color.withValues(alpha:0.7)),
        ]),
      ),
    );
  }
}

// ── Bottom sheet for New vs Load ─────────────────────────────────────────────

class _NewOrLoadSheet extends StatelessWidget {
  final String type;
  final List<SavedTemplate> templates;
  final VoidCallback onNew;
  final Future<void> Function(SavedTemplate) onLoad;

  const _NewOrLoadSheet({
    required this.type,
    required this.templates,
    required this.onNew,
    required this.onLoad,
  });

  Color get _color => switch (type) {
        'series' => Colors.teal,
        'triseries' => Colors.indigo,
        'tournament' => Colors.amber,
        'multiformat' => Colors.deepOrange,
        _ => Colors.greenAccent,
      };

  String get _label => switch (type) {
        'series' => 'Series',
        'triseries' => 'Tri-Series',
        'tournament' => 'Tournament',
        'multiformat' => 'Multi-Format Series',
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color;
    final label = _label;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onNew,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.add_circle_outline, color: c, size: 20),
                  const SizedBox(width: 10),
                  Text('Start New $label',
                      style: TextStyle(
                          color: c,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Or continue from a saved setup:',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 10),
            ...templates.take(6).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => onLoad(t),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  t.type == 'multiformat'
                                      ? t.segments.map((s) => s.label).join(' + ')
                                      : '${t.teamsSummary} · ${t.formatLabel}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Season ${t.season + 1}',
                            style: TextStyle(
                                color: c,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ]),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
