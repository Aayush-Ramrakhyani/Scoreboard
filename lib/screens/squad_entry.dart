import 'package:flutter/material.dart';
import '../models.dart';
import '../services/firebase_service.dart';

/// Mutable per-player state used while building a squad before it is committed.
class PlayerSetupData {
  final TextEditingController nameCtrl;
  PlayerRole? role;
  BowlerType? bowlerType;
  bool isCaptain;
  bool isWicketKeeper;

  PlayerSetupData(String defaultName)
      : nameCtrl = TextEditingController(text: defaultName),
        role = null,
        isCaptain = false,
        isWicketKeeper = false;

  factory PlayerSetupData.fromInfo(PlayerInfo info) {
    final p = PlayerSetupData(info.name);
    p.isWicketKeeper = info.isWicketKeeper;
    p.role = info.isWicketKeeper ? PlayerRole.batter : info.role;
    p.bowlerType = info.bowlerType;
    p.isCaptain = info.isCaptain;
    return p;
  }

  void loadFrom(PlayerInfo info) {
    nameCtrl.text = info.name;
    isWicketKeeper = info.isWicketKeeper;
    role = info.isWicketKeeper ? PlayerRole.batter : info.role;
    bowlerType = info.bowlerType;
    isCaptain = info.isCaptain;
  }

  bool get needsBowlerType =>
      role == PlayerRole.bowler || role == PlayerRole.allRounder;

  PlayerInfo toInfo() => PlayerInfo(
        name: nameCtrl.text.trim(),
        role: isWicketKeeper ? PlayerRole.batter : (role ?? PlayerRole.batter),
        bowlerType: bowlerType,
        isCaptain: isCaptain,
        isWicketKeeper: isWicketKeeper,
      );

  void dispose() => nameCtrl.dispose();
}

String? validateSquad(List<PlayerSetupData> players, String teamName,
    {int min = 11, int max = 11}) {
  if (players.length < min || players.length > max) {
    return min == max
        ? '$teamName must have exactly $min players'
        : '$teamName squad must have $min–$max players';
  }
  if (players.any((p) => p.nameCtrl.text.trim().isEmpty)) {
    return 'Fill all player names for $teamName';
  }
  if (players.any((p) => !p.isWicketKeeper && p.role == null)) {
    return 'Select a playing role for every player in $teamName';
  }
  if (players.where((p) => p.isCaptain).length > 1) {
    return '$teamName can have only one Captain';
  }
  if (players.any((p) => p.needsBowlerType && p.bowlerType == null)) {
    return 'Pick Fast or Spin for every Bowler / All-Rounder in $teamName';
  }
  return null;
}

class SquadEntryWidget extends StatefulWidget {
  final List<PlayerSetupData> players;
  final Color accentColor;
  final VoidCallback? onAddPlayer;
  final void Function(int index)? onRemovePlayer;

  const SquadEntryWidget({
    super.key,
    required this.players,
    required this.accentColor,
    this.onAddPlayer,
    this.onRemovePlayer,
  });

  @override
  State<SquadEntryWidget> createState() => _SquadEntryWidgetState();
}

