import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../tournament_models.dart';
import 'toss_screen.dart';

class PlayingXIScreen extends StatefulWidget {
  final TournamentTeam team1;
  final TournamentTeam team2;
  final MatchFormat format;
  final int days;
  final String matchLabel;
  final void Function(MatchState ms)? onMatchComplete;

  const PlayingXIScreen({
    super.key,
    required this.team1,
    required this.team2,
    required this.format,
    required this.days,
    required this.matchLabel,
    this.onMatchComplete,
  });

  @override
  State<PlayingXIScreen> createState() => _PlayingXIScreenState();
}

class _PlayingXIScreenState extends State<PlayingXIScreen>
    with TickerProviderStateMixin {
  late final TabController _tab;
  late final AnimationController _swapCtrl;

  // ORDERED playing XI — index = slot (0-10), value = squad index
  late final List<int> _xi1, _xi2;
  int _cap1 = -1, _cap2 = -1;
  int _wk1 = -1, _wk2 = -1;

  // Selection: XI slot index (-1 = none), bench squad idx (-1 = none)
  int _selXIPos1 = -1, _selXIPos2 = -1;
  int _selBench1 = -1, _selBench2 = -1;

  // Swap animation state
  bool _isAnimating = false;
  int _animTabIdx = -1;
  int _animXIPos = -1;        // XI slot being animated
  int _animBenchSqIdx = -1;   // bench squad idx being animated
  OverlayEntry? _swapOverlay;

  // GlobalKey registry: "xi/bench-tabIdx-listPos"
  final _keys = <String, GlobalKey>{};
  GlobalKey _k(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _swapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));

    final pre1 = min(11, widget.team1.players.length);
    final pre2 = min(11, widget.team2.players.length);
    _xi1 = List.generate(pre1, (i) => i);
    _xi2 = List.generate(pre2, (i) => i);

    _cap1 = widget.team1.players.indexWhere((p) => p.isCaptain);
    _cap2 = widget.team2.players.indexWhere((p) => p.isCaptain);

    _wk1 = _xi1.firstWhere(
        (sq) => widget.team1.players[sq].isWicketKeeper, orElse: () => -1);
    _wk2 = _xi2.firstWhere(
        (sq) => widget.team2.players[sq].isWicketKeeper, orElse: () => -1);
  }

  @override
  void dispose() {
    _swapOverlay?.remove();
    _tab.dispose();
    _swapCtrl.dispose();
    super.dispose();
  }

  // ── Readiness
  bool get _cap1Ok => _cap1 >= 0 && _xi1.contains(_cap1);
  bool get _cap2Ok => _cap2 >= 0 && _xi2.contains(_cap2);
  bool get _wk1Ok => _wk1 >= 0 && _xi1.contains(_wk1);
  bool get _wk2Ok => _wk2 >= 0 && _xi2.contains(_wk2);
  bool get _canConfirm =>
      _xi1.length == 11 && _xi2.length == 11 &&
      _cap1Ok && _cap2Ok && _wk1Ok && _wk2Ok;

  // ── Apply swap in data (call inside setState)
  void _applySwap(bool isTeam1) {
    final xi = isTeam1 ? _xi1 : _xi2;
    final squad = isTeam1 ? widget.team1.players : widget.team2.players;
    final xiPos = isTeam1 ? _selXIPos1 : _selXIPos2;
    final bench = isTeam1 ? _selBench1 : _selBench2;

    final outSq = xi[xiPos];
    xi[xiPos] = bench; // in-place replace — position is preserved

    if (isTeam1) {
      if (_cap1 == outSq) _cap1 = -1;
      if (_wk1 == outSq) {
        _wk1 = squad[bench].isWicketKeeper
            ? bench
            : _xi1.firstWhere((s) => squad[s].isWicketKeeper, orElse: () => -1);
      }
      _selXIPos1 = -1;
      _selBench1 = -1;
    } else {
      if (_cap2 == outSq) _cap2 = -1;
      if (_wk2 == outSq) {
        _wk2 = squad[bench].isWicketKeeper
            ? bench
            : _xi2.firstWhere((s) => squad[s].isWicketKeeper, orElse: () => -1);
      }
      _selXIPos2 = -1;
      _selBench2 = -1;
    }
  }

  // ── Measure screen rect of a GlobalKey'd widget
  Rect? _getRect(GlobalKey key) {
    final rb = key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached) return null;
    return rb.localToGlobal(Offset.zero) & rb.size;
  }

  // ── Trigger the flying swap animation then apply data change
  Future<void> _triggerSwap(bool isTeam1) async {
    if (_isAnimating) return;

    final tabIdx = isTeam1 ? 0 : 1;
    final selXIPos = isTeam1 ? _selXIPos1 : _selXIPos2;
    final selBench = isTeam1 ? _selBench1 : _selBench2;
    final xi = isTeam1 ? _xi1 : _xi2;
    final squad = isTeam1 ? widget.team1.players : widget.team2.players;

    final benchList = List.generate(squad.length, (i) => i)
        .where((i) => !xi.contains(i))
        .toList();
    final benchListPos = benchList.indexOf(selBench);

    final xiRect = _getRect(_k('xi-$tabIdx-$selXIPos'));
    final benchRect = _getRect(_k('bench-$tabIdx-$benchListPos'));

    // Fall back to instant swap if off-screen
    if (xiRect == null || benchRect == null) {
      setState(() => _applySwap(isTeam1));
      return;
    }

    final xiName = squad[xi[selXIPos]].name;
    final benchName = squad[selBench].name;

    _animTabIdx = tabIdx;
    _animXIPos = selXIPos;
    _animBenchSqIdx = selBench;

    _swapOverlay = OverlayEntry(
      builder: (_) => _FlyingSwap(
        ctrl: _swapCtrl,
        xiRect: xiRect,
        benchRect: benchRect,
        xiName: xiName,
        benchName: benchName,
      ),
    );

    setState(() => _isAnimating = true);
    Overlay.of(context).insert(_swapOverlay!);
    await _swapCtrl.forward(from: 0);

    _swapOverlay?.remove();
    _swapOverlay = null;

    setState(() {
      _isAnimating = false;
      _animTabIdx = -1;
      _animXIPos = -1;
      _animBenchSqIdx = -1;
      _applySwap(isTeam1);
    });
  }

  // ── Build final XI and navigate
  void _confirm() {
    PlayerInfo toInfo(List<PlayerInfo> squad, int sqIdx, int cap, int wk) =>
        PlayerInfo(
          name: squad[sqIdx].name,
          role: squad[sqIdx].role,
          bowlerType: squad[sqIdx].bowlerType,
          isCaptain: sqIdx == cap,
          isWicketKeeper: sqIdx == wk,
        );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tournament'),
        builder: (_) => TossScreen(
          setup: MatchSetup(
            team1Name: widget.team1.name,
            team2Name: widget.team2.name,
            team1Players:
                _xi1.map((i) => toInfo(widget.team1.players, i, _cap1, _wk1)).toList(),
            team2Players:
                _xi2.map((i) => toInfo(widget.team2.players, i, _cap2, _wk2)).toList(),
            format: widget.format,
            days: widget.days,
          ),
          onMatchComplete: widget.onMatchComplete,
        ),
      ),
    );
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: Text(
          'Playing XI · ${widget.matchLabel}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.greenAccent,
          tabs: [
            _teamTab(widget.team1.name, _cap1Ok && _wk1Ok),
            _teamTab(widget.team2.name, _cap2Ok && _wk2Ok),
          ],
        ),
      ),
      body: Column(children: [
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildPanel(isTeam1: true),
              _buildPanel(isTeam1: false),
            ],
          ),
        ),
        _buildBottomBar(),
      ]),
    );
  }

  Tab _teamTab(String name, bool done) => Tab(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(name),
          if (done) ...[
            const SizedBox(width: 5),
            const Icon(Icons.check_circle, size: 13, color: Colors.greenAccent),
          ],
        ]),
      );

  // ── Full panel for one team
  Widget _buildPanel({required bool isTeam1}) {
    final tabIdx = isTeam1 ? 0 : 1;
    final team = isTeam1 ? widget.team1 : widget.team2;
    final xi = isTeam1 ? _xi1 : _xi2;
    final cap = isTeam1 ? _cap1 : _cap2;
    final wk = isTeam1 ? _wk1 : _wk2;
    final selXIPos = isTeam1 ? _selXIPos1 : _selXIPos2;
    final selBench = isTeam1 ? _selBench1 : _selBench2;
    final benchList = List.generate(team.players.length, (i) => i)
        .where((i) => !xi.contains(i))
        .toList();
    final canSwap = selXIPos >= 0 && selBench >= 0;
    final hasAny = selXIPos >= 0 || selBench >= 0;
    final animThisTab = _isAnimating && _animTabIdx == tabIdx;

    return Column(children: [
      // Team banner
      Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2B1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text(team.name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),

      // Column headers
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(children: [
          Expanded(
            child: Center(
              child: Text('PLAYING XI (${xi.length}/11)',
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: Center(
              child: Text('BENCH (${benchList.length})',
                  style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ),
          ),
        ]),
      ),

      // Two columns + swap button
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Playing XI column
              Expanded(
                child: _buildXIColumn(
                  tabIdx: tabIdx, team: team, xi: xi,
                  cap: cap, wk: wk, selXIPos: selXIPos,
                  isTeam1: isTeam1, animThisTab: animThisTab,
                ),
              ),

              // Centred swap button
              SizedBox(
                width: 40,
                child: Center(
                  child: _SwapButton(
                    canSwap: canSwap && !_isAnimating,
                    hasAny: hasAny,
                    onTap: () => _triggerSwap(isTeam1),
                  ),
                ),
              ),

              // Bench column
              Expanded(
                child: _buildBenchColumn(
                  tabIdx: tabIdx, team: team, xi: xi,
                  benchList: benchList, selBench: selBench,
                  isTeam1: isTeam1, animThisTab: animThisTab,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  // ── Playing XI list
  Widget _buildXIColumn({
    required int tabIdx,
    required TournamentTeam team,
    required List<int> xi,
    required int cap, required int wk,
    required int selXIPos,
    required bool isTeam1,
    required bool animThisTab,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: xi.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white10),
          itemBuilder: (_, pos) {
            final sqIdx = xi[pos];
            final p = team.players[sqIdx];
            final selected = selXIPos == pos;
            // Hide during animation so flying tile takes its place
            final hideForAnim = animThisTab && _animXIPos == pos;
            final isCap = cap == sqIdx;
            final isWk = wk == sqIdx;

            return KeyedSubtree(
              key: _k('xi-$tabIdx-$pos'),
              child: Opacity(
                opacity: hideForAnim ? 0 : 1,
                child: GestureDetector(
                  onTap: _isAnimating
                      ? null
                      : () => setState(() {
                            if (isTeam1) {
                              _selXIPos1 = selected ? -1 : pos;
                            } else {
                              _selXIPos2 = selected ? -1 : pos;
                            }
                          }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    color: selected
                        ? Colors.amber.withOpacity(0.15)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name row
                        Row(children: [
                          SizedBox(
                            width: 16,
                            child: Text('${pos + 1}',
                                style: TextStyle(
                                    color: selected
                                        ? Colors.amber
                                        : Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: Text(p.name,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.amber
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (selected)
                            const Icon(Icons.swap_horiz,
                                size: 12, color: Colors.amber),
                        ]),
                        // Chip row
                        const SizedBox(height: 3),
                        Row(children: [
                          const SizedBox(width: 16),
                          ..._roleBadge(p),
                          if (p.isWicketKeeper) ...[
                            const SizedBox(width: 2),
                            GestureDetector(
                              onTap: _isAnimating
                                  ? null
                                  : () => setState(() => isTeam1
                                      ? _wk1 = sqIdx
                                      : _wk2 = sqIdx),
                              child: _chip('WK', isWk, const Color(0xFF1565C0)),
                            ),
                          ],
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: _isAnimating
                                ? null
                                : () => setState(() =>
                                    isTeam1 ? _cap1 = sqIdx : _cap2 = sqIdx),
                            child: _chip('C', isCap, const Color(0xFFF9A825)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Bench list
  Widget _buildBenchColumn({
    required int tabIdx,
    required TournamentTeam team,
    required List<int> xi,
    required List<int> benchList,
    required int selBench,
    required bool isTeam1,
    required bool animThisTab,
  }) {
    if (benchList.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D2B1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text('No bench\nplayers',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: benchList.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white10),
          itemBuilder: (_, listPos) {
            final sqIdx = benchList[listPos];
            final p = team.players[sqIdx];
            final selected = selBench == sqIdx;
            final hideForAnim = animThisTab && _animBenchSqIdx == sqIdx;

            return KeyedSubtree(
              key: _k('bench-$tabIdx-$listPos'),
              child: Opacity(
                opacity: hideForAnim ? 0 : 1,
                child: GestureDetector(
                  onTap: _isAnimating
                      ? null
                      : () => setState(() {
                            if (isTeam1) {
                              _selBench1 = selected ? -1 : sqIdx;
                            } else {
                              _selBench2 = selected ? -1 : sqIdx;
                            }
                          }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    color: selected
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          SizedBox(
                            width: 16,
                            child: Text('${sqIdx + 1}',
                                style: TextStyle(
                                    color: selected
                                        ? Colors.orange
                                        : Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: Text(p.name,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.orange
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (selected)
                            const Icon(Icons.swap_horiz,
                                size: 12, color: Colors.orange),
                        ]),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Row(children: [
                            ..._roleBadge(p),
                            if (p.isWicketKeeper)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('WK',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Shared helpers
  List<Widget> _roleBadge(PlayerInfo p) {
    String? lbl;
    Color? col;
    if (p.role == PlayerRole.batter) {
      lbl = 'Bat'; col = const Color(0xFF2E7D32);
    } else if (p.role == PlayerRole.bowler && p.bowlerType != null) {
      lbl = p.bowlerType == BowlerType.fast ? 'Fas' : 'Spn';
      col = p.bowlerType == BowlerType.fast ? const Color(0xFFBF360C) : const Color(0xFF4527A0);
    } else if (p.role == PlayerRole.allRounder && p.bowlerType != null) {
      lbl = p.bowlerType == BowlerType.fast ? 'ARF' : 'ARS';
      col = p.bowlerType == BowlerType.fast ? const Color(0xFFBF360C) : const Color(0xFF6A1B9A);
    }
    if (lbl == null) return [];
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(color: col!, borderRadius: BorderRadius.circular(3)),
        child: Text(lbl,
            style: const TextStyle(
                color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 2),
    ];
  }

  Widget _chip(String label, bool active, Color color) => AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: active ? color : Colors.white10,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: active ? color : Colors.white24, width: 0.8),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.bold)),
      );

  // ── Bottom confirm bar
  Widget _buildBottomBar() {
    final label = _xi1.length != 11 || _xi2.length != 11
        ? 'Select 11 players per team'
        : !_wk1Ok || !_wk2Ok
            ? 'XI must include a Wicket Keeper'
            : !_cap1Ok || !_cap2Ok
                ? 'Tap C to set match captain'
                : 'Confirm XIs & Start Match';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      color: const Color(0xFF0D2B1E),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _StatusChip(
              name: widget.team1.name, count: _xi1.length,
              wkOk: _wk1Ok, capOk: _cap1Ok),
          const Spacer(),
          _StatusChip(
              name: widget.team2.name, count: _xi2.length,
              wkOk: _wk2Ok, capOk: _cap2Ok),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canConfirm ? _confirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              disabledBackgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(label),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Flying swap overlay — tiles animate across both columns
// ═══════════════════════════════════════════════════════════
class _FlyingSwap extends StatelessWidget {
  final AnimationController ctrl;
  final Rect xiRect;
  final Rect benchRect;
  final String xiName;
  final String benchName;

  const _FlyingSwap({
    required this.ctrl,
    required this.xiRect,
    required this.benchRect,
    required this.xiName,
    required this.benchName,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = Curves.easeInOutCubic.transform(ctrl.value);
        // Slight scale bump at mid-flight for a "jumping" feel
        final scale = 1.0 + 0.10 * sin(t * pi);

        // XI tile travels right → bench position
        final xiPos = Offset.lerp(xiRect.topLeft, benchRect.topLeft, t)!;
        // Bench tile travels left → XI position
        final bPos = Offset.lerp(benchRect.topLeft, xiRect.topLeft, t)!;

        return Stack(children: [
          // Absorb touches during animation
          Positioned.fill(child: GestureDetector(onTap: () {})),

          // XI player flying right (amber)
          Positioned(
            left: xiPos.dx,
            top: xiPos.dy,
            width: xiRect.width,
            height: xiRect.height,
            child: Transform.scale(
              scale: scale,
              child: _FlyTile(name: xiName, color: Colors.amber.shade700),
            ),
          ),

          // Bench player flying left (deep orange)
          Positioned(
            left: bPos.dx,
            top: bPos.dy,
            width: benchRect.width,
            height: benchRect.height,
            child: Transform.scale(
              scale: scale,
              child: _FlyTile(name: benchName, color: Colors.deepOrange.shade700),
            ),
          ),
        ]);
      },
    );
  }
}

class _FlyTile extends StatelessWidget {
  final String name;
  final Color color;
  const _FlyTile({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      elevation: 14,
      shadowColor: color.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Circular swap button
// ═══════════════════════════════════════════════════════════
class _SwapButton extends StatelessWidget {
  final bool canSwap, hasAny;
  final VoidCallback onTap;
  const _SwapButton(
      {required this.canSwap, required this.hasAny, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canSwap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: canSwap
              ? Colors.green.shade700
              : hasAny
                  ? Colors.amber.withOpacity(0.25)
                  : const Color(0xFF0D2B1E),
          border: Border.all(
            color: canSwap
                ? Colors.greenAccent
                : hasAny
                    ? Colors.amber.withOpacity(0.6)
                    : Colors.white24,
            width: 1.5,
          ),
          boxShadow: canSwap
              ? [
                  BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.35),
                      blurRadius: 10,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: Icon(
          Icons.swap_vert,
          size: 16,
          color: canSwap
              ? Colors.white
              : hasAny
                  ? Colors.amber
                  : Colors.white24,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Status chip
// ═══════════════════════════════════════════════════════════
class _StatusChip extends StatelessWidget {
  final String name;
  final int count;
  final bool wkOk, capOk;
  const _StatusChip(
      {required this.name,
      required this.count,
      required this.wkOk,
      required this.capOk});

  @override
  Widget build(BuildContext context) {
    final done = count == 11;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(done ? Icons.check_circle : Icons.people_outline,
            color: done ? Colors.greenAccent : Colors.white38, size: 13),
        const SizedBox(width: 4),
        Text('$name: $count/11',
            style: TextStyle(
                color: done ? Colors.greenAccent : Colors.white54,
                fontSize: 11,
                fontWeight: done ? FontWeight.bold : FontWeight.normal)),
      ]),
      if (done) ...[
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sports_cricket,
              color: wkOk ? const Color(0xFF1565C0) : Colors.redAccent,
              size: 12),
          const SizedBox(width: 3),
          Text(wkOk ? 'WK set' : 'No WK',
              style: TextStyle(
                  color: wkOk ? const Color(0xFF90CAF9) : Colors.redAccent,
                  fontSize: 10)),
        ]),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(capOk ? Icons.star : Icons.star_border,
              color: capOk ? const Color(0xFFF9A825) : Colors.white38,
              size: 12),
          const SizedBox(width: 3),
          Text(capOk ? 'Captain set' : 'No captain',
              style: TextStyle(
                  color: capOk ? const Color(0xFFF9A825) : Colors.white38,
                  fontSize: 10)),
        ]),
      ],
    ]);
  }
}
