import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models.dart';
import '../tournament_models.dart';
import '../services/live_session_service.dart';
import '../widgets/pulsing_dot.dart';

// ── Entry screen ──────────────────────────────────────────────────────────────

class WatchLiveScreen extends StatefulWidget {
  const WatchLiveScreen({super.key});
  @override
  State<WatchLiveScreen> createState() => _WatchLiveScreenState();
}

class _WatchLiveScreenState extends State<WatchLiveScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-character code');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final exists = await LiveSessionService.sessionExists(code);
    if (!mounted) return;
    if (!exists) {
      setState(() { _loading = false; _error = 'Code not found. Check with the scorer.'; });
      return;
    }
    setState(() => _loading = false);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _LiveDisplayScreen(code: code)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Watch Live',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_tethering, color: Colors.greenAccent, size: 56),
                const SizedBox(height: 20),
                const Text('Enter Live Code',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Ask the scorer for the 6-character code',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '······',
                    hintStyle: const TextStyle(
                        color: Colors.white24, fontSize: 28, letterSpacing: 8),
                    filled: true,
                    fillColor: const Color(0xFF0D2B1E),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green.shade700),
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderSide:
                            const BorderSide(color: Colors.greenAccent, width: 2),
                        borderRadius: BorderRadius.circular(12)),
                    errorText: _error,
                    errorStyle: const TextStyle(color: Colors.redAccent),
                  ),
                  onSubmitted: (_) => _join(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _join,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Watch'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Live display ──────────────────────────────────────────────────────────────

class _LiveDisplayScreen extends StatelessWidget {
  final String code;
  const _LiveDisplayScreen({required this.code});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveSessionService.watchSession(code),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1B3A2D),
            body: Center(
                child: CircularProgressIndicator(color: Colors.greenAccent)),
          );
        }
        final data = snap.data?.data();
        if (data == null) {
          return _errorScaffold('Session not found.');
        }

        final type = data['type'] as String? ?? 'match';
        final isActive = data['isActive'] as bool? ?? false;
        final hostName = data['hostName'] as String? ?? 'Host';
        final title = data['tournamentTitle'] as String?;

        final tickJson = data['liveTick'] as Map<String, dynamic>?;

        if (type == 'match') {
          final msJson = data['matchState'] as Map<String, dynamic>?;
          if (msJson == null) return _errorScaffold('No match data.');
          final ms = AppDatabase.matchStateFromJson(msJson);
          return _MatchLiveScaffold(
            ms: ms,
            tick: tickJson,
            hostName: hostName,
            isActive: isActive,
            code: code,
          );
        }

        // Tournament / series
        final tJson = data['tournamentState'] as Map<String, dynamic>?;
        if (tJson == null) return _errorScaffold('No tournament data.');
        final tournament = AppDatabase.tournamentFromJson(type, tJson);
        if (tournament == null) return _errorScaffold('Unknown session type.');

        final currentMatchJson = data['currentMatchState'] as Map<String, dynamic>?;
        final currentMatch = currentMatchJson != null
            ? AppDatabase.matchStateFromJson(currentMatchJson)
            : null;

        return _TournamentLiveScaffold(
          tournament: tournament,
          currentMatch: currentMatch,
          tick: tickJson,
          hostName: hostName,
          title: title,
          isActive: isActive,
          code: code,
        );
      },
    );
  }

  static Widget _errorScaffold(String msg) => Scaffold(
        backgroundColor: const Color(0xFF1B3A2D),
        body: Center(
          child: Text(msg,
              style: const TextStyle(color: Colors.white54, fontSize: 16)),
        ),
      );
}

// ── Match live scaffold ───────────────────────────────────────────────────────

class _MatchLiveScaffold extends StatelessWidget {
  final MatchState ms;
  final Map<String, dynamic>? tick;
  final String hostName;
  final bool isActive;
  final String code;

  const _MatchLiveScaffold({
    required this.ms,
    required this.tick,
    required this.hostName,
    required this.isActive,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF1B3A2D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2B1E),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(children: [
            if (isActive) ...[
              const PulsingDot(),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                '${ms.setup.team1Name} vs ${ms.setup.team2Name}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          bottom: const TabBar(
            labelColor: Colors.greenAccent,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.greenAccent,
            tabs: [
              Tab(text: 'Live Score'),
              Tab(text: 'Scorecard'),
              Tab(text: 'Squad'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _LiveScoreTab(ms: ms, tick: tick, isActive: isActive),
          _ScorecardTab(ms: ms),
          _SquadTab(teams: [
            _TeamSquad(ms.setup.team1Name, ms.team1Players),
            _TeamSquad(ms.setup.team2Name, ms.team2Players),
          ]),
        ]),
      ),
    );
  }
}

// ── Tournament live scaffold ──────────────────────────────────────────────────

class _TournamentLiveScaffold extends StatelessWidget {
  final AnyTournament tournament;
  final MatchState? currentMatch;
  final Map<String, dynamic>? tick;
  final String hostName;
  final String? title;
  final bool isActive;
  final String code;

