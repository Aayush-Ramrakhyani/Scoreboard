import 'package:flutter/material.dart';
import '../tournament_models.dart';
import '../database/app_database.dart';
import '../saved_template.dart';
import '../services/template_service.dart';
import 'squad_entry.dart';
import 'tournament_home_screen.dart';

class SeriesSetupScreen extends StatefulWidget {
  final String? templateName;
  const SeriesSetupScreen({super.key, this.templateName});
  @override
  State<SeriesSetupScreen> createState() => _SeriesSetupScreenState();
}

class _SeriesSetupScreenState extends State<SeriesSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _t1Ctrl = TextEditingController(text: 'Team A');
  final _t2Ctrl = TextEditingController(text: 'Team B');
  MatchFormat _format = MatchFormat.t20;
  int _days = 5;
  int _matchCount = 3;

  late final List<PlayerSetupData> _squad1;
  late final List<PlayerSetupData> _squad2;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _squad1 = List.generate(18, (i) => PlayerSetupData('Player ${i + 1}'));
    _squad2 = List.generate(18, (i) => PlayerSetupData('Player ${i + 1}'));
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final p in _squad1) { p.dispose(); }
    for (final p in _squad2) { p.dispose(); }
    super.dispose();
  }

  void _start() {
    final t1 = _t1Ctrl.text.trim();
    final t2 = _t2Ctrl.text.trim();
    if (t1.isEmpty || t2.isEmpty) { _snack('Enter both team names'); return; }
    final e1 = validateSquad(_squad1, t1, min: 18, max: 21);
    if (e1 != null) { _snack(e1); return; }
    final e2 = validateSquad(_squad2, t2, min: 18, max: 21);
    if (e2 != null) { _snack(e2); return; }

    final overs = switch (_format) {
      MatchFormat.t10 => 10,
      MatchFormat.t20 => 20,
      MatchFormat.odi => 50,
      MatchFormat.test => _days * 90,
      _ => 20,
    };

    final p1 = _squad1.map((p) => p.toInfo()).toList();
    final p2 = _squad2.map((p) => p.toInfo()).toList();
    final state = SeriesState(
      teams: [
        TournamentTeam(name: t1, players: p1),
        TournamentTeam(name: t2, players: p2),
      ],
      overs: overs,
      format: _format,
      days: _days,
      totalMatches: _matchCount,
    );

    final tName = widget.templateName ?? '$t1 vs $t2';
    final now = DateTime.now().millisecondsSinceEpoch;
    TemplateService.save(SavedTemplate(
      id: TemplateService.newId(),
      name: tName,
      type: 'series',
      teams: [TemplateTeam(name: t1, players: p1), TemplateTeam(name: t2, players: p2)],
      format: _format,
      numMatches: _matchCount,
      days: _days,
      createdAt: now,
      updatedAt: now,
    ));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tournament'),
        builder: (_) => TournamentHomeScreen(
          tournament: SeriesHolder(state),
          customTitle: '$tName – Season 1',
        ),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadTeam(
      BuildContext ctx, TextEditingController nameCtrl, List<PlayerSetupData> squad) async {
    final team = await showTeamPickerSheet(ctx);
    if (team == null) return;
    applyTeamToSquad(team: team, squad: squad, nameCtrl: nameCtrl, setState: setState);
  }

  Future<SeriesState?> _loadSavedSeries() async {
    if (await AppDatabase.savedTournamentType() != 'series') return null;
    final t = await AppDatabase.loadTournament();
    return t is SeriesHolder ? t.state : null;
  }

  Widget _buildContinueTab() => FutureBuilder<SeriesState?>(
        future: _loadSavedSeries(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
          }
          final state = snap.data;
          if (state == null) {
            return _continueEmpty('No saved series found.', 'Start New Series', () => _tab.animateTo(1));
          }
          final played = state.matches.where((m) => m.result != null).length;
          final t1 = state.teams[0].name;
          final t2 = state.teams[1].name;
          return _continueSaved(
            title: '$t1 vs $t2',
            subtitle: '$played / ${state.totalMatches} matches played · ${state.seriesResult.isEmpty ? "In progress" : state.seriesResult}',
            format: '${state.totalMatches}-match ${state.format.name.toUpperCase()}',
            onResume: () => Navigator.pushReplacement(ctx,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/tournament'),
                builder: (_) => TournamentHomeScreen(tournament: SeriesHolder(state)),
              )),
            onNew: () => _tab.animateTo(1),
          );
        },
      );

  Widget _continueEmpty(String msg, String btnLabel, VoidCallback onTap) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.sports_cricket_outlined, color: Colors.white12, size: 64),
            const SizedBox(height: 16),
            Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: Text(btnLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      );

  Widget _continueSaved({
    required String title,
    required String subtitle,
    required String format,
    required VoidCallback onResume,
    required VoidCallback onNew,
  }) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2B1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade700.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(format, style: TextStyle(color: Colors.tealAccent.shade100, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                const Icon(Icons.fiber_manual_record, color: Colors.amber, size: 10),
                const SizedBox(width: 4),
                const Text('In Progress', style: TextStyle(color: Colors.amber, fontSize: 11)),
              ]),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Resume', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Start a new series instead'),
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Series Setup',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.greenAccent,
          tabs: [
            const Tab(text: 'Continue'),
            const Tab(text: 'Series Info'),
            Tab(text: _t1Ctrl.text.isEmpty ? 'Team 1' : _t1Ctrl.text),
            Tab(text: _t2Ctrl.text.isEmpty ? 'Team 2' : _t2Ctrl.text),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildContinueTab(),
          _buildInfo(),
          Column(children: [
            _teamHeader(_t1Ctrl, Colors.green.shade700, _squad1),
            Expanded(
                child: SquadEntryWidget(
                    players: _squad1,
                    accentColor: Colors.green.shade700,
                    onAddPlayer: _squad1.length < 21
                        ? () => setState(() => _squad1
                            .add(PlayerSetupData('Player ${_squad1.length + 1}')))
                        : null,
                    onRemovePlayer: _squad1.length > 18
                        ? (i) => setState(() {
                              _squad1[i].dispose();
                              _squad1.removeAt(i);
                            })
                        : null)),
          ]),
          Column(children: [
            _teamHeader(_t2Ctrl, Colors.blue.shade700, _squad2),
            Expanded(
                child: SquadEntryWidget(
                    players: _squad2,
                    accentColor: Colors.blue.shade700,
                    onAddPlayer: _squad2.length < 21
                        ? () => setState(() => _squad2
                            .add(PlayerSetupData('Player ${_squad2.length + 1}')))
                        : null,
                    onRemovePlayer: _squad2.length > 18
                        ? (i) => setState(() {
                              _squad2[i].dispose();
                              _squad2.removeAt(i);
                            })
                        : null)),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        _field(_t1Ctrl, 'Team 1 Name', Icons.groups),
        const SizedBox(height: 14),
        _field(_t2Ctrl, 'Team 2 Name', Icons.groups_2),
        const SizedBox(height: 14),
        _formatPicker(),
        const SizedBox(height: 24),
        const Text('Number of Matches',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [1, 2, 3, 5, 7].map((n) {
            final sel = _matchCount == n;
            return GestureDetector(
              onTap: () => setState(() => _matchCount = n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? Colors.teal.shade700 : const Color(0xFF0D2B1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel ? Colors.tealAccent : Colors.white24),
                ),
                child: Text('$n ${n == 1 ? "Match" : "Matches"}',
                    style: TextStyle(
                        color: sel ? Colors.white : Colors.white60,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'All $_matchCount matches will be played. Winner = most wins.',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _start,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Start Series'),
        ),
      ]),
    );
  }

  Widget _formatPicker() {
    const formats = [
      (MatchFormat.t10, 'T10', '10 overs'),
      (MatchFormat.t20, 'T20', '20 overs'),
      (MatchFormat.odi, 'ODI', '50 overs'),
      (MatchFormat.test, 'Test', '2 innings each'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MATCH FORMAT',
            style: TextStyle(color: Colors.white54, fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: formats.map((f) {
            final sel = _format == f.$1;
            return GestureDetector(
              onTap: () => setState(() => _format = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? Colors.teal.shade700.withValues(alpha:0.45) : const Color(0xFF0D2B1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? Colors.tealAccent : Colors.white24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.$2, style: TextStyle(
                      color: sel ? Colors.white : Colors.white70,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
                  Text(f.$3, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
            );
          }).toList(),
        ),
        if (_format == MatchFormat.test) ...[
          const SizedBox(height: 14),
          const Text('NUMBER OF DAYS',
              style: TextStyle(color: Colors.white54, fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(children: [3, 4, 5].map((d) {
            final sel = _days == d;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _days = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? Colors.teal.shade700 : const Color(0xFF0D2B1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? Colors.tealAccent : Colors.white24),
                  ),
                  child: Text('$d days',
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white60,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                ),
              ),
            );
          }).toList()),
        ],
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool numeric = false}) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.teal.shade700),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
            borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: const Color(0xFF0D2B1E),
      ),
    );
  }

  Widget _teamHeader(TextEditingController ctrl, Color color, List<PlayerSetupData> squad) =>
      ValueListenableBuilder(
        valueListenable: ctrl,
        builder: (ctx, __, ___) => Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          color: color.withValues(alpha: 0.3),
          child: Row(children: [
            Expanded(
              child: Text(
                ctrl.text.isEmpty ? 'Team' : ctrl.text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.file_download_outlined, size: 15),
              label: const Text('Load', style: TextStyle(fontSize: 12)),
              onPressed: () => _loadTeam(ctx, ctrl, squad),
            ),
          ]),
        ),
      );
}
