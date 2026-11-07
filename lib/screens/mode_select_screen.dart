import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../main.dart';
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
import 'international_cup_setup_screen.dart';

/// Home dashboard after login. Lists all scoring modes (quick match, series,
/// tournament, international cup) and provides access to history, my teams,
/// saved templates, and the live-watch feature.
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
    try {
      await FirebaseService.signOut();
    } catch (_) {}
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
          isResume: true,
        ),
      ),
    );
    _checkSaved();
  }

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
    final cs = Theme.of(context).colorScheme;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Name your $label',
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.38)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.outline)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.onSurface, width: 1.5)),
            filled: false,
          ),
          onSubmitted: (v) =>
              Navigator.pop(ctx, v.trim().isEmpty ? label : v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, label),
              child: Text('Skip',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.45)))),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(ctx, v.isEmpty ? label : v);
            },
            child: Text('Continue',
                style: TextStyle(
                    color: cs.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNewOrLoad(String type, List<SavedTemplate> existing) {
    showModalBottomSheet(
      context: context,
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
    final cs = Theme.of(context).colorScheme;
    final hasResume = _hasSavedMatch || _hasSavedTournament;

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProfileBar(cs),
                  const SizedBox(height: 24),
                  Icon(Icons.sports_cricket, color: cs.onSurface, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Cricket Scoreboard',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a match format to begin',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontSize: 15),
                  ),

                  if (hasResume) ...[
                    const SizedBox(height: 36),
                    Row(children: [
                      Icon(Icons.history,
                          color: cs.onSurface.withValues(alpha: 0.7), size: 14),
                      const SizedBox(width: 6),
                      Text('RESUME',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                    ]),
                    const SizedBox(height: 10),
                    if (_hasSavedMatch)
                      _resumeCard(
                        cs: cs,
                        icon: Icons.sports_cricket,
                        title: 'Resume Match',
                        subtitle: 'Continue your in-progress game',
                        onTap: _resumeMatch,
                      ),
                    if (_hasSavedMatch && _hasSavedTournament)
                      const SizedBox(height: 10),
                    if (_hasSavedTournament)
                      _resumeCard(
                        cs: cs,
                        icon: Icons.emoji_events,
                        title: 'Resume Tournament',
                        subtitle: 'Continue your in-progress tournament',
                        onTap: _resumeTournament,
                      ),
                    const SizedBox(height: 24),
                    Divider(color: cs.outlineVariant),
                  ],

                  const SizedBox(height: 28),
                  _modeCard(cs: cs, icon: Icons.sports_cricket,
                      title: 'Single Match',
                      subtitle: 'One-off game between two teams',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SetupScreen()))),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.replay,
                      title: 'Series',
                      subtitle: 'Multiple matches — winner by most wins',
                      onTap: () => _launch('series')),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.view_list_rounded,
                      title: 'Multi-Format Series',
                      subtitle: 'Mix T20 + ODI + Test · separate winner per format',
                      onTap: () => _launch('multiformat')),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.group,
                      title: 'Tri-Series',
                      subtitle: '3 teams · 6 league matches · top 2 play Final',
                      onTap: () => _launch('triseries')),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.emoji_events,
                      title: 'Big Tournament',
                      subtitle: 'Groups · Super Groups · Semis · Final',
                      onTap: () => _launch('tournament')),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.public,
                      title: 'International Cup',
                      subtitle: 'ODI WC · T20 WC · Asia Cup · Champions Trophy',
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const InternationalCupSetupScreen()))),
                  const SizedBox(height: 28),
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.groups,
                      title: 'My Teams',
                      subtitle: 'Save & manage your squads for reuse',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MyTeamsScreen()))),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.bookmark_outlined,
                      title: 'My Setups',
                      subtitle: 'Saved tournament & series templates · replay seasons',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SavedTemplatesScreen()))),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.history,
                      title: 'History',
                      subtitle: 'View all past matches & tournaments',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const HistoryScreen()))),
                  const SizedBox(height: 14),
                  _modeCard(cs: cs, icon: Icons.wifi_tethering,
                      title: 'Watch Live',
                      subtitle: 'View a live match or tournament — enter the code',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const WatchLiveScreen()))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBar(ColorScheme cs) {
    final user = FirebaseAuth.instance.currentUser;
    final label = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? 'Guest');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: cs.onSurface.withValues(alpha: 0.15),
          child: Text(
            label.isNotEmpty ? label[0].toUpperCase() : '?',
            style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.8), fontSize: 13)),
        ),
        // Theme toggle — GestureDetector captures the exact tap position
        // so the circular reveal expands from the button center.
        ValueListenableBuilder<bool>(
          valueListenable: themeNotifier,
          builder: (_, isLight, __) => GestureDetector(
            onTapDown: (d) => toggleTheme(origin: d.globalPosition),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                isLight ? Icons.dark_mode : Icons.light_mode,
                color: cs.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.logout,
              color: cs.onSurface.withValues(alpha: 0.45), size: 20),
          tooltip: 'Sign out',
          onPressed: _logout,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _resumeCard({
    required ColorScheme cs,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.25),
              width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, color: cs.onSurface.withValues(alpha: 0.8), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 12)),
                ]),
          ),
          Icon(Icons.play_circle,
              color: cs.onSurface.withValues(alpha: 0.7), size: 28),
        ]),
      ),
    );
  }

  Widget _modeCard({
    required ColorScheme cs,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cs.onSurface, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 13)),
                ]),
          ),
          Icon(Icons.chevron_right,
              color: cs.onSurface.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}

// ── Bottom sheet for New vs Load ──────────────────────────────────────────────

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

  String get _label => switch (type) {
        'series' => 'Series',
        'triseries' => 'Tri-Series',
        'tournament' => 'Tournament',
        'multiformat' => 'Multi-Format Series',
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onNew,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline),
                ),
                child: Row(children: [
                  Icon(Icons.add_circle_outline, color: cs.onSurface, size: 20),
                  const SizedBox(width: 10),
                  Text('Start New $label',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Text('Or continue from a saved setup:',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontSize: 12)),
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
                        color: cs.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name,
                                    style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  t.type == 'multiformat'
                                      ? t.segments
                                          .map((s) => s.label)
                                          .join(' + ')
                                      : '${t.teamsSummary} · ${t.formatLabel}',
                                  style: TextStyle(
                                      color: cs.onSurface
                                          .withValues(alpha: 0.45),
                                      fontSize: 11),
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
                            color: cs.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Season ${t.season + 1}',
                            style: TextStyle(
                                color: cs.onSurface,
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