  const _TournamentLiveScaffold({
    required this.tournament,
    required this.currentMatch,
    required this.tick,
    required this.hostName,
    required this.title,
    required this.isActive,
    required this.code,
  });

  String get _displayTitle {
    if (title != null) return title!;
    return switch (tournament) {
      SeriesHolder h =>
        '${h.state.teams[0].name} vs ${h.state.teams[1].name} Series',
      TriSeriesHolder _ => 'Tri-Series',
      BigTournamentHolder _ => 'Tournament',
      MultiFormatSeriesHolder h =>
        '${h.state.team1Name} vs ${h.state.team2Name}',
    };
  }

  List<TournamentTeam> get _teams => switch (tournament) {
        SeriesHolder h => h.state.teams,
        TriSeriesHolder h => h.state.teams,
        BigTournamentHolder h => h.state.teams,
        MultiFormatSeriesHolder h => h.state.teams,
      };

  @override
  Widget build(BuildContext context) {
    final isOver = switch (tournament) {
      SeriesHolder h => h.state.isComplete,
      TriSeriesHolder h => h.state.isComplete,
      BigTournamentHolder h => h.state.isComplete,
      MultiFormatSeriesHolder h => h.state.isComplete,
    };

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFF1B3A2D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2B1E),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(children: [
            if (isActive && !isOver) ...[
              const PulsingDot(),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(_displayTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          bottom: const TabBar(
            labelColor: Colors.greenAccent,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.greenAccent,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Score'),
              Tab(text: 'Points Table'),
              Tab(text: 'Stats'),
              Tab(text: 'Matches'),
              Tab(text: 'Squad'),
            ],
          ),
        ),
        body: TabBarView(children: [
          currentMatch != null
              ? _LiveScoreTab(ms: currentMatch!, tick: tick, isActive: isActive)
              : _NoMatchInProgress(isOver: isOver, tournament: tournament),
          _PointsTableTab(tournament: tournament),
          _StatsTab(tournament: tournament),
          _MatchesTab(tournament: tournament),
          _SquadTab(
              teams: _teams
                  .map((t) => _TeamSquad(t.name, t.players.map((pi) {
                        final p = Player(pi.name,
                            role: pi.role,
                            bowlerType: pi.bowlerType,
                            isCaptain: pi.isCaptain,
                            isWicketKeeper: pi.isWicketKeeper);
                        return p;
                      }).toList()))
                  .toList()),
        ]),
      ),
    );
  }
}

// ── Live Score tab ────────────────────────────────────────────────────────────