class _SquadEntryWidgetState extends State<SquadEntryWidget> {
  @override
  Widget build(BuildContext context) {
    final players = widget.players;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: players.length + (widget.onAddPlayer != null ? 1 : 0),
      itemBuilder: (_, i) {
        if (widget.onAddPlayer != null && i == players.length) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton.icon(
              onPressed: widget.onAddPlayer,
              icon: Icon(Icons.person_add,
                  color: Theme.of(context).colorScheme.primary, size: 18),
              label: Text('Add Player',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          );
        }

        final p = players[i];
        // Only captain is limited to 1 — WK can be multiple in a squad
        final captainTaken =
            players.asMap().entries.any((e) => e.key != i && e.value.isCaptain);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: widget.accentColor,
                  child: Text('${i + 1}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: p.nameCtrl,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      hintText: 'Player name',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.surface),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                ),
                ..._buildBadges(p).map((b) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _badgeChip(b.label, b.color),
                    )),
                if (widget.onRemovePlayer != null)
                  GestureDetector(
                    onTap: () => widget.onRemovePlayer!(i),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.remove_circle_outline,
                          color: Colors.redAccent.withValues(alpha: 0.8), size: 20),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              _sectionLabel('PLAYING ROLE'),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _roleChip(
                  label: 'Batter',
                  selected: p.role == PlayerRole.batter,
                  color: const Color(0xFF388E3C),
                  locked: p.isWicketKeeper,
                  onTap: p.isWicketKeeper
                      ? null
                      : () => setState(() {
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
                      : () => setState(() => p.role = PlayerRole.bowler),
                ),
                _roleChip(
                  label: 'All-Rounder',
                  selected: p.role == PlayerRole.allRounder,
                  color: const Color(0xFF6A1B9A),
                  locked: p.isWicketKeeper,
                  onTap: p.isWicketKeeper
                      ? null
                      : () => setState(() => p.role = PlayerRole.allRounder),
                ),
              ]),
              if (p.needsBowlerType) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Text('Type:',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                  const SizedBox(width: 8),
                  _typeChip(p, BowlerType.fast, 'Fast'),
                  const SizedBox(width: 6),
                  _typeChip(p, BowlerType.spin, 'Spin'),
                ]),
              ],
              const SizedBox(height: 10),
              Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
              const SizedBox(height: 10),
              _sectionLabel('DESIGNATION'),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _toggleChip(
                  label: 'Wicket Keeper',
                  icon: Icons.sports_cricket,
                  active: p.isWicketKeeper,
                  color: const Color(0xFF1565C0),
                  disabled: false, // multiple WKs allowed in a squad
                  onTap: () => setState(() {
                    p.isWicketKeeper = !p.isWicketKeeper;
                    if (p.isWicketKeeper) {
                      p.role = PlayerRole.batter;
                      p.bowlerType = null;
                    } else {
                      p.role = null;
                    }
                  }),
                ),
                _toggleChip(
                  label: 'Captain',
                  icon: Icons.star,
                  active: p.isCaptain,
                  color: const Color(0xFFF9A825),
                  disabled: captainTaken,
                  // setState rebuilds ALL cards so captainTaken recalculates everywhere
                  onTap: captainTaken
                      ? null
                      : () => setState(() => p.isCaptain = !p.isCaptain),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : dim ? Theme.of(context).colorScheme.outlineVariant : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? Colors.white
                    : dim
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _typeChip(PlayerSetupData p, BowlerType type, String label) {
    final sel = p.bowlerType == type;
    final color = type == BowlerType.fast ? Colors.deepOrange : Colors.indigo;
    return GestureDetector(
      onTap: () => setState(() => p.bowlerType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color : Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
          color: active ? color.withValues(alpha: 0.85) : Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? color
                  : disabled
                      ? Theme.of(context).colorScheme.outlineVariant
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? Icons.check_circle : icon,
              size: 14,
              color: active
                  ? Colors.white
                  : disabled
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: active
                      ? Colors.white
                      : disabled
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _badgeChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        child: Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  List<({String label, Color color})> _buildBadges(PlayerSetupData p) {
    final list = <({String label, Color color})>[];
    if (p.isWicketKeeper) list.add((label: 'WK', color: const Color(0xFF1565C0)));
    if (p.isCaptain) list.add((label: 'C', color: const Color(0xFFF9A825)));
    if (p.role == PlayerRole.batter) {
      list.add((label: 'Bat', color: const Color(0xFF2E7D32)));
    } else if (p.role == PlayerRole.bowler && p.bowlerType != null) {
      list.add((
        label: p.bowlerType == BowlerType.fast ? 'Fast' : 'Spin',
        color: p.bowlerType == BowlerType.fast
            ? const Color(0xFFBF360C)
            : const Color(0xFF4527A0),
      ));
    } else if (p.role == PlayerRole.allRounder && p.bowlerType != null) {
      list.add((
        label: p.bowlerType == BowlerType.fast ? 'AR-F' : 'AR-S',
        color: p.bowlerType == BowlerType.fast
            ? const Color(0xFFBF360C)
            : const Color(0xFF6A1B9A),
      ));
    }
    return list;
  }
}

// ── Shared team-picker utilities ──────────────────────────────────────────────

/// Shows a bottom sheet listing the user's saved teams.
/// Returns the selected [SavedTeam], or null if dismissed.
Future<SavedTeam?> showTeamPickerSheet(BuildContext context) =>
    showModalBottomSheet<SavedTeam>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _TeamPickerSheet(),
    );

/// Resizes [squad] to match [team] players, fills each slot from [team],
/// updates [nameCtrl], then calls [setState].
void applyTeamToSquad({
  required SavedTeam team,
  required List<PlayerSetupData> squad,
  required TextEditingController nameCtrl,
  required StateSetter setState,
}) {
  setState(() {
    nameCtrl.text = team.name;
    // Grow
    while (squad.length < team.players.length) {
      squad.add(PlayerSetupData('Player ${squad.length + 1}'));
    }
    // Shrink
    while (squad.length > team.players.length) {
      squad.last.dispose();
      squad.removeLast();
    }
    // Fill
    for (int i = 0; i < team.players.length; i++) {
      squad[i].loadFrom(team.players[i]);
    }
  });
}

class _TeamPickerSheet extends StatefulWidget {
  const _TeamPickerSheet();
  @override
  State<_TeamPickerSheet> createState() => _TeamPickerSheetState();
}

class _TeamPickerSheetState extends State<_TeamPickerSheet> {
  List<SavedTeam>? _teams;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    FirebaseService.loadTeams().then((teams) {
      if (mounted) setState(() { _teams = teams; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _teams = []; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SizedBox(
      height: mq.size.height * 0.6,
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(2)),
        ),
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
          child: Row(children: [
            Expanded(
              child: Text('Load from My Teams',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        // Content
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary))
              : (_teams == null || _teams!.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_add,
                              color: Theme.of(context).colorScheme.outlineVariant, size: 44),
                          SizedBox(height: 12),
                          Text('No saved teams yet',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                          SizedBox(height: 4),
                          Text('Go to My Teams to create one',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _teams!.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final t = _teams![i];
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            ),
                            child: Row(children: [
                              Icon(Icons.groups,
                                  color: Theme.of(context).colorScheme.primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(t.name,
                                          style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      Text('${t.players.length} players',
                                          style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                              fontSize: 11)),
                                    ]),
                              ),
                              Icon(Icons.chevron_right,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
