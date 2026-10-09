import 'package:flutter/material.dart';
import '../cup_data.dart';
import '../models.dart';
import '../tournament_models.dart';
import 'tournament_home_screen.dart';

class SquadReviewScreen extends StatefulWidget {
  final CupType cupType;
  final List<List<String>> groupAssignments;
  final List<TournamentTeam> initialTeams;

  const SquadReviewScreen({
    super.key,
    required this.cupType,
    required this.groupAssignments,
    required this.initialTeams,
  });

  @override
  State<SquadReviewScreen> createState() => _SquadReviewScreenState();
}

class _SquadReviewScreenState extends State<SquadReviewScreen> {
  late final Map<String, List<PlayerInfo>> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final t in widget.initialTeams)
        t.name: List<PlayerInfo>.from(t.players),
    };
  }

  Future<void> _openTeamEditor(String teamName) async {
    final result = await Navigator.push<List<PlayerInfo>>(
      context,
      MaterialPageRoute(
        builder: (_) => _TeamSquadEditor(
          teamName: teamName,
          selected: List<PlayerInfo>.from(_selected[teamName]!),
          pool: CupData.teamPool(teamName),
        ),
      ),
    );
    if (result != null) setState(() => _selected[teamName] = result);
  }

  void _startTournament() {
    final teams = widget.initialTeams
        .map((t) => TournamentTeam(name: t.name, players: _selected[t.name]!))
        .toList();

    final state = InternationalCupState(
      cupType: widget.cupType,
      teams: teams,
      groupAssignments: widget.groupAssignments,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentHomeScreen(tournament: InternationalCupHolder(state)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Review Squads',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _startTournament,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text('Start Tournament'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tap any team to swap players from their pool before the tournament starts.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          for (int gi = 0; gi < widget.groupAssignments.length; gi++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                'GROUP ${String.fromCharCode(65 + gi)}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            for (final teamName in widget.groupAssignments[gi])
              _TeamTile(
                teamName: teamName,
                squad: _selected[teamName]!,
                onTap: () => _openTeamEditor(teamName),
              ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  final String teamName;
  final List<PlayerInfo> squad;
  final VoidCallback onTap;

  const _TeamTile({
    required this.teamName,
    required this.squad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final captain = squad.firstWhere((p) => p.isCaptain, orElse: () => squad.first);
    final batters = squad.where((p) => p.role == PlayerRole.batter).length;
    final bowlers = squad.where((p) => p.role == PlayerRole.bowler).length;
    final allRounders = squad.where((p) => p.role == PlayerRole.allRounder).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2B1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(teamName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 3),
              Text('C: ${captain.name}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                '${squad.length} players · $batters bat · $allRounders AR · $bowlers bowl',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.shade900.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_outlined, color: Colors.greenAccent, size: 13),
              SizedBox(width: 4),
              Text('Edit', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Per-team squad editor ─────────────────────────────────────────────────────

class _TeamSquadEditor extends StatefulWidget {
  final String teamName;
  final List<PlayerInfo> selected;
  final List<PlayerInfo> pool;

  const _TeamSquadEditor({
    required this.teamName,
    required this.selected,
    required this.pool,
  });

  @override
  State<_TeamSquadEditor> createState() => _TeamSquadEditorState();
}

class _TeamSquadEditorState extends State<_TeamSquadEditor> {
  late List<PlayerInfo> _selected;
  PlayerInfo? _pendingSwap;

  @override
  void initState() {
    super.initState();
    _selected = List<PlayerInfo>.from(widget.selected);
  }

  List<PlayerInfo> get _bench =>
      widget.pool.where((p) => !_selected.any((s) => s.name == p.name)).toList();

  void _tapSelected(PlayerInfo p) {
    if (p.isCaptain) return;
    setState(() {
      _pendingSwap = _pendingSwap?.name == p.name ? null : p;
    });
  }

  void _tapBench(PlayerInfo p) {
    if (_pendingSwap == null) return;
    setState(() {
      _selected.removeWhere((s) => s.name == _pendingSwap!.name);
      _selected.add(p);
      _pendingSwap = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bench = _bench;
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.teamName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
      body: Column(children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _pendingSwap != null
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.amber.shade900.withValues(alpha: 0.45),
                  child: Text(
                    'Now tap a bench player to replace  ${_pendingSwap!.name}',
                    style: const TextStyle(color: Colors.amber, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('SQUAD  (${_selected.length}/18)  — tap to swap out'),
              const SizedBox(height: 8),
              ..._selected.map((p) => _playerTile(
                    p,
                    inSquad: true,
                    isPending: _pendingSwap?.name == p.name,
                    onTap: () => _tapSelected(p),
                  )),
              const SizedBox(height: 20),
              _sectionLabel('BENCH  (${bench.length})  — tap to bring in'),
              const SizedBox(height: 8),
              if (bench.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No bench players available',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                )
              else
                ...bench.map((p) => _playerTile(
                      p,
                      inSquad: false,
                      isPending: false,
                      onTap: () => _tapBench(p),
                    )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4));

  Widget _playerTile(PlayerInfo p,
      {required bool inSquad, required bool isPending, required VoidCallback onTap}) {
    final isLocked = p.isCaptain && inSquad;
    final borderColor = isPending
        ? Colors.amber
        : inSquad
            ? Colors.green.shade800
            : Colors.white12;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPending
              ? Colors.amber.withValues(alpha: 0.10)
              : inSquad
                  ? Colors.green.withValues(alpha: 0.06)
                  : const Color(0xFF0D2B1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isPending ? 1.5 : 1),
        ),
        child: Row(children: [
          Expanded(
            child: Row(children: [
              Expanded(
                child: Text(p.name,
                    style: TextStyle(
                        color: inSquad ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
              ),
              const SizedBox(width: 8),
              if (p.isCaptain) _badge('C', Colors.amber.shade700),
              if (p.isWicketKeeper) _badge('WK', Colors.blue.shade800),
              _badge(_roleShort(p), _roleColor(p)),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(
            isLocked
                ? Icons.lock_outline
                : inSquad
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
            color: isLocked
                ? Colors.amber.withValues(alpha: 0.6)
                : inSquad
                    ? (_pendingSwap != null
                        ? Colors.amber
                        : Colors.white24)
                    : Colors.greenAccent.withValues(alpha: 0.7),
            size: 18,
          ),
        ]),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  String _roleShort(PlayerInfo p) {
    if (p.role == PlayerRole.bowler) {
      return p.bowlerType == BowlerType.fast ? 'PAC' : 'SPIN';
    }
    if (p.role == PlayerRole.allRounder) {
      return p.bowlerType == BowlerType.fast ? 'AR-F' : 'AR-S';
    }
    return 'BAT';
  }

  Color _roleColor(PlayerInfo p) {
    if (p.role == PlayerRole.bowler) {
      return p.bowlerType == BowlerType.fast
          ? const Color(0xFFBF360C)
          : const Color(0xFF4527A0);
    }
    if (p.role == PlayerRole.allRounder) {
      return p.bowlerType == BowlerType.fast
          ? const Color(0xFFBF360C)
          : const Color(0xFF6A1B9A);
    }
    return const Color(0xFF2E7D32);
  }
}