class _LiveScoreTab extends StatelessWidget {
  final MatchState ms;
  final Map<String, dynamic>? tick; // compact tick — preferred for instant updates
  final bool isActive;
  const _LiveScoreTab({required this.ms, required this.tick, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final t = tick;
    if (t != null) return _buildFromTick(t);
    return _buildFromMs();
  }

  // ── Tick-based build (fast path: ~300 byte payload already at viewer) ────────

  Widget _buildFromTick(Map<String, dynamic> t) {
    final runs    = t['r']   as int?    ?? 0;
    final wickets = t['w']   as int?    ?? 0;
    final balls   = t['b']   as int?    ?? 0;
    final target  = t['tg']  as int?    ?? 0;
    final bpi     = t['bpi'] as int?    ?? 120;
    final ci      = t['ci']  as int?    ?? 1;
    final matchOver   = t['mo']  as bool?   ?? false;
    final matchResult = t['mr']  as String? ?? '';
    final team1   = t['t1']  as String? ?? '';
    final team2   = t['t2']  as String? ?? '';
    final tbf     = t['tbf'] as bool?   ?? true;
    final sx  = t['sx']  as Map?;
    final nsx = t['nsx'] as Map?;
    final bw  = t['bw']  as Map?;
    final ballLog = (t['bl'] as List?)?.cast<String>() ?? <String>[];

    final isSecond   = ci == 2 || ci == 4;
    final isOddInnings = ci % 2 == 1;
    final battingTeam  = isOddInnings ? (tbf ? team1 : team2) : (tbf ? team2 : team1);
    final overs = balls ~/ 6;
    final rem   = balls % 6;

    final crr = balls > 0 ? (runs * 6 / balls).toStringAsFixed(2) : '0.00';
    String rrr = '—';
    if (isSecond && target > 0) {
      final left = bpi - balls;
      if (left > 0) {
        final needed = target - runs;
        rrr = needed <= 0 ? '0.00' : (needed * 6 / left).toStringAsFixed(2);
      }
    }

    final sxName  = sx?['n']  as String? ?? '';
    final sxRuns  = sx?['r']  as int?    ?? 0;
    final sxBalls = sx?['b']  as int?    ?? 0;
    final nsxName  = nsx?['n'] as String? ?? '';
    final nsxRuns  = nsx?['r'] as int?    ?? 0;
    final nsxBalls = nsx?['b'] as int?    ?? 0;
    final bwName    = bw?['n'] as String? ?? '';
    final bwWickets = bw?['w'] as int?    ?? 0;
    final bwRuns    = bw?['r'] as int?    ?? 0;
    final bwBalls   = bw?['b'] as int?    ?? 0;
    final bwOv = '${bwBalls ~/ 6}.${bwBalls % 6}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (matchOver) _resultBanner(matchResult),
        if (!matchOver && !isActive)
          _infoBanner('Session ended — showing last known score'),
        const SizedBox(height: 12),

        _card(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(battingTeam,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('BATTING', style: TextStyle(color: Colors.greenAccent.shade100, fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$runs/$wickets',
                style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, height: 1)),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('($overs.$rem ov)',
                  style: const TextStyle(color: Colors.white54, fontSize: 16)),
            ),
          ]),
          if (isSecond && target > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Need ${target - runs} off ${_ballsToOvers(bpi - balls)} ${bpi - balls == 1 ? "ball" : "balls"}',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Text('CRR: $crr', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (isSecond && target > 0) ...[
              const SizedBox(width: 16),
              Text('RRR: $rrr', style: const TextStyle(color: Colors.amber, fontSize: 12)),
            ],
          ]),
        ])),
        const SizedBox(height: 10),

        _card(
          label: 'BATTING',
          child: Column(children: [
            _tickBatterRow(sxName, sxRuns, sxBalls, isStriker: true),
            const Divider(color: Colors.white10, height: 16),
            _tickBatterRow(nsxName, nsxRuns, nsxBalls, isStriker: false),
          ]),
        ),
        const SizedBox(height: 10),

        _card(
          label: 'BOWLING',
          child: Row(children: [
            Expanded(child: Text(bwName,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
            Text('$bwWickets/$bwRuns',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('($bwOv ov)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 10),

        if (ballLog.isNotEmpty)
          _card(
            label: 'THIS OVER',
            child: Wrap(spacing: 6, runSpacing: 6,
                children: ballLog.map((b) => _ballChip(b)).toList()),
          ),
      ]),
    );
  }

  Widget _tickBatterRow(String name, int runs, int balls, {required bool isStriker}) =>
      Row(children: [
        SizedBox(
          width: 16,
          child: Text(isStriker ? '●' : '',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
        ),
        Expanded(child: Text(name,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
        Text('$runs',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('(${balls}b)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]);

  // ── MatchState-based build (fallback for sessions without liveTick) ──────────

  Widget _buildFromMs() {
    final inn = ms.currentInningsObj;
    final isSecond = ms.currentInnings == 2 || ms.currentInnings == 4;
    final target = ms.target;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ms.matchOver) _resultBanner(ms.matchResult),
        if (!ms.matchOver && !isActive)
          _infoBanner('Session ended — showing last known score'),
        const SizedBox(height: 12),

        // Score card
        _card(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(ms.battingTeamName,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text('BATTING', style: TextStyle(color: Colors.greenAccent.shade100, fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${inn.totalRuns}/${inn.wickets}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    height: 1)),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('(${inn.oversDisplay} ov)',
                  style: const TextStyle(color: Colors.white54, fontSize: 16)),
            ),
          ]),
          if (isSecond && target > 0) ...[
            const SizedBox(height: 6),
            _targetRow(ms, inn, target),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Text('CRR: ${_crr(inn)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (isSecond && target > 0) ...[
              const SizedBox(width: 16),
              Text('RRR: ${_rrr(ms, inn, target)}',
                  style: const TextStyle(color: Colors.amber, fontSize: 12)),
            ],
          ]),
        ])),
        const SizedBox(height: 10),

        // Batters
        _card(
          label: 'BATTING',
          child: Column(children: [
            _batterRow(inn.striker, isStriker: true),
            const Divider(color: Colors.white10, height: 16),
            _batterRow(inn.nonStriker, isStriker: false),
          ]),
        ),
        const SizedBox(height: 10),

        // Current bowler
        _card(
          label: 'BOWLING',
          child: _bowlerRow(inn.currentBowler),
        ),
        const SizedBox(height: 10),

        // Ball log
        if (inn.ballLog.isNotEmpty)
          _card(
            label: 'THIS OVER',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: inn.ballLog.map((b) => _ballChip(b)).toList(),
            ),
          ),
      ]),
    );
  }

  Widget _resultBanner(String result) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: Text(result,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      );

  Widget _infoBanner(String msg) => Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      );

  Widget _targetRow(MatchState ms, Innings inn, int target) {
    final ballsLeft = ms.setup.ballsPerInnings - inn.balls;
    final runsNeeded = target - inn.totalRuns;
    return Text(
      'Need $runsNeeded off ${_ballsToOvers(ballsLeft)} ${ballsLeft == 1 ? "ball" : "balls"}',
      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
    );
  }

  Widget _batterRow(Player p, {required bool isStriker}) => Row(children: [
        SizedBox(
          width: 16,
          child: Text(isStriker ? '●' : '',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
        ),
        Expanded(
          child: Text(
            p.name + (p.isCaptain ? ' (c)' : '') + (p.isWicketKeeper ? ' †' : ''),
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Text('${p.runsScored}',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('(${p.ballsFaced}b)',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]);

  Widget _bowlerRow(Player p) => Row(children: [
        Expanded(
          child: Text(p.name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Text('${p.wicketsTaken}/${p.runsConceded}',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text('(${_bowlerOvers(p)} ov)',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]);

  Widget _ballChip(String b) {
    Color bg;
    if (b == 'W') {
      bg = Colors.red.shade700;
    } else if (b == '4') {
      bg = Colors.blue.shade700;
    } else if (b == '6') {
      bg = Colors.amber.shade700;
    } else if (b.startsWith('Wd') || b.startsWith('Nb')) {
      bg = Colors.orange.shade700;
    } else {
      bg = Colors.white12;
    }
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(b,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _card({String? label, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2B1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null) ...[
            Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4)),
            const SizedBox(height: 10),
          ],
          child,
        ]),
      );

  String _crr(Innings inn) {
    if (inn.balls == 0) return '0.00';
    return (inn.totalRuns * 6 / inn.balls).toStringAsFixed(2);
  }

  String _rrr(MatchState ms, Innings inn, int target) {
    final ballsLeft = ms.setup.ballsPerInnings - inn.balls;
    if (ballsLeft <= 0) return '—';
    final needed = target - inn.totalRuns;
    if (needed <= 0) return '0.00';
    return (needed * 6 / ballsLeft).toStringAsFixed(2);
  }

  String _bowlerOvers(Player p) {
    final comp = p.ballsBowled ~/ 6;
    final rem = p.ballsBowled % 6;
    return '$comp.$rem';
  }

  String _ballsToOvers(int balls) {
    final ov = balls ~/ 6;
    final b = balls % 6;
    return b == 0 ? '$ov ov' : '$ov.$b ov';
  }
}

// ── Scorecard tab ─────────────────────────────────────────────────────────────

class _ScorecardTab extends StatelessWidget {
  final MatchState ms;
  const _ScorecardTab({required this.ms});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _InningsCard(label: '${ms.setup.team1Name} — 1st Innings', inn: ms.innings1, isFirst: true),
        const SizedBox(height: 14),
        _InningsCard(label: '${ms.setup.team2Name} — 2nd Innings', inn: ms.innings2, isFirst: false),
        if (ms.innings3 != null) ...[
          const SizedBox(height: 14),
          _InningsCard(label: '${ms.setup.team1Name} — 2nd Innings', inn: ms.innings3!, isFirst: true),
        ],
        if (ms.innings4 != null) ...[
          const SizedBox(height: 14),
          _InningsCard(label: '${ms.setup.team2Name} — 2nd Innings', inn: ms.innings4!, isFirst: false),
        ],
      ]),
    );
  }
}

class _InningsCard extends StatelessWidget {
  final String label;
  final Innings inn;
  final bool isFirst;
  const _InningsCard({required this.label, required this.inn, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final batted = inn.battingTeamPlayers.where((p) => p.hasPlayedInnings || p.isOut).toList();
    final bowled = inn.bowlingTeamPlayers.where((p) => p.ballsBowled > 0).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        const Divider(color: Colors.white10, height: 1),
        // Batting header
        _tableHeader(['BATTER', 'R', 'B', '4s', '6s', 'SR']),
        ...batted.map((p) => _batterTableRow(p)),
        const Divider(color: Colors.white10, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            const Expanded(child: Text('Extras',
                style: TextStyle(color: Colors.white54, fontSize: 12))),
            Text('${inn.totalExtras}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        const Divider(color: Colors.white10, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            const Expanded(child: Text('Total',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            Text('${inn.totalRuns}/${inn.wickets} (${inn.oversDisplay} ov)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
        if (bowled.isNotEmpty) ...[
          const Divider(color: Colors.white10, height: 1),
          _tableHeader(['BOWLER', 'O', 'M', 'R', 'W', 'Econ']),
          ...bowled.map((p) => _bowlerTableRow(p)),
        ],
      ]),
    );
  }

  Widget _tableHeader(List<String> cols) => Container(
        color: Colors.white.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Expanded(child: Text(cols[0],
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
          ...cols.skip(1).map((c) => SizedBox(
                width: 36,
                child: Text(c,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
              )),
        ]),
      );

  Widget _batterTableRow(Player p) {
    final sr = p.ballsFaced > 0
        ? (p.runsScored * 100 / p.ballsFaced).toStringAsFixed(1)
        : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name + (p.isCaptain ? ' (c)' : '') + (p.isWicketKeeper ? ' †' : ''),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          if (p.dismissalInfo.isNotEmpty)
            Text(p.dismissalInfo,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
                overflow: TextOverflow.ellipsis),
        ])),
        _cell('${p.runsScored}', bold: true),
        _cell('${p.ballsFaced}'),
        _cell('${p.fours}'),
        _cell('${p.sixes}'),
        _cell(sr),
      ]),
    );
  }

  Widget _bowlerTableRow(Player p) {
    final overs = '${p.ballsBowled ~/ 6}.${p.ballsBowled % 6}';
    final econ = p.ballsBowled > 0
        ? (p.runsConceded * 6 / p.ballsBowled).toStringAsFixed(1)
        : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(children: [
        Expanded(child: Text(p.name,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
        _cell(overs),
        _cell('${p.maidens}'),
        _cell('${p.runsConceded}'),
        _cell('${p.wicketsTaken}', bold: true),
        _cell(econ),
      ]),
    );
  }

  Widget _cell(String v, {bool bold = false}) => SizedBox(
        width: 36,
        child: Text(v,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: bold ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}

// ── Points Table tab ──────────────────────────────────────────────────────────

class _PointsTableTab extends StatelessWidget {
  final AnyTournament tournament;
  const _PointsTableTab({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: switch (tournament) {
        SeriesHolder h => _seriesTable(h.state),
        TriSeriesHolder h => _triSeriesTable(h.state),
        BigTournamentHolder h => _bigTable(h.state),
        MultiFormatSeriesHolder h => _mfsTable(h.state),
      },
    );
  }

  Widget _seriesTable(SeriesState s) {
    final t1wins = s.matches.where((m) => m.result?.winnerName == s.teams[0].name).length;
    final t2wins = s.matches.where((m) => m.result?.winnerName == s.teams[1].name).length;
    final played = s.matches.where((m) => m.result != null).length;
    return _tableCard('Series Standings', [
      _standingHeader(),
      _standingRow(s.teams[0].name, t1wins, played - t1wins - (played - t1wins - t2wins), played - t1wins - t2wins, t1wins * 2),
      _standingRow(s.teams[1].name, t2wins, played - t2wins - (played - t1wins - t2wins), played - t1wins - t2wins, t2wins * 2),
    ]);
  }

  Widget _triSeriesTable(TriSeriesState s) {
    final standings = s.standings;
    return _tableCard('League Standings', [
      _standingHeader(),
      ...standings.map((st) => _standingRow(
            st.teamName, st.won, st.lost, st.tied, st.points,
            nrr: st.nrr.toStringAsFixed(3))),
    ]);
  }

  Widget _bigTable(BigTournamentState s) {
    final groups = s.phase1Groups;
    final cols = <Widget>[];
    for (int gi = 0; gi < groups.length; gi++) {
      final label = groups.length == 1
          ? 'Standings'
          : 'Group ${String.fromCharCode(65 + gi)}';
      final standings = groups[gi].computedStandings(s.overs * (s.format == MatchFormat.hundred ? 5 : 6));
      cols.add(_tableCard(label, [
        _standingHeader(),
        ...standings.map((st) => _standingRow(
              st.teamName, st.won, st.lost, st.tied, st.points,
              nrr: st.nrr.toStringAsFixed(3))),
      ]));
      if (gi < groups.length - 1) cols.add(const SizedBox(height: 14));
    }
    return Column(children: cols);
  }

  Widget _mfsTable(MultiFormatSeriesState s) {
    final t1 = s.teams[0].name;
    final t2 = s.teams[1].name;
    final rows = s.segments.map((seg) {
      final t1w = seg.matches.where((m) => m.result?.winnerName == t1).length;
      final t2w = seg.matches.where((m) => m.result?.winnerName == t2).length;
      final played = seg.matches.where((m) => m.result != null).length;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(seg.formatLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Text('$t1w – $t2w',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('($played played)',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      );
    });
    return _tableCard('Series Scores', rows.toList());
  }

  Widget _tableCard(String title, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D2B1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const Divider(color: Colors.white10, height: 1),
          ...children.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: c)),
          const SizedBox(height: 8),
        ]),
      );

  Widget _standingHeader() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Expanded(child: Text('Team',
              style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          for (final h in ['P', 'W', 'L', 'T', 'Pts'])
            SizedBox(
              width: 32,
              child: Text(h,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 52),
        ]),
      );

  Widget _standingRow(String name, int w, int l, int t, int pts, {String? nrr}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis)),
          for (final v in [w + l + t, w, l, t, pts])
            SizedBox(
              width: 32,
              child: Text('$v',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: v == pts ? Colors.greenAccent : Colors.white70,
                      fontSize: 13,
                      fontWeight: v == pts ? FontWeight.bold : FontWeight.normal)),
            ),
          SizedBox(
            width: 52,
            child: Text(nrr != null ? 'NRR $nrr' : '',
                textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ]),
      );
}

