import 'package:flutter/material.dart';
import '../models.dart';
import 'squad_entry.dart' show showTeamPickerSheet;
import 'toss_screen.dart';

// ── per-player mutable setup state ───────────────────────────────────────────
class _PlayerSetup {
  final TextEditingController nameCtrl;
  PlayerRole role;
  BowlerType? bowlerType;
  bool isCaptain;
  bool isWicketKeeper; // forces role = batter

  _PlayerSetup(String defaultName)
      : nameCtrl = TextEditingController(text: defaultName),
        role = PlayerRole.batter,
        isCaptain = false,
        isWicketKeeper = false;

  bool get needsBowlerType =>
      role == PlayerRole.bowler || role == PlayerRole.allRounder;
}

// ── screen ────────────────────────────────────────────────────────────────────
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _team1NameCtrl = TextEditingController(text: 'Team A');
  final _team2NameCtrl = TextEditingController(text: 'Team B');
  MatchFormat _format = MatchFormat.t20;
  int _days = 5;

  late final List<_PlayerSetup> _team1;
  late final List<_PlayerSetup> _team2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _team1 = List.generate(11, (i) => _PlayerSetup('Player ${i + 1}'));
    _team2 = List.generate(11, (i) => _PlayerSetup('Player ${i + 1}'));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── validation ────────────────────────────────────────────────────────────

  String? _validateTeam(List<_PlayerSetup> players, String teamName) {
    if (players.any((p) => p.nameCtrl.text.trim().isEmpty)) {
      return 'Fill all player names for $teamName';
    }
    final wkCount = players.where((p) => p.isWicketKeeper).length;
    if (wkCount > 1) return '$teamName can have only one Wicket Keeper';
    final cCount = players.where((p) => p.isCaptain).length;
    if (cCount > 1) return '$teamName can have only one Captain';
    final missingType =
        players.where((p) => p.needsBowlerType && p.bowlerType == null).length;
    if (missingType > 0) {
      return 'Pick Fast or Spin for every Bowler / All-Rounder in $teamName';
    }
    return null;
  }

  void _startMatch() {
    final t1 = _team1NameCtrl.text.trim();
    final t2 = _team2NameCtrl.text.trim();
    if (t1.isEmpty || t2.isEmpty) { _snack('Please enter both team names'); return; }
    final err1 = _validateTeam(_team1, t1);
    if (err1 != null) { _snack(err1); return; }
    final err2 = _validateTeam(_team2, t2);
    if (err2 != null) { _snack(err2); return; }

    final setup = MatchSetup(
      team1Name: t1,
      team2Name: t2,
      team1Players: _team1.map(_toInfo).toList(),
      team2Players: _team2.map(_toInfo).toList(),
      format: _format,
      days: _days,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TossScreen(setup: setup)),
    );
  }

  PlayerInfo _toInfo(_PlayerSetup p) => PlayerInfo(
        name: p.nameCtrl.text.trim(),
        role: p.isWicketKeeper ? PlayerRole.batter : p.role,
        bowlerType: p.bowlerType,
        isCaptain: p.isCaptain,
        isWicketKeeper: p.isWicketKeeper,
      );

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadTeamInto(
      BuildContext ctx, TextEditingController nameCtrl, List<_PlayerSetup> squad) async {
    final team = await showTeamPickerSheet(ctx);
    if (team == null || !mounted) return;
    setState(() {
      nameCtrl.text = team.name;
      while (squad.length < team.players.length) {
        squad.add(_PlayerSetup('Player ${squad.length + 1}'));
      }
      while (squad.length > team.players.length) {
        squad.last.nameCtrl.dispose();
        squad.removeLast();
      }
      for (var i = 0; i < team.players.length; i++) {
        final p = team.players[i];
        squad[i].nameCtrl.text = p.name;
        squad[i].isWicketKeeper = p.isWicketKeeper;
        squad[i].role = p.isWicketKeeper ? PlayerRole.batter : p.role;
        squad[i].bowlerType = p.bowlerType;
        squad[i].isCaptain = p.isCaptain;
      }
    });
  }

  // ── player card ───────────────────────────────────────────────────────────

  Widget _buildPlayerList(List<_PlayerSetup> players, Color accentColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: 11,
      itemBuilder: (_, i) {
        final p = players[i];
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final wkTaken = players
                .asMap()
                .entries
                .any((e) => e.key != i && e.value.isWicketKeeper);
            final captainTaken = players
                .asMap()
                .entries
                .any((e) => e.key != i && e.value.isCaptain);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2B1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── name + badge preview ──────────────────────────────
                  Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: accentColor,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: p.nameCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          hintText: 'Player name',
                          hintStyle:
                              const TextStyle(color: Colors.white30),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.green.shade800),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.greenAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1B3A2D),
                        ),
                      ),
                    ),
                    // live badge preview
                    ..._buildBadgesFromSetup(p)
                        .map((b) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _badgeChip(b.label, b.color),
                            )),
                  ]),

                  const SizedBox(height: 10),

                  // ── playing role ──────────────────────────────────────
                  _sectionLabel('PLAYING ROLE'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _roleChip(
                        label: 'Batter',
                        selected: p.role == PlayerRole.batter,
                        color: const Color(0xFF388E3C),
                        // WK forces batter — chip is locked, just show selected
                        locked: p.isWicketKeeper,
                        onTap: p.isWicketKeeper
                            ? null
                            : () => setSt(() {
                                  p.role = PlayerRole.batter;
                                  p.bowlerType = null;
                                }),
                      ),
                      _roleChip(
                        label: 'Bowler',
                        selected: p.role == PlayerRole.bowler,
                        color: const Color(0xFFBF360C),
                        locked: p.isWicketKeeper,
                        onTap: p.isWicketKeeper
                            ? null
                            : () => setSt(() {
                                  p.role = PlayerRole.bowler;
                                }),
                      ),
                      _roleChip(
                        label: 'All-Rounder',
                        selected: p.role == PlayerRole.allRounder,
                        color: const Color(0xFF6A1B9A),
                        locked: p.isWicketKeeper,
                        onTap: p.isWicketKeeper
                            ? null
                            : () => setSt(() {
                                  p.role = PlayerRole.allRounder;
                                }),
                      ),
                    ],
                  ),

                  // ── bowler type ───────────────────────────────────────
                  if (p.needsBowlerType) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Text('Type:',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 8),
                      _bowlerTypeChip(
                          p, BowlerType.fast, 'Fast', setSt),
                      const SizedBox(width: 6),
                      _bowlerTypeChip(
                          p, BowlerType.spin, 'Spin', setSt),
                    ]),
                  ],

                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),

                  // ── designations ──────────────────────────────────────
                  _sectionLabel('DESIGNATION'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _toggleChip(
                        label: 'Wicket Keeper',
                        icon: Icons.sports_cricket,
                        active: p.isWicketKeeper,
                        color: const Color(0xFF1565C0),
                        disabled: wkTaken,
                        onTap: wkTaken
                            ? null
                            : () => setSt(() {
                                  p.isWicketKeeper = !p.isWicketKeeper;
                                  if (p.isWicketKeeper) {
                                    // WK must be a batter
                                    p.role = PlayerRole.batter;
                                    p.bowlerType = null;
                                  }
                                }),
                      ),
                      _toggleChip(
                        label: 'Captain',
                        icon: Icons.star,
                        active: p.isCaptain,
                        color: const Color(0xFFF9A825),
                        disabled: captainTaken,
                        onTap: captainTaken
                            ? null
                            : () => setSt(() {
                                  p.isCaptain = !p.isCaptain;
                                }),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── chip builders ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5));

  Widget _roleChip({
    required String label,
    required bool selected,
    required Color color,
    required bool locked,
    required VoidCallback? onTap,
  }) {
    final dim = locked && !selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : dim ? Colors.white10 : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? Colors.white
                    : dim
                        ? Colors.white24
                        : Colors.white60,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _bowlerTypeChip(
      _PlayerSetup p, BowlerType type, String label, StateSetter setSt) {
    final sel = p.bowlerType == type;
    final color =
        type == BowlerType.fast ? Colors.deepOrange : Colors.indigo;
    return GestureDetector(
      onTap: () => setSt(() => p.bowlerType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required bool disabled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha:0.85) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? color
                  : disabled
                      ? Colors.white10
                      : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? Icons.check_circle : icon,
                size: 14,
                color: active
                    ? Colors.white
                    : disabled
                        ? Colors.white24
                        : Colors.white54),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active
                        ? Colors.white
                        : disabled
                            ? Colors.white24
                            : Colors.white60,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _badgeChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
      );

  List<({String label, Color color})> _buildBadgesFromSetup(
      _PlayerSetup p) {
    final list = <({String label, Color color})>[];
    if (p.isWicketKeeper) {
      list.add((label: 'WK', color: const Color(0xFF1565C0)));
    }
    if (p.isCaptain) {
      list.add((label: 'C', color: const Color(0xFFF9A825)));
    }
    if (p.role == PlayerRole.batter) {
      list.add((label: 'Bat', color: const Color(0xFF2E7D32)));
    }
    if (p.role == PlayerRole.bowler && p.bowlerType != null) {
      list.add((
        label: p.bowlerType == BowlerType.fast ? 'Fast' : 'Spin',
        color: p.bowlerType == BowlerType.fast
            ? const Color(0xFFBF360C)
            : const Color(0xFF4527A0),
      ));
    }
    if (p.role == PlayerRole.allRounder && p.bowlerType != null) {
      list.add((
        label: p.bowlerType == BowlerType.fast ? 'AR-F' : 'AR-S',
        color: p.bowlerType == BowlerType.fast
            ? const Color(0xFFBF360C)
            : const Color(0xFF6A1B9A),
      ));
    }
    return list;
  }

  // ── main scaffold ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Cricket Scoreboard Setup',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.greenAccent,
          tabs: const [
            Tab(text: 'Match Info'),
            Tab(text: 'Team 1 Players'),
            Tab(text: 'Team 2 Players'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _infoCard(),
                const SizedBox(height: 24),
                _field(_team1NameCtrl, 'Team 1 Name', Icons.groups),
                const SizedBox(height: 16),
                _field(_team2NameCtrl, 'Team 2 Name', Icons.groups_2),
                const SizedBox(height: 16),
                _formatPicker(),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _startMatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Start Match'),
                ),
              ],
            ),
          ),
          Column(children: [
            _teamHeader(_team1NameCtrl, Colors.green.shade700, _team1),
            Expanded(
                child:
                    _buildPlayerList(_team1, Colors.green.shade700)),
          ]),
          Column(children: [
            _teamHeader(_team2NameCtrl, Colors.blue.shade700, _team2),
            Expanded(
                child:
                    _buildPlayerList(_team2, Colors.blue.shade700)),
          ]),
        ],
      ),
    );
  }

  Widget _infoCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade900.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent.withValues(alpha:0.3)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.sports_cricket,
                  color: Colors.greenAccent, size: 26),
              SizedBox(width: 10),
              Text('Match Setup',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ]),
            SizedBox(height: 8),
            Text(
              '• Each player has a Playing Role (Batter / Bowler / All-Rounder)\n'
              '• Bowler & All-Rounder must pick Fast or Spin\n'
              '• Wicket Keeper designation forces Batter role\n'
              '• Only one WK and one Captain per team',
              style: TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      );

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
            style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const SizedBox(height: 10),
        ...formats.map((f) {
          final sel = _format == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _format = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: sel
                    ? Colors.green.shade800.withValues(alpha:0.35)
                    : const Color(0xFF0D2B1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? Colors.greenAccent : Colors.white24),
              ),
              child: Row(children: [
                Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: sel ? Colors.greenAccent : Colors.white38,
                    size: 20),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.$2,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14)),
                  Text(f.$3,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ]),
              ]),
            ),
          );
        }),
        if (_format == MatchFormat.test) ...[
          const SizedBox(height: 8),
          const Text('NUMBER OF DAYS',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
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
                    color: sel ? Colors.green.shade800 : const Color(0xFF0D2B1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? Colors.greenAccent : Colors.white24),
                  ),
                  child: Text('$d days',
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white60,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal)),
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
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.shade700),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide:
              const BorderSide(color: Colors.greenAccent, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: const Color(0xFF0D2B1E),
      ),
    );
  }

  Widget _teamHeader(TextEditingController ctrl, Color color, List<_PlayerSetup> squad) =>
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
              onPressed: () => _loadTeamInto(ctx, ctrl, squad),
            ),
          ]),
        ),
      );
}
