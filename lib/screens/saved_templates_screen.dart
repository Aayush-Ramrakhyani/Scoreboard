import 'package:flutter/material.dart';
import '../models.dart';
import '../saved_template.dart';
import '../services/template_service.dart';
import 'tournament_home_screen.dart';

/// Lists saved match/series templates stored via [TemplateService]. Templates
/// can be loaded to skip squad re-entry when replaying a familiar fixture.
class SavedTemplatesScreen extends StatefulWidget {
  const SavedTemplatesScreen({super.key});
  @override
  State<SavedTemplatesScreen> createState() => _SavedTemplatesScreenState();
}

class _SavedTemplatesScreenState extends State<SavedTemplatesScreen> {
  List<SavedTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await TemplateService.loadAll();
    if (mounted) setState(() { _templates = t; _loading = false; });
  }

  // ── Start a new season ────────────────────────────────────────────────────

  Future<void> _startSeason(SavedTemplate t) async {
    await TemplateService.incrementSeason(t);
    if (!mounted) return;
    final title = '${t.name} – Season ${t.season}';
    final tournament = t.buildTournament();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TournamentHomeScreen(tournament: tournament, customTitle: title),
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _delete(SavedTemplate t) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text('Delete Setup',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            content: Text('Delete "${t.name}"?\nThis cannot be undone.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await TemplateService.delete(t.id);
    if (mounted) setState(() => _templates.remove(t));
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _edit(SavedTemplate t) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _TemplateEditScreen(template: t)),
    );
    if (result == true) _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Setups',
            style:
                TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : _templates.isEmpty
              ? _empty()
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _card(_templates[i]),
                ),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bookmark_border, color: Theme.of(context).colorScheme.outlineVariant, size: 64),
          const SizedBox(height: 16),
          Text('No saved setups yet',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 16)),
          const SizedBox(height: 6),
          Text(
              'Save a series or tournament setup from the setup screens',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), fontSize: 13)),
        ]),
      );

  Widget _card(SavedTemplate t) {
    final color = _typeColor(t.type);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(
                        t.season > 1
                            ? 'Last played: Season ${t.season}'
                            : 'Not played yet',
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11),
                      ),
                    ]),
              ),
              _badge(t.typeLabel, color),
              const SizedBox(width: 6),
              if (t.type != 'multiformat') _badge(t.formatLabel, Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
            ]),
          ),
          // ── Teams ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: t.teams
                  .map((tm) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tm.name,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          // ── Segments (multiformat) ────────────────────────────────────────
          if (t.type == 'multiformat' && t.segments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Text(
                t.segments.map((s) => s.label).join(' + '),
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11),
              ),
            ),
          // ── Actions ──────────────────────────────────────────────────────
          Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              Expanded(
                child: _actionBtn(
                  icon: Icons.play_arrow_rounded,
                  label: t.season == 0
                      ? 'Start'
                      : 'Start Season ${t.season + 1}',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => _startSeason(t),
                ),
              ),
              const SizedBox(width: 6),
              _iconBtn(Icons.edit_outlined, Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), () => _edit(t)),
              _iconBtn(Icons.delete_outline, Colors.redAccent.withValues(alpha: 0.7),
                  () => _delete(t)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _actionBtn(
          {required IconData icon,
          required String label,
          required Color color,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      );

  Color _typeColor(String type) => switch (type) {
        'series' => Colors.teal,
        'triseries' => Colors.indigo.shade400,
        'tournament' => Colors.amber.shade600,
        'multiformat' => Colors.deepOrange,
        _ => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
      };
}

// ── Template edit screen ──────────────────────────────────────────────────────

class _TemplateEditScreen extends StatefulWidget {
  final SavedTemplate template;
  const _TemplateEditScreen({required this.template});
  @override
  State<_TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<_TemplateEditScreen> {
  late final TextEditingController _nameCtrl;
  late int _numMatches;
  late int _days;
  late List<_EditTeam> _teams;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameCtrl = TextEditingController(text: t.name);
    _numMatches = t.numMatches;
    _days = t.days;
    _teams = t.teams
        .map((tt) => _EditTeam(
              nameCtrl: TextEditingController(text: tt.name),
              players: List<PlayerInfo>.from(tt.players),
            ))
        .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final t in _teams) {
      t.nameCtrl.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  bool _validate() {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Enter a setup name');
      return false;
    }
    for (final t in _teams) {
      if (t.nameCtrl.text.trim().isEmpty) {
        _snack('Enter all team names');
        return false;
      }
      if (t.players.isEmpty) {
        _snack('Each team needs at least 1 player');
        return false;
      }
    }
    final names = _teams.map((t) => t.nameCtrl.text.trim()).toList();
    if (names.toSet().length != names.length) {
      _snack('Team names must be unique');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    final t = widget.template;
    t.name = _nameCtrl.text.trim();
    t.numMatches = _numMatches;
    t.days = _days;
    t.teams = _teams
        .map((et) => TemplateTeam(
              name: et.nameCtrl.text.trim(),
              players: et.players,
            ))
        .toList();
    // Keep groupOf in sync if teams were added/removed
    if (t.type == 'tournament' && t.groupOf.length != t.teams.length) {
      t.groupOf = List.generate(t.teams.length, (i) => i % t.numGroups);
    }
    await TemplateService.save(t);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  Future<void> _addTeam() async {
    if (widget.template.type == 'series' ||
        widget.template.type == 'multiformat') {
      _snack('2-team formats cannot add teams');
      return;
    }
    final ctrl = TextEditingController(text: 'Team ${_teams.length + 1}');
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text('Add Team',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            content: TextField(
              controller: ctrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Team name',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Add',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary))),
            ],
          ),
        ) ??
        false;
    ctrl.dispose();
    if (!ok) return;
    setState(() => _teams.add(_EditTeam(
          nameCtrl: TextEditingController(text: ctrl.text.trim()),
          players: List.generate(
              18,
              (i) => PlayerInfo(
                  name: 'Player ${i + 1}',
                  role: PlayerRole.batter)),
        )));
  }

  void _removeTeam(int idx) {
    if (_teams.length <= 2) {
      _snack('Need at least 2 teams');
      return;
    }
    setState(() {
      _teams[idx].nameCtrl.dispose();
      _teams.removeAt(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Setup',
            style:
                TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          if (_saving)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Save',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Setup name ──────────────────────────────────────────────────
          _section('Setup Name'),
          _field(_nameCtrl, 'Name (e.g. IPL, Asia Cup …)', Icons.label_outline),
          const SizedBox(height: 20),

          // ── Series options ───────────────────────────────────────────────
          if (t.type == 'series') ...[
            _section('Number of Matches'),
            Wrap(
              spacing: 8,
              children: [3, 5, 7].map((n) {
                final sel = _numMatches == n;
                return ChoiceChip(
                  label: Text('$n Matches'),
                  selected: sel,
                  onSelected: (_) => setState(() => _numMatches = n),
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  labelStyle: TextStyle(
                      color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // ── Teams ────────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _section('Teams')),
            if (t.type == 'triseries' || t.type == 'tournament')
              TextButton.icon(
                onPressed: _addTeam,
                icon: Icon(Icons.add,
                    color: Theme.of(context).colorScheme.primary, size: 16),
                label: Text('Add',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
              ),
          ]),
          ...List.generate(_teams.length, (i) => _teamTile(i)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.3)),
      );

  Widget _field(TextEditingController ctrl, String hint, IconData icon) =>
      TextField(
        controller: ctrl,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 18),
          filled: true,
          fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _teamTile(int idx) {
    final et = _teams[idx];
    final canRemove = _teams.length > 2 &&
        widget.template.type != 'series' &&
        widget.template.type != 'multiformat';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
            child: Row(children: [
              Icon(Icons.groups, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: et.nameCtrl,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Team name',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.redAccent, size: 18),
                  onPressed: () => _removeTeam(idx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(children: [
              Text('${et.players.length} players',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _editSquad(idx),
                child: Text('Edit Squad',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).colorScheme.primary)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _editSquad(int teamIdx) async {
    final result = await Navigator.push<List<PlayerInfo>>(
      context,
      MaterialPageRoute(
        builder: (_) => _SquadEditScreen(
          teamName: _teams[teamIdx].nameCtrl.text.trim(),
          players: List<PlayerInfo>.from(_teams[teamIdx].players),
        ),
      ),
    );
    if (result != null) {
      setState(() => _teams[teamIdx].players = result);
    }
  }
}

class _EditTeam {
  TextEditingController nameCtrl;
  List<PlayerInfo> players;
  _EditTeam({required this.nameCtrl, required this.players});
}

// ── Squad edit screen ─────────────────────────────────────────────────────────

class _SquadEditScreen extends StatefulWidget {
  final String teamName;
  final List<PlayerInfo> players;
  const _SquadEditScreen({required this.teamName, required this.players});
  @override
  State<_SquadEditScreen> createState() => _SquadEditScreenState();
}

class _SquadEditScreenState extends State<_SquadEditScreen> {
  late List<_EditPlayer> _players;

  static const _minPlayers = 11;
  static const _maxPlayers = 21;

  @override
  void initState() {
    super.initState();
    _players = widget.players
        .map((p) => _EditPlayer(
              nameCtrl: TextEditingController(text: p.name),
              role: p.role,
              bowlerType: p.bowlerType,
              isWicketKeeper: p.isWicketKeeper,
              isCaptain: p.isCaptain,
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final p in _players) {
      p.nameCtrl.dispose();
    }
    super.dispose();
  }

  List<PlayerInfo> _buildResult() => _players
      .map((p) => PlayerInfo(
            name: p.nameCtrl.text.trim().isEmpty
                ? 'Player ${_players.indexOf(p) + 1}'
                : p.nameCtrl.text.trim(),
            role: p.role,
            bowlerType: p.bowlerType,
            isWicketKeeper: p.isWicketKeeper,
            isCaptain: p.isCaptain,
          ))
      .toList();

  void _addPlayer() {
    if (_players.length >= _maxPlayers) return;
    setState(() => _players.add(_EditPlayer(
          nameCtrl: TextEditingController(
              text: 'Player ${_players.length + 1}'),
          role: PlayerRole.batter,
        )));
  }

  void _removePlayer(int idx) {
    if (_players.length <= _minPlayers) return;
    setState(() {
      _players[idx].nameCtrl.dispose();
      _players.removeAt(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _buildResult()),
            child: Text('Done',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      floatingActionButton: _players.length < _maxPlayers
          ? FloatingActionButton.small(
              onPressed: _addPlayer,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurface),
            )
          : null,
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _players.length,
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            final p = _players.removeAt(oldIndex);
            _players.insert(newIndex, p);
          });
        },
        itemBuilder: (_, idx) {
          final p = _players[idx];
          return _playerTile(key: ValueKey(idx), idx: idx, p: p);
        },
      ),
    );
  }

  Widget _playerTile(
      {required Key key, required int idx, required _EditPlayer p}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: p.nameCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Player ${idx + 1}',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_players.length > _minPlayers)
              GestureDetector(
                onTap: () => _removePlayer(idx),
                child: Icon(Icons.close,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), size: 16),
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const SizedBox(width: 26),
            _roleChip(p, PlayerRole.batter, 'Bat'),
            const SizedBox(width: 5),
            _roleChip(p, PlayerRole.bowler, 'Bowl'),
            const SizedBox(width: 5),
            _roleChip(p, PlayerRole.allRounder, 'AR'),
            const Spacer(),
            _toggle('WK', p.isWicketKeeper,
                () => setState(() => p.isWicketKeeper = !p.isWicketKeeper)),
            const SizedBox(width: 6),
            _toggle('C', p.isCaptain,
                () => setState(() => p.isCaptain = !p.isCaptain)),
          ]),
          if (p.role == PlayerRole.bowler || p.role == PlayerRole.allRounder)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 26),
              child: Row(children: [
                _bowlerChip(p, BowlerType.fast, 'Fast'),
                const SizedBox(width: 5),
                _bowlerChip(p, BowlerType.spin, 'Spin'),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _roleChip(_EditPlayer p, PlayerRole role, String label) {
    final sel = p.role == role;
    return GestureDetector(
      onTap: () => setState(() {
        p.role = role;
        if (role == PlayerRole.batter) p.bowlerType = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: sel
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: sel
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 11)),
      ),
    );
  }

  Widget _bowlerChip(_EditPlayer p, BowlerType bt, String label) {
    final sel = p.bowlerType == bt;
    return GestureDetector(
      onTap: () => setState(() => p.bowlerType = bt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: sel
              ? Colors.deepOrange.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: sel
                  ? Colors.deepOrange.withValues(alpha: 0.5)
                  : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.deepOrange.shade200 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 10)),
      ),
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? Colors.amber.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
                color: active
                    ? Colors.amber.withValues(alpha: 0.5)
                    : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.amber : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 11)),
        ),
      );
}

class _EditPlayer {
  TextEditingController nameCtrl;
  PlayerRole role;
  BowlerType? bowlerType;
  bool isWicketKeeper;
  bool isCaptain;

  _EditPlayer({
    required this.nameCtrl,
    required this.role,
    this.bowlerType,
    this.isWicketKeeper = false,
    this.isCaptain = false,
  });
}