// ── Matches tab ───────────────────────────────────────────────────────────────

class _MatchesTab extends StatelessWidget {
  final AnyTournament tournament;
  const _MatchesTab({required this.tournament});

  List<TournamentMatch> get _allMatches => switch (tournament) {
        SeriesHolder h => h.state.matches,
        TriSeriesHolder h => [
            ...h.state.leagueMatches,
            if (h.state.finalMatch != null) h.state.finalMatch!,
          ],
        BigTournamentHolder h => [
            for (final g in h.state.phase1Groups) ...g.matches,
            if (h.state.phase2Groups != null)
              for (final g in h.state.phase2Groups!) ...g.matches,
            if (h.state.sf1 != null) h.state.sf1!,
            if (h.state.sf2 != null) h.state.sf2!,
            if (h.state.finalMatch != null) h.state.finalMatch!,
          ],
        MultiFormatSeriesHolder h => [
            for (final seg in h.state.segments) ...seg.matches,
          ],
      };

  @override
  Widget build(BuildContext context) {
    final matches = _allMatches;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _MatchTile(match: matches[i]),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final TournamentMatch match;
  const _MatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final done = match.result != null;
    final r = match.result;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: done ? Colors.white12 : Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${match.team1Name} vs ${match.team2Name}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(match.phase,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            if (done && r != null) ...[
              const SizedBox(height: 4),
              Text(r.matchResult,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ],
          ]),
        ),
        if (!done)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
            ),
            child: const Text('In Progress',
                style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        if (done && r != null)
          _miniScore(r),
      ]),
    );
  }

  Widget _miniScore(MatchState r) {
    final inn1 = r.innings1;
    final inn2 = r.innings2;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${r.setup.team1Name}: ${inn1.totalRuns}/${inn1.wickets}',
          style: const TextStyle(color: Colors.white60, fontSize: 11)),
      Text('${r.setup.team2Name}: ${inn2.totalRuns}/${inn2.wickets}',
          style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]);
  }
}

