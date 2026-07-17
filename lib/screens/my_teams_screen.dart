import 'package:flutter/material.dart';
import '../models.dart';
import '../services/firebase_service.dart';
import 'squad_entry.dart';

// ── My Teams list ─────────────────────────────────────────────────────────────

class MyTeamsScreen extends StatelessWidget {
  const MyTeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('My Teams',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.greenAccent),
            tooltip: 'New team',
            onPressed: () => _openEditor(context, null),
          ),
        ],
      ),
      body: StreamBuilder<List<SavedTeam>>(
        stream: FirebaseService.teamsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Colors.greenAccent));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style:
                        const TextStyle(color: Colors.redAccent)));
          }
          final teams = snap.data ?? [];
          if (teams.isEmpty) return _emptyState(context);
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: teams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _teamCard(context, teams[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text('New Team'),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.group_add, color: Colors.white12, size: 64),
          const SizedBox(height: 18),
          const Text('No saved teams yet',
              style: TextStyle(color: Colors.white54, fontSize: 17)),
          const SizedBox(height: 8),
          const Text('Create a team once, load it in any tournament',
              style: TextStyle(color: Colors.white30, fontSize: 13)),
        ]),
      );

  Widget _teamCard(BuildContext context, SavedTeam team) {
    final batters = team.players
        .where((p) => p.role == PlayerRole.batter && !p.isWicketKeeper)
        .length;
    final wks = team.players.where((p) => p.isWicketKeeper).length;
    final arounders =
        team.players.where((p) => p.role == PlayerRole.allRounder).length;
    final bowlers = team.players
        .where((p) => p.role == PlayerRole.bowler && !p.isWicketKeeper)
        .length;
    final captain =
        team.players.where((p) => p.isCaptain).firstOrNull?.name ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    if (captain.isNotEmpty)
                      Text('Captain: $captain',
                          style: const TextStyle(
                              color: Colors.amber, fontSize: 11)),
                  ]),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.greenAccent, size: 20),
              onPressed: () => _openEditor(context, team),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              onPressed: () => _confirmDelete(context, team),
            ),
          ]),
        ),
        // Role chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            _chip('${team.players.length} players', Colors.white24),
            if (batters > 0) _chip('$batters Bat', const Color(0xFF388E3C)),
            if (wks > 0) _chip('$wks WK', const Color(0xFF1565C0)),
            if (arounders > 0)
              _chip('$arounders AR', const Color(0xFF6A1B9A)),
            if (bowlers > 0) _chip('$bowlers Bowl', const Color(0xFFBF360C)),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      );

  void _openEditor(BuildContext context, SavedTeam? team) =>
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TeamEditorScreen(existing: team),
            fullscreenDialog: true),
      );

  Future<void> _confirmDelete(
      BuildContext context, SavedTeam team) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0D2B1E),
            title: const Text('Delete Team',
                style: TextStyle(color: Colors.white)),
            content: Text('Delete "${team.name}"?\nThis cannot be undone.',
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ) ??
        false;
    if (ok) await FirebaseService.deleteTeam(team.id);
  }
}

// ── Team Editor ───────────────────────────────────────────────────────────────

class TeamEditorScreen extends StatefulWidget {
  final SavedTeam? existing;
  const TeamEditorScreen({super.key, this.existing});
  @override
  State<TeamEditorScreen> createState() => _TeamEditorScreenState();
}

class _TeamEditorScreenState extends State<TeamEditorScreen> {
  late final TextEditingController _nameCtrl;
  late List<PlayerSetupData> _players;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl =
          TextEditingController(text: widget.existing!.name);
      _players = widget.existing!.players
          .map(PlayerSetupData.fromInfo)
          .toList();
    } else {
      _nameCtrl = TextEditingController();
      _players =
          List.generate(18, (i) => PlayerSetupData('Player ${i + 1}'));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final p in _players) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Enter a team name');
      return;
    }
    final err = validateSquad(_players, name,
        min: _players.length, max: _players.length);
    if (err != null) {
      _snack(err);
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseService.saveTeam(
        id: widget.existing?.id,
        name: name,
        players: _players.map((p) => p.toInfo()).toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: Text(_isEditing ? 'Edit Team' : 'New Team',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.greenAccent, strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(children: [
        // Team name + player count bar
        Container(
          color: const Color(0xFF0D2B1E),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Team name',
                  hintStyle:
                      const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.shield_outlined,
                      color: Colors.greenAccent, size: 20),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.green.shade800),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Colors.greenAccent, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1B3A2D),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Player count chips
            _countBtn(11),
            const SizedBox(width: 6),
            _countBtn(18),
          ]),
        ),
        // Squad entry
        Expanded(
          child: SquadEntryWidget(
            players: _players,
            accentColor: Colors.green.shade700,
            onAddPlayer: _players.length < 21
                ? () => setState(() => _players
                    .add(PlayerSetupData('Player ${_players.length + 1}')))
                : null,
            onRemovePlayer: _players.length > 1
                ? (i) => setState(() {
                      _players[i].dispose();
                      _players.removeAt(i);
                    })
                : null,
          ),
        ),
      ]),
    );
  }

  Widget _countBtn(int n) {
    final sel = _players.length == n;
    return GestureDetector(
      onTap: () {
        if (sel) return;
        setState(() {
          while (_players.length < n) {
            _players
                .add(PlayerSetupData('Player ${_players.length + 1}'));
          }
          while (_players.length > n) {
            _players.last.dispose();
            _players.removeLast();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.green.shade700 : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? Colors.greenAccent : Colors.white24),
        ),
        child: Text('$n',
            style: TextStyle(
                color: sel ? Colors.white : Colors.white54,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }
}
