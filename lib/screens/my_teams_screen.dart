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
      appBar: AppBar(
        title: Text('My Teams',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
            tooltip: 'New team',
            onPressed: () => _openEditor(context, null),
          ),
        ],
      ),
      body: StreamBuilder<List<SavedTeam>>(
        stream: FirebaseService.teamsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary));
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        icon: const Icon(Icons.group_add),
        label: const Text('New Team'),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_add, color: Theme.of(context).colorScheme.outlineVariant, size: 64),
          const SizedBox(height: 18),
          Text('No saved teams yet',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 17)),
          const SizedBox(height: 8),
          Text('Create a team once, load it in any tournament',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 13)),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    if (captain.isNotEmpty)
                      Text('Captain: $captain',
                          style: const TextStyle(
                              color: Colors.amber, fontSize: 11)),
                  ]),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 20),
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
            _chip('${team.players.length} players', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
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
            style: TextStyle(color: color, fontSize: 11)),
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
                title: Text('Delete Team',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            content: Text('Delete "${team.name}"?\nThis cannot be undone.',
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Team' : 'New Team',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary, strokeWidth: 2))
                : Text('Save',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(children: [
        // Team name + player count bar
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Team name',
                  hintStyle:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                  prefixIcon: Icon(Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Theme.of(context).colorScheme.surface),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
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
            accentColor: Theme.of(context).colorScheme.primary,
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
          color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
        ),
        child: Text('$n',
            style: TextStyle(
                color: sel ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }
}