// ── Squad tab ─────────────────────────────────────────────────────────────────

class _TeamSquad {
  final String name;
  final List<Player> players;
  _TeamSquad(this.name, this.players);
}

class _SquadTab extends StatefulWidget {
  final List<_TeamSquad> teams;
  const _SquadTab({required this.teams});
  @override
  State<_SquadTab> createState() => _SquadTabState();
}

class _SquadTabState extends State<_SquadTab> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.teams.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.teams.length, (i) {
                final sel = _idx == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _idx = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? Colors.green.shade700 : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? Colors.greenAccent : Colors.white24),
                      ),
                      child: Text(widget.teams[i].name,
                          style: TextStyle(
                              color: sel ? Colors.white : Colors.white60,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: widget.teams[_idx].players.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
          itemBuilder: (_, i) {
            final p = widget.teams[_idx].players[i];
            final tags = <String>[
              if (p.isCaptain) 'C',
              if (p.isWicketKeeper) 'WK',
            ];
            final roleLabel = switch (p.role) {
              PlayerRole.batter => 'BAT',
              PlayerRole.bowler => 'BOWL',
              PlayerRole.allRounder => 'AR',
            };
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.green.shade900,
                  child: Text('${i + 1}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(p.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                for (final tag in tags)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Text(tag,
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(roleLabel,
                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

// ── No match in progress ──────────────────────────────────────────────────────

class _NoMatchInProgress extends StatelessWidget {
  final bool isOver;
  final AnyTournament tournament;
  const _NoMatchInProgress({required this.isOver, required this.tournament});

  TournamentMatch? get _lastPlayed {
    final all = _StatsTab._allPlayedMatches(tournament);
    return all.isEmpty ? null : all.last;
  }

  @override
  Widget build(BuildContext context) {
    final last = _lastPlayed;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 16),
        if (isOver)
          _banner(Icons.emoji_events, Colors.amber, 'Tournament Completed')
        else
          _banner(Icons.hourglass_empty, Colors.white38, 'Break — No match in progress'),
        if (last != null) ...[
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('LAST RESULT',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4)),
          ),
          const SizedBox(height: 8),
          _MatchTile(match: last),
        ],
        const SizedBox(height: 20),
        const Text('View Points Table, Stats and Matches tabs for full details',
            style: TextStyle(color: Colors.white24, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _banner(IconData icon, Color color, String label) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Stats tab ─────────────────────────────────────────────────────────────────

class _AggStats {
  final String name;
  final String team;
  int battingInnings = 0;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  int hs = 0;
  int notOuts = 0;
  int wickets = 0;
  int runsConceded = 0;
  int ballsBowled = 0;
  int maidens = 0;

  _AggStats(this.name, this.team);

  double get avg {
    final outs = battingInnings - notOuts;
    return outs == 0 ? runs.toDouble() : runs / outs;
  }

  double get sr => balls == 0 ? 0 : runs * 100 / balls;
  double get economy =>
      ballsBowled == 0 ? 0 : runsConceded * 6 / ballsBowled;
  String get oversStr => '${ballsBowled ~/ 6}.${ballsBowled % 6}';
}

class _StatsTab extends StatefulWidget {
  final AnyTournament tournament;
  const _StatsTab({required this.tournament});

  static List<TournamentMatch> _allPlayedMatches(AnyTournament t) {
    final out = <TournamentMatch>[];
    switch (t) {
      case SeriesHolder h:
        out.addAll(h.state.matches.where((m) => m.result != null));
      case TriSeriesHolder h:
        out.addAll(h.state.leagueMatches.where((m) => m.result != null));
        if (h.state.finalMatch?.result != null) out.add(h.state.finalMatch!);
      case BigTournamentHolder h:
        for (final g in h.state.phase1Groups) {
          out.addAll(g.matches.where((m) => m.result != null));
        }
        if (h.state.phase2Groups != null) {
          for (final g in h.state.phase2Groups!) {
            out.addAll(g.matches.where((m) => m.result != null));
          }
        }
        if (h.state.sf1?.result != null) out.add(h.state.sf1!);
        if (h.state.sf2?.result != null) out.add(h.state.sf2!);
        if (h.state.finalMatch?.result != null) out.add(h.state.finalMatch!);
      case MultiFormatSeriesHolder h:
        for (final seg in h.state.segments) {
          out.addAll(seg.matches.where((m) => m.result != null));
        }
    }
    return out;
  }

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  bool _showBatting = true;

  Map<String, _AggStats> _buildAgg() {
    final map = <String, _AggStats>{};
    for (final match in _StatsTab._allPlayedMatches(widget.tournament)) {
      final r = match.result!;
      _processPlayers(r.team1Players, r.setup.team1Name, map);
      _processPlayers(r.team2Players, r.setup.team2Name, map);
    }
    return map;
  }

  void _processPlayers(
      List<Player> players, String team, Map<String, _AggStats> map) {
    for (final p in players) {
      final key = '${p.name}|$team';
      final agg = map.putIfAbsent(key, () => _AggStats(p.name, team));
      if (p.hasPlayedInnings || p.runsScored > 0) {
        agg.battingInnings++;
        agg.runs += p.runsScored;
        agg.balls += p.ballsFaced;
        agg.fours += p.fours;
        agg.sixes += p.sixes;
        if (p.runsScored > agg.hs) agg.hs = p.runsScored;
        if (!p.isOut) agg.notOuts++;
      }
      if (p.ballsBowled > 0) {
        agg.wickets += p.wicketsTaken;
        agg.runsConceded += p.runsConceded;
        agg.ballsBowled += p.ballsBowled;
        agg.maidens += p.maidens;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agg = _buildAgg();
    if (agg.isEmpty) {
      return const Center(
        child: Text('No matches played yet',
            style: TextStyle(color: Colors.white38, fontSize: 15)),
      );
    }

    final all = agg.values.toList();
    final batters = all
        .where((s) => s.battingInnings > 0)
        .toList()
      ..sort((a, b) => b.runs.compareTo(a.runs));
    final bowlers = all
        .where((s) => s.ballsBowled > 0)
        .toList()
      ..sort((a, b) {
        final wDiff = b.wickets.compareTo(a.wickets);
        if (wDiff != 0) return wDiff;
        return a.economy.compareTo(b.economy);
      });

    return Column(children: [
      // Toggle
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showBatting = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _showBatting
                      ? Colors.green.shade700
                      : Colors.white10,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10)),
                  border: Border.all(
                      color: _showBatting
                          ? Colors.greenAccent
                          : Colors.white24),
                ),
                child: Text('Batting',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _showBatting ? Colors.white : Colors.white54,
                        fontWeight: _showBatting
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showBatting = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_showBatting
                      ? Colors.green.shade700
                      : Colors.white10,
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(10)),
                  border: Border.all(
                      color: !_showBatting
                          ? Colors.greenAccent
                          : Colors.white24),
                ),
                child: Text('Bowling',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: !_showBatting ? Colors.white : Colors.white54,
                        fontWeight: !_showBatting
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13)),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      // Header
      _showBatting
          ? _battingHeader()
          : _bowlingHeader(),
      const Divider(color: Colors.white10, height: 1),
      // Rows
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount:
              _showBatting ? batters.length : bowlers.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (_, i) => _showBatting
              ? _battingRow(batters[i], i + 1)
              : _bowlingRow(bowlers[i], i + 1),
        ),
      ),
    ]);
  }

  Widget _battingHeader() => Container(
        color: Colors.white.withValues(alpha: 0.04),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(children: [
          const SizedBox(width: 22),
          const Expanded(
              child: Text('BATTER',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
          for (final h in ['Inn', 'Runs', 'HS', 'Avg', 'SR', '4s', '6s'])
            _hCell(h),
        ]),
      );

  Widget _bowlingHeader() => Container(
        color: Colors.white.withValues(alpha: 0.04),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(children: [
          const SizedBox(width: 22),
          const Expanded(
              child: Text('BOWLER',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
          for (final h in ['Wkt', 'Ov', 'Runs', 'Econ', 'Mdn'])
            _hCell(h),
        ]),
      );

  Widget _battingRow(_AggStats s, int rank) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          SizedBox(
            width: 22,
            child: Text('$rank',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text(s.team,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
          _dCell('${s.battingInnings}'),
          _dCell('${s.runs}', bold: true, color: Colors.greenAccent),
          _dCell('${s.hs}'),
          _dCell(s.avg.toStringAsFixed(1)),
          _dCell(s.sr.toStringAsFixed(1)),
          _dCell('${s.fours}'),
          _dCell('${s.sixes}'),
        ]),
      );

  Widget _bowlingRow(_AggStats s, int rank) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          SizedBox(
            width: 22,
            child: Text('$rank',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text(s.team,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
          _dCell('${s.wickets}', bold: true, color: Colors.greenAccent),
          _dCell(s.oversStr),
          _dCell('${s.runsConceded}'),
          _dCell(s.economy.toStringAsFixed(2)),
          _dCell('${s.maidens}'),
        ]),
      );

  Widget _hCell(String h) => SizedBox(
        width: 38,
        child: Text(h,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

  Widget _dCell(String v,
          {bool bold = false, Color color = Colors.white70}) =>
      SizedBox(
        width: 38,
        child: Text(v,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: bold ? color : Colors.white70,
                fontSize: 12,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
      );
}
