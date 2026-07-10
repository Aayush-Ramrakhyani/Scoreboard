import 'package:flutter/material.dart';
import '../models.dart';
import '../tournament_models.dart';
import 'playing_xi_screen.dart';
import 'toss_screen.dart';

class TournamentHomeScreen extends StatefulWidget {
  final AnyTournament tournament;
  const TournamentHomeScreen({super.key, required this.tournament});
  @override
  State<TournamentHomeScreen> createState() => _TournamentHomeScreenState();
}

class _TournamentHomeScreenState extends State<TournamentHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  List<TournamentTeam> get _allTeams => switch (widget.tournament) {
        SeriesHolder h => h.state.teams,
        TriSeriesHolder h => h.state.teams,
        BigTournamentHolder h => h.state.teams,
        MultiFormatSeriesHolder h => h.state.teams,
      };

  MatchFormat get _format => switch (widget.tournament) {
        SeriesHolder h => h.state.format,
        TriSeriesHolder h => h.state.format,
        BigTournamentHolder h => h.state.format,
        MultiFormatSeriesHolder _ => MatchFormat.t20, // overridden per match
      };

  int get _days => switch (widget.tournament) {
        SeriesHolder h => h.state.days,
        _ => 5,
      };

  TournamentTeam _getTeam(String name) =>
      _allTeams.firstWhere((t) => t.name == name);

  String get _title => switch (widget.tournament) {
        SeriesHolder h =>
          '${h.state.teams[0].name} vs ${h.state.teams[1].name} Series',
        TriSeriesHolder _ => 'Tri-Series',
        BigTournamentHolder _ => 'Tournament',
        MultiFormatSeriesHolder h =>
          '${h.state.team1Name} vs ${h.state.team2Name}',
      };

  bool get _isOver => switch (widget.tournament) {
        SeriesHolder h => h.state.isComplete,
        TriSeriesHolder h => h.state.isComplete,
        BigTournamentHolder h => h.state.isComplete,
        MultiFormatSeriesHolder h => h.state.isComplete,
      };

  String get _resultBanner => switch (widget.tournament) {
        SeriesHolder h => h.state.seriesResult,
        TriSeriesHolder h =>
          h.state.isComplete ? '${h.state.champion} wins the Tri-Series!' : '',
        BigTournamentHolder h =>
          h.state.isComplete ? '${h.state.champion} wins the Tournament!' : '',
        MultiFormatSeriesHolder h =>
          h.state.isComplete ? h.state.overallResult : '',
      };

  // ── match play ────────────────────────────────────────────────────────────

  void _playMatch(TournamentMatch match) {
    final t1 = _getTeam(match.team1Name);
    final t2 = _getTeam(match.team2Name);

    // Multi-format series: each match may have a different format/days
    MatchFormat matchFormat = _format;
    int matchDays = _days;
    if (widget.tournament case MultiFormatSeriesHolder h) {
      final seg = h.state.segmentFor(match);
      if (seg != null) {
        matchFormat = seg.format;
        matchDays = seg.days;
      }
    }

    void onComplete(MatchState ms) {
      setState(() {
        match.result = ms;
        _tryAdvance();
      });
    }

    // Full squad (18–21 players): show Playing XI selection before the toss
    if (t1.players.length > 11) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/tournament'),
          builder: (_) => PlayingXIScreen(
            team1: t1,
            team2: t2,
            format: matchFormat,
            days: matchDays,
            matchLabel: match.phase,
            onMatchComplete: onComplete,
          ),
        ),
      );
      return;
    }

    final setup = MatchSetup(
      team1Name: t1.name,
      team2Name: t2.name,
      team1Players: t1.players,
      team2Players: t2.players,
      format: matchFormat,
      days: matchDays,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/tournament'),
        builder: (_) => TossScreen(
          setup: setup,
          onMatchComplete: onComplete,
        ),
      ),
    );
  }

  void _tryAdvance() {
    switch (widget.tournament) {
      case TriSeriesHolder h:
        h.state.trySetupFinal();
      case BigTournamentHolder h:
        final s = h.state;
        if (s.phase1Complete &&
            s.phase2Groups == null &&
            s.sf1 == null &&
            s.finalMatch == null) {
          s.tryAdvancePhase1();
        }
        if (s.phase2Groups != null && s.phase2Complete && s.sf1 == null) {
          s.tryAdvancePhase2();
        }
        if (s.semisReady && s.semisComplete && s.finalMatch == null) {
          s.trySetupFinal();
        }
      case SeriesHolder _:
        break;
      case MultiFormatSeriesHolder _:
        break; // sequential play handled by isMatchPlayable; no phase advancement needed
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B1E),
        title: Text(_title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.greenAccent,
          tabs: const [Tab(text: 'Schedule'), Tab(text: 'Standings')],
        ),
      ),
      body: Column(children: [
        if (_isOver && _resultBanner.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            color: Colors.amber.shade900.withOpacity(0.4),
            child: Text(_resultBanner,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [_buildSchedule(), _buildStandings()],
          ),
        ),
      ]),
    );
  }

  // ── schedule tab ──────────────────────────────────────────────────────────

  Widget _buildSchedule() {
    if (widget.tournament case MultiFormatSeriesHolder h) {
      return _buildMultiFormatSchedule(h.state);
    }
    final sections = _buildSections();
    if (sections.isEmpty) {
      return const Center(
          child: Text('No matches yet', style: TextStyle(color: Colors.white54)));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: sections.expand((s) => [
            _sectionHeader(s.$1),
            ...s.$2.map(_matchCard),
            const SizedBox(height: 8),
          ]).toList(),
    );
  }

  Widget _buildMultiFormatSchedule(MultiFormatSeriesState state) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: state.segments.expand((seg) => [
            _segmentSectionHeader(seg),
            ...seg.matches.map(_matchCard),
            const SizedBox(height: 12),
          ]).toList(),
    );
  }

  Widget _segmentSectionHeader(FormatSegment seg) {
    final winner = seg.winner;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(children: [
        Expanded(
          child: Text(
            '${seg.formatLabel} SERIES (${seg.playedCount}/${seg.matchCount})',
            style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5),
          ),
        ),
        if (winner != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: winner.isEmpty
                  ? Colors.grey.shade700
                  : Colors.amber.shade800,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              winner.isEmpty ? 'TIED' : '$winner WON',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
      ]),
    );
  }

  // Returns the ordered match list for the current active phase (used for sequential play)
  List<TournamentMatch> _getCurrentSchedule() {
    switch (widget.tournament) {
      case SeriesHolder h:
        return h.state.matches;
      case TriSeriesHolder h:
        if (!h.state.leagueComplete) return h.state.leagueMatches;
        if (h.state.finalMatch != null) return [h.state.finalMatch!];
        return [];
      case BigTournamentHolder h:
        final s = h.state;
        if (!s.phase1Complete) return s.phase1Schedule;
        if (s.phase2Groups != null && !s.phase2Complete) return s.phase2Schedule;
        final knockouts = <TournamentMatch>[];
        if (s.sf1 != null) knockouts.add(s.sf1!);
        if (s.sf2 != null) knockouts.add(s.sf2!);
        if (s.finalMatch != null) knockouts.add(s.finalMatch!);
        return knockouts;
      case MultiFormatSeriesHolder h:
        for (final seg in h.state.segments) {
          if (!seg.isComplete) return seg.matches;
        }
        return [];
    }
  }

  bool _isPlayable(TournamentMatch match) {
    if (match.isPlayed) return false;
    if (widget.tournament case MultiFormatSeriesHolder h) {
      return h.state.isMatchPlayable(match);
    }
    final schedule = _getCurrentSchedule();
    if (schedule.isEmpty) return false;
    final firstUnplayed = schedule.firstWhere((m) => !m.isPlayed, orElse: () => match);
    return identical(firstUnplayed, match);
  }

  List<(String, List<TournamentMatch>)> _buildSections() {
    switch (widget.tournament) {
      case SeriesHolder h:
        return [('SCHEDULE', h.state.matches)];

      case TriSeriesHolder h:
        final sections = <(String, List<TournamentMatch>)>[
          ('LEAGUE MATCHES', h.state.leagueMatches),
        ];
        if (h.state.finalMatch != null) {
          sections.add(('FINAL', [h.state.finalMatch!]));
        }
        return sections;

      case BigTournamentHolder h:
        final s = h.state;
        final sections = <(String, List<TournamentMatch>)>[];
        sections.add(('GROUP STAGE', s.phase1Schedule));
        if (s.phase2Groups != null) {
          sections.add(('SUPER GROUPS', s.phase2Schedule));
        }
        final sfMatches = <TournamentMatch>[];
        if (s.sf1 != null) sfMatches.add(s.sf1!);
        if (s.sf2 != null) sfMatches.add(s.sf2!);
        if (sfMatches.isNotEmpty) sections.add(('SEMI-FINALS', sfMatches));
        if (s.finalMatch != null) sections.add(('FINAL', [s.finalMatch!]));
        return sections;

      case MultiFormatSeriesHolder _:
        return []; // multi-format schedule built directly in _buildSchedule
    }
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(title,
            style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
      );

  Widget _matchCard(TournamentMatch match) {
    final playable = _isPlayable(match);
    final locked = !match.isPlayed && !playable;
    // Show group label on interleaved cards (Group A / Super Group 1 etc.)
    final showLabel = match.phase.startsWith('Group') || match.phase.startsWith('Super');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: playable
                ? Colors.greenAccent.withOpacity(0.35)
                : Colors.white10),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showLabel)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(match.phase,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
            Row(children: [
              Flexible(
                child: Text(match.team1Name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: match.isPlayed && match.winnerName == match.team1Name
                            ? Colors.greenAccent
                            : locked
                                ? Colors.white38
                                : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('vs',
                    style: TextStyle(
                        color: locked ? Colors.white24 : Colors.white38,
                        fontSize: 12)),
              ),
              Flexible(
                child: Text(match.team2Name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: match.isPlayed && match.winnerName == match.team2Name
                            ? Colors.greenAccent
                            : locked
                                ? Colors.white38
                                : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ]),
            if (match.isPlayed) ...[
              const SizedBox(height: 4),
              Text(match.result!.matchResult,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        if (playable)
          ElevatedButton(
            onPressed: () => _playMatch(match),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Play'),
          )
        else if (locked)
          const Icon(Icons.lock_outline, color: Colors.white24, size: 20)
        else
          const Icon(Icons.check_circle_outline,
              color: Colors.greenAccent, size: 22),
      ]),
    );
  }

  // ── standings tab ─────────────────────────────────────────────────────────

  Widget _buildStandings() {
    switch (widget.tournament) {
      case SeriesHolder h:
        return _buildSeriesStandings(h.state);
      case TriSeriesHolder h:
        return _buildPointsTablePage([
          ('TRI-SERIES STANDINGS', h.state.standings)
        ]);
      case BigTournamentHolder h:
        return _buildBigTournamentStandings(h.state);
      case MultiFormatSeriesHolder h:
        return _buildMultiFormatStandings(h.state);
    }
  }

  Widget _buildSeriesStandings(SeriesState state) {
    final w1 = state.winsFor(state.teams[0].name);
    final w2 = state.winsFor(state.teams[1].name);
    final played =
        state.matches.where((m) => m.isPlayed).length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sectionHeader('SERIES RECORD'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2B1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _seriesTeamCol(state.teams[0].name, w1,
                      w1 > w2 && state.isComplete),
                  Column(children: [
                    Text('$played/${state.totalMatches}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                    const Text('played',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                  _seriesTeamCol(state.teams[1].name, w2,
                      w2 > w1 && state.isComplete),
                ],
              ),
            ),
            if (state.isComplete) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amber.withOpacity(0.4)),
                ),
                child: Text(state.seriesResult,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _seriesTeamCol(String name, int wins, bool isWinner) => Column(children: [
        Text(name,
            style: TextStyle(
                color: isWinner ? Colors.greenAccent : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 8),
        Text('$wins',
            style: TextStyle(
                color: isWinner ? Colors.greenAccent : Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold)),
        const Text('wins',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]);

  Widget _buildBigTournamentStandings(BigTournamentState s) {
    final sections = <(String, List<TeamStanding>)>[];
    for (final g in s.phase1Groups) {
      sections.add((g.name.toUpperCase(), g.computedStandings(s.ballsPerInnings)));
    }
    if (s.phase2Groups != null) {
      for (final g in s.phase2Groups!) {
        sections.add((g.name.toUpperCase(), g.computedStandings(s.ballsPerInnings)));
      }
    }
    return _buildPointsTablePage(sections);
  }

  Widget _buildPointsTablePage(
      List<(String, List<TeamStanding>)> sections) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: sections.expand((s) => [
            _sectionHeader(s.$1),
            _pointsTable(s.$2),
            const SizedBox(height: 16),
          ]).toList(),
    );
  }

  Widget _pointsTable(List<TeamStanding> standings) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(0.7),
          2: FlexColumnWidth(0.7),
          3: FlexColumnWidth(0.7),
          4: FlexColumnWidth(0.7),
          5: FlexColumnWidth(1.4),
          6: FlexColumnWidth(0.7),
        },
        children: [
          TableRow(
            decoration:
                BoxDecoration(color: Colors.green.shade900.withOpacity(0.5)),
            children: ['Team', 'P', 'W', 'L', 'T', 'NRR', 'Pts']
                .map((h) => _th(h))
                .toList(),
          ),
          ...standings.asMap().entries.map((e) {
            final s = e.value;
            final isFirst = e.key == 0;
            return TableRow(
              decoration: BoxDecoration(
                  color: isFirst
                      ? Colors.greenAccent.withOpacity(0.06)
                      : e.key.isOdd
                          ? Colors.white.withOpacity(0.02)
                          : Colors.transparent),
              children: [
                _td(s.teamName, bold: true),
                _td('${s.played}'),
                _td('${s.won}'),
                _td('${s.lost}'),
                _td('${s.tied}'),
                _td(s.nrrDisplay,
                    color: s.nrr >= 0 ? Colors.greenAccent : Colors.redAccent),
                _td('${s.points}', bold: true),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _td(String text, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );

  // ── Multi-Format Series standings ─────────────────────────────────────────

  Widget _buildMultiFormatStandings(MultiFormatSeriesState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.isComplete) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Text(state.overallResult,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ],
        ...state.segments.expand((seg) => [
              _sectionHeader('${seg.formatLabel} SERIES'),
              const SizedBox(height: 8),
              _segmentStandingCard(seg),
              const SizedBox(height: 16),
            ]),
      ],
    );
  }

  Widget _segmentStandingCard(FormatSegment seg) {
    final w1 = seg.winsFor(seg.team1Name);
    final w2 = seg.winsFor(seg.team2Name);
    final winner = seg.winner;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _seriesTeamCol(seg.team1Name, w1, winner == seg.team1Name),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${seg.playedCount}/${seg.matchCount}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              Text(seg.isComplete ? 'complete' : 'played',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              if (seg.ties > 0) ...[
                const SizedBox(height: 4),
                Text('${seg.ties} tied',
                    style: const TextStyle(color: Colors.orange, fontSize: 10)),
              ],
            ]),
            _seriesTeamCol(seg.team2Name, w2, winner == seg.team2Name),
          ],
        ),
        if (winner != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: winner.isEmpty
                  ? Colors.grey.shade800.withOpacity(0.3)
                  : Colors.green.shade800.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(seg.resultText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ]),
    );
  }
}
