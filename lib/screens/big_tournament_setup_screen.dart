import 'package:flutter/material.dart';
import '../tournament_models.dart';
import '../saved_template.dart';
import '../services/template_service.dart';
import 'squad_entry.dart';
import 'tournament_home_screen.dart';

class _Preset {
  final int numGroups;
  final int advanceCount;
  final String description;
  const _Preset(this.numGroups, this.advanceCount, this.description);
}

// Enumerates valid group/advance combinations that produce 2, 4, or 8 knockout
// qualifiers — the only bracket sizes the app supports.
List<_Preset> _presetsFor(int teams) {
  final result = <_Preset>[];
  for (int g = 1; g <= teams ~/ 2; g++) {
    if (teams % g != 0) continue;
    final per = teams ~/ g;
    for (int a = 1; a < per; a++) {
      final total = g * a;
      if (![2, 4, 8].contains(total)) continue;
      final phase = total == 8
          ? 'Super Groups → Semis → Final'
          : total == 4
              ? 'Semi-Finals → Final'
              : 'Final';
      final label = g == 1
          ? '1 group of $per · top $a → $phase'
          : '$g groups of $per · top $a each → $phase';
      result.add(_Preset(g, a, label));
    }
  }
  return result;
}

/// Multi-step setup wizard for a large custom tournament (4–16+ teams).
/// Dynamically generates group/knockout presets based on the team count and
/// optionally pre-fills from a saved [templateName].
class BigTournamentSetupScreen extends StatefulWidget {
  final String? templateName;
  const BigTournamentSetupScreen({super.key, this.templateName});
  @override
  State<BigTournamentSetupScreen> createState() =>
      _BigTournamentSetupScreenState();
}

class _BigTournamentSetupScreenState extends State<BigTournamentSetupScreen> {
  int _step = 0;

  // Config
  int _numTeams = 8;
  _Preset? _preset;
  List<_Preset> _presets = [];
  MatchFormat _format = MatchFormat.t20;

  // Team data (built when team count is confirmed)
  List<TextEditingController> _nameCtrl = [];
  List<List<PlayerSetupData>> _squads = [];

  // Group assignment: index per team (0=GroupA, 1=GroupB, etc.)
  List<int> _groupOf = [];

  @override
  void initState() {
    super.initState();
    _rebuildTeams(_numTeams);
  }

  @override
  void dispose() {
    for (final c in _nameCtrl) {
      c.dispose();
    }
    for (final sq in _squads) {
      for (final p in sq) {
        p.dispose();
      }
    }
    super.dispose();
  }

  void _rebuildTeams(int n) {
    for (final c in _nameCtrl) {
      c.dispose();
    }
    for (final sq in _squads) {
      for (final p in sq) {
        p.dispose();
      }
    }
    _nameCtrl = List.generate(n, (i) => TextEditingController(text: 'Team ${i + 1}'));
    _squads = List.generate(
        n, (_) => List.generate(18, (j) => PlayerSetupData('Player ${j + 1}')));
    _presets = _presetsFor(n);
    _preset = null;
    _groupOf = List.generate(n, (i) => 0);
  }

  void _applyDefaultGroups() {
    if (_preset == null) return;
    final per = _numTeams ~/ _preset!.numGroups;
    _groupOf = List.generate(_numTeams, (i) => i ~/ per);
  }

  int get _totalSteps =>
      2 + _numTeams + (_preset != null && _preset!.numGroups > 1 ? 1 : 0);

  bool get _isSquadStep => _step >= 2 && _step <= 1 + _numTeams;

  int get _squadTeamIndex => _step - 2;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadTeam(int teamIdx) async {
    final team = await showTeamPickerSheet(context);
    if (team == null) return;
    applyTeamToSquad(
      team: team,
      squad: _squads[teamIdx],
      nameCtrl: _nameCtrl[teamIdx],
      setState: setState,
    );
  }

  void _nextStep() {
    // Validate current step
    if (_step == 0) {
      if (_preset == null) { _snack('Select a tournament format'); return; }
      _applyDefaultGroups();
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      // Validate team names
      final names = _nameCtrl.map((c) => c.text.trim()).toList();
      if (names.any((n) => n.isEmpty)) { _snack('Enter all team names'); return; }
      if (names.toSet().length != names.length) { _snack('Team names must be unique'); return; }
      setState(() => _step = 2);
      return;
    }

    if (_isSquadStep) {
      final i = _squadTeamIndex;
      final err = validateSquad(_squads[i], _nameCtrl[i].text.trim(), min: 18, max: 21);
      if (err != null) { _snack(err); return; }
      setState(() => _step++);
      return;
    }

    // Group assignment step or final
    _startTournament();
  }

  void _startTournament() {
    final overs = switch (_format) {
      MatchFormat.t10 => 10,
      MatchFormat.t20 => 20,
      MatchFormat.odi => 50,
      MatchFormat.hundred => 20,
      _ => 20,
    };
    final teams = List.generate(
      _numTeams,
      (i) => TournamentTeam(
        name: _nameCtrl[i].text.trim(),
        players: _squads[i].map((p) => p.toInfo()).toList(),
      ),
    );

    // Build group assignments
    List<List<String>>? assignments;
    if (_preset!.numGroups > 1) {
      assignments = List.generate(_preset!.numGroups, (_) => <String>[]);
      for (int i = 0; i < _numTeams; i++) {
        final g = _groupOf[i].clamp(0, _preset!.numGroups - 1);
        assignments[g].add(teams[i].name);
      }
      // Validate each group has at least 2 teams
      for (int g = 0; g < assignments.length; g++) {
        if (assignments[g].length < 2) {
          _snack('Group ${String.fromCharCode(65 + g)} needs at least 2 teams');
          return;
        }
      }
    }

    final state = BigTournamentState(
      teams: teams,
      overs: overs,
      format: _format,
      numPhase1Groups: _preset!.numGroups,
      phase1AdvanceCount: _preset!.advanceCount,
      groupAssignments: assignments,
    );

    final tName = widget.templateName ?? '$_numTeams-Team Tournament';
    final now = DateTime.now().millisecondsSinceEpoch;
    TemplateService.save(SavedTemplate(
      id: TemplateService.newId(),
      name: tName,
      type: 'tournament',
      teams: List.generate(_numTeams, (i) => TemplateTeam(
        name: teams[i].name,
        players: teams[i].players,
      )),
      format: _format,
      numGroups: _preset!.numGroups,
      advanceCount: _preset!.advanceCount,
      groupOf: List<int>.from(_groupOf),
      createdAt: now,
      updatedAt: now,
    ));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tournament'),
        builder: (_) => TournamentHomeScreen(
          tournament: BigTournamentHolder(state),
          customTitle: '$tName – Season 1',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Big Tournament Setup',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _totalSteps > 1 ? _step / (_totalSteps - 1) : 0,
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
      body: _buildCurrentStep(),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildCurrentStep() {
    if (_step == 0) return _buildConfigStep();
    if (_step == 1) return _buildNamesStep();
    if (_isSquadStep) return _buildSquadStep(_squadTeamIndex);
    return _buildGroupsStep();
  }

  // ── Step 0: Config ────────────────────────────────────────────────────────

  Widget _buildConfigStep() {
    final presets = _presets;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        _label('NUMBER OF TEAMS'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [4, 6, 8, 10, 12, 16, 20].map((n) {
            final sel = _numTeams == n;
            return GestureDetector(
              onTap: () => setState(() {
                _numTeams = n;
                _rebuildTeams(n);
              }),
              child: _chip('$n', sel, Theme.of(context).colorScheme.primary),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _label('TOURNAMENT FORMAT'),
        const SizedBox(height: 10),
        if (presets.isEmpty)
          Text('No valid formats for this team count.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))
        else
          ...presets.map((p) {
            final sel = _preset == p;
            return GestureDetector(
              onTap: () => setState(() => _preset = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.amber.shade800.withValues(alpha:0.25)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel ? Colors.amber : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
                ),
                child: Row(children: [
                  Icon(
                      sel ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: sel ? Colors.amber : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                      size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p.description,
                        style: TextStyle(
                            color: sel ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                ]),
              ),
            );
          }),
        const SizedBox(height: 24),
        _label('MATCH FORMAT'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            (MatchFormat.t10, 'T10', '10 ov'),
            (MatchFormat.t20, 'T20', '20 ov'),
            (MatchFormat.odi, 'ODI', '50 ov'),
            (MatchFormat.hundred, 'Hundred', '100 balls'),
          ].map((f) {
            final sel = _format == f.$1;
            return GestureDetector(
              onTap: () => setState(() => _format = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? Colors.amber.shade800.withValues(alpha:0.35) : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? Colors.amber : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
                ),
                child: Column(children: [
                  Text(f.$2, style: TextStyle(
                      color: sel ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
                  Text(f.$3, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 10)),
                ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── Step 1: Team Names ────────────────────────────────────────────────────

  Widget _buildNamesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        _label('TEAM NAMES'),
        const SizedBox(height: 12),
        ...List.generate(_numTeams, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _nameCtrl[i],
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  prefixIcon: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.amber.shade800,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface, fontSize: 11)),
                  ),
                  hintText: 'Team ${i + 1}',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.amber.shade800),
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Colors.amber, width: 2),
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            )),
      ]),
    );
  }

  // ── Steps 2..N+1: Squad entry ─────────────────────────────────────────────

  Widget _buildSquadStep(int teamIdx) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        color: Colors.amber.shade800.withValues(alpha: 0.25),
        child: Row(children: [
          Expanded(
            child: Text(
              '${_nameCtrl[teamIdx].text} — Squad Entry  (${teamIdx + 1}/$_numTeams)',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.file_download_outlined, size: 15),
            label: const Text('Load', style: TextStyle(fontSize: 12)),
            onPressed: () => _loadTeam(teamIdx),
          ),
        ]),
      ),
      Expanded(
        child: SquadEntryWidget(
            players: _squads[teamIdx],
            accentColor: Colors.amber.shade700,
            onAddPlayer: _squads[teamIdx].length < 21
                ? () => setState(() => _squads[teamIdx]
                    .add(PlayerSetupData('Player ${_squads[teamIdx].length + 1}')))
                : null,
            onRemovePlayer: _squads[teamIdx].length > 18
                ? (i) => setState(() {
                      _squads[teamIdx][i].dispose();
                      _squads[teamIdx].removeAt(i);
                    })
                : null),
      ),
    ]);
  }

  // ── Group assignment step ─────────────────────────────────────────────────

  Widget _buildGroupsStep() {
    final numGroups = _preset!.numGroups;
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        _label('GROUP ASSIGNMENT'),
        const SizedBox(height: 4),
        Text(
          'Assign each team to a group. Each group needs at least 2 teams.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12),
        ),
        const SizedBox(height: 16),
        ...List.generate(_numTeams, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(children: [
              Expanded(
                child: Text(_nameCtrl[i].text,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              Text('Group:',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
              const SizedBox(width: 10),
              Wrap(
                spacing: 6,
                children: List.generate(numGroups, (g) {
                  final sel = _groupOf[i] == g;
                  return GestureDetector(
                    onTap: () => setState(() => _groupOf[i] = g),
                    child: _chip(labels[g], sel, Colors.amber.shade800),
                  );
                }),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── nav bar ───────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    final isLast = _step == _totalSteps - 1;
    final isFirst = _step == 0;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(children: [
        if (!isFirst)
          OutlinedButton(
            onPressed: () => setState(() => _step--),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Back'),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade800,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(isLast ? 'Start Tournament' : 'Next'),
        ),
      ]),
    );
  }

  // ── util ──────────────────────────────────────────────────────────────────

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5));

  Widget _chip(String label, bool selected, Color color) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13)),
      );
}
