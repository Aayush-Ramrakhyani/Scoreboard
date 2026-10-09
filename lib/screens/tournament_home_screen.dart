import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../models.dart';
import '../tournament_models.dart';
import '../database/app_database.dart';
import '../database/history_database.dart';
import '../services/motm_service.dart';
import '../services/live_session_service.dart';
import '../services/template_service.dart';
import '../services/tournament_history_service.dart';
import '../widgets/pulsing_dot.dart';
import 'playing_xi_screen.dart';
import 'scorecard_screen.dart';
import 'toss_screen.dart';

class TournamentHomeScreen extends StatefulWidget {
  final AnyTournament tournament;
  final String? customTitle;
  final String? firestoreId; // pass when resuming so history entry is reused
  final bool isResume; // true when loading saved data; false when starting fresh
  const TournamentHomeScreen({
    super.key,
    required this.tournament,
    this.customTitle,
    this.firestoreId,
    this.isResume = false,
  });
  @override
  State<TournamentHomeScreen> createState() => _TournamentHomeScreenState();
}

class _TournamentHomeScreenState extends State<TournamentHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late String _firestoreId;
  int _squadTeamIdx = 0;
  int _statsCategory = 0;
  String? _liveCode;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _firestoreId = widget.firestoreId ?? TournamentHistoryService.newId();
    if (!widget.isResume) {
      // Immediately overwrite the active-tournament slot with this fresh state.
      // Without this, going back before playing a match leaves stale old data
      // in storage, causing phantom results on the next Resume.
      AppDatabase.saveTournament(widget.tournament);
      TemplateService.saveTournamentProgress(widget.tournament,
          title: widget.customTitle, firestoreId: _firestoreId);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _goLive() async {
    if (_liveCode != null) {
      _showLiveCodeDialog(_liveCode!);
      return;
    }
    final code = await LiveSessionService.createTournamentSession(
      widget.tournament,
      title: widget.customTitle,
    );
    if (!mounted) return;
    setState(() => _liveCode = code);
    _showLiveCodeDialog(code);
  }

  void _showLiveCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2B1E),
        title: const Text('Live Code',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share this code with viewers:',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent, width: 2),
            ),
            child: Text(code,
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8)),
          ),
          const SizedBox(height: 12),
          const Text('Viewers: open app → Watch Live → enter code',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')));
              }
            },
            child: const Text('Copy', style: TextStyle(color: Colors.greenAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LiveSessionService.endSession(code);
              if (mounted) setState(() => _liveCode = null);
            },
            child: const Text('Stop Live', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  List<TournamentTeam> get _allTeams => switch (widget.tournament) {
        SeriesHolder h => h.state.teams,
        TriSeriesHolder h => h.state.teams,
        BigTournamentHolder h => h.state.teams,
        MultiFormatSeriesHolder h => h.state.teams,
        InternationalCupHolder h => h.state.teams,
      };

  MatchFormat get _format => switch (widget.tournament) {
        SeriesHolder h => h.state.format,
        TriSeriesHolder h => h.state.format,
        BigTournamentHolder h => h.state.format,
        MultiFormatSeriesHolder _ => MatchFormat.t20, // overridden per match
        InternationalCupHolder h => h.state.format,
      };

  int get _days => switch (widget.tournament) {
        SeriesHolder h => h.state.days,
        _ => 5,
      };

  TournamentTeam _getTeam(String name) =>
      _allTeams.firstWhere((t) => t.name == name);

  String get _title {
    if (widget.customTitle != null) return widget.customTitle!;
    return switch (widget.tournament) {
      SeriesHolder h =>
        '${h.state.teams[0].name} vs ${h.state.teams[1].name} Series',
      TriSeriesHolder _ => 'Tri-Series',
      BigTournamentHolder _ => 'Tournament',
      MultiFormatSeriesHolder h =>
        '${h.state.team1Name} vs ${h.state.team2Name}',
      InternationalCupHolder h => h.state.title,
    };
  }

  bool get _isOver => switch (widget.tournament) {
        SeriesHolder h => h.state.isComplete,
        TriSeriesHolder h => h.state.isComplete,
        BigTournamentHolder h => h.state.isComplete,
        MultiFormatSeriesHolder h => h.state.isComplete,
        InternationalCupHolder h => h.state.isComplete,
      };

  String get _resultBanner => switch (widget.tournament) {
        SeriesHolder h => h.state.seriesResult,
        TriSeriesHolder h =>
          h.state.isComplete ? '${h.state.champion} wins the Tri-Series!' : '',
        BigTournamentHolder h =>
          h.state.isComplete ? '${h.state.champion} wins the Tournament!' : '',
        MultiFormatSeriesHolder h =>
          h.state.isComplete ? h.state.overallResult : '',
        InternationalCupHolder h =>
          h.state.isComplete ? '${h.state.champion} wins the ${h.state.title}!' : '',
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
      if (_isOver) {
        AppDatabase.clearTournament();
        HistoryDatabase.addTournament(widget.tournament);
        TemplateService.clearTournamentProgress();
      } else {
        AppDatabase.saveTournament(widget.tournament);
        TemplateService.saveTournamentProgress(widget.tournament,
            title: widget.customTitle, firestoreId: _firestoreId);
      }
      TournamentHistoryService.save(
        _firestoreId,
        widget.tournament,
        title: widget.customTitle,
        isComplete: _isOver,
      );
      final code = _liveCode;
      if (code != null) {
        LiveSessionService.pushTournamentState(code, widget.tournament,
            title: widget.customTitle);
      }
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
      case InternationalCupHolder h:
        final s = h.state;
        s.tryAdvancePhase1();
        if (s.phase2Groups != null) s.tryAdvancePhase2();
        s.trySetupFinal();
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
        actions: [
          if (!_isOver)
            _liveCode != null
                ? GestureDetector(
                    onTap: _goLive,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const PulsingDot(),
                        const SizedBox(width: 5),
                        Text(_liveCode!,
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ]),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.wifi_tethering, color: Colors.white54),
                    tooltip: 'Go Live',
                    onPressed: _goLive,
                  ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.greenAccent,
          tabs: const [Tab(text: 'Schedule'), Tab(text: 'Standings'), Tab(text: 'Squads'), Tab(text: 'Stats')],
        ),
      ),
      body: Column(children: [
        if (_isOver && _resultBanner.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            color: Colors.amber.shade900.withValues(alpha:0.4),
            child: Text(_resultBanner,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ),
        if (_isOver) _buildMottBanner(),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [_buildSchedule(), _buildStandings(), _buildSquads(), _buildStats()],
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
      case InternationalCupHolder h:
        final s = h.state;
        if (!s.phase1Complete) return s.phase1Schedule;
        if (s.phase2Groups != null && !s.phase2Complete) return s.phase2Schedule;
        final knockouts = <TournamentMatch>[];
        if (s.sf1 != null) knockouts.add(s.sf1!);
        if (s.sf2 != null) knockouts.add(s.sf2!);
        if (s.finalMatch != null) knockouts.add(s.finalMatch!);
        return knockouts;
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

      case InternationalCupHolder h:
        final s = h.state;
        final sections = <(String, List<TournamentMatch>)>[];
        sections.add(('GROUP STAGE', s.phase1Schedule));
        if (s.phase2Groups != null) {
          sections.add(('SUPER STAGE', s.phase2Schedule));
        }
        final sfMatches = <TournamentMatch>[];
        if (s.sf1 != null) sfMatches.add(s.sf1!);
        if (s.sf2 != null) sfMatches.add(s.sf2!);
        if (sfMatches.isNotEmpty) sections.add(('SEMI-FINALS', sfMatches));
        if (s.finalMatch != null) sections.add(('FINAL', [s.finalMatch!]));
        return sections;
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
                ? Colors.greenAccent.withValues(alpha:0.35)
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
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScorecardScreen(state: match.result!),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.analytics_outlined, color: Colors.greenAccent, size: 14),
                SizedBox(width: 4),
                Text('Score', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
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
      case InternationalCupHolder h:
        return _buildCupStandings(h.state);
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
                  color: Colors.amber.shade900.withValues(alpha:0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha:0.4)),
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
                BoxDecoration(color: Colors.green.shade900.withValues(alpha:0.5)),
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
                      ? Colors.greenAccent.withValues(alpha:0.06)
                      : e.key.isOdd
                          ? Colors.white.withValues(alpha:0.02)
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
              color: Colors.amber.shade900.withValues(alpha:0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha:0.4)),
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

  // ── stats tab ─────────────────────────────────────────────────────────────

  static const _kStatCats = [
    (0, 'Most Runs',     true ),
    (1, 'Highest Score', true ),
    (2, 'Most Fours',    true ),
    (3, 'Most Sixes',    true ),
    (4, 'Most Hundreds', true ),
    (5, 'Most Fifties',  true ),
    (6, 'Most Wickets',  false),
    (7, 'Most 5W Hauls', false),
    (8, 'Best Bowling',  false),
  ];

  // ── International Cup standings ───────────────────────────────────────────

  Widget _buildCupStandings(InternationalCupState s) {
    final groups = [
      ...s.phase1Groups,
      ...?s.phase2Groups,
    ];
    final knockouts = [s.sf1, s.sf2, s.finalMatch].whereType<TournamentMatch>().where((m) => m.isPlayed).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final group in groups) ...[
          _sectionHeader(group.name),
          const SizedBox(height: 6),
          _pointsTable(group.computedStandings(s.ballsPerInnings)),
          const SizedBox(height: 14),
        ],
        if (knockouts.isNotEmpty) ...[
          _sectionHeader('KNOCKOUTS'),
          const SizedBox(height: 6),
          for (final m in knockouts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2B1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.phase, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${m.winnerName} won', style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(m.result!.matchResult, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ),
            ),
        ],
      ],
    );
  }

  List<TournamentMatch> get _allPlayedMatches {
    final out = <TournamentMatch>[];
    switch (widget.tournament) {
      case SeriesHolder h:
        out.addAll(h.state.matches.where((m) => m.isPlayed));
      case TriSeriesHolder h:
        out.addAll(h.state.leagueMatches.where((m) => m.isPlayed));
        if (h.state.finalMatch?.isPlayed == true) out.add(h.state.finalMatch!);
      case BigTournamentHolder h:
        out.addAll(h.state.phase1Schedule.where((m) => m.isPlayed));
        out.addAll(h.state.phase2Schedule.where((m) => m.isPlayed));
        if (h.state.sf1?.isPlayed == true) out.add(h.state.sf1!);
        if (h.state.sf2?.isPlayed == true) out.add(h.state.sf2!);
        if (h.state.finalMatch?.isPlayed == true) out.add(h.state.finalMatch!);
      case MultiFormatSeriesHolder h:
        for (final seg in h.state.segments) {
          out.addAll(seg.matches.where((m) => m.isPlayed));
        }
      case InternationalCupHolder h:
        out.addAll(h.state.allPlayedMatches);
    }
    return out;
  }

  Widget _buildMottBanner() {
    final mott = MotmService.calculateMott(_allPlayedMatches);
    if (mott == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: Colors.deepPurple.shade900.withValues(alpha: 0.45),
      child: Row(children: [
        const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Man of the Tournament',
                style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text('${mott.playerName}  ·  ${mott.teamName}  ·  ${mott.roleLabel}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            if (mott.statsLine.isNotEmpty)
              Text(mott.statsLine,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Map<String, _PA> _computeStats() {
    final map = <String, _PA>{};
    for (final match in _allPlayedMatches) {
      final ms = match.result!;
      void process(List<Player> players, String teamName) {
        for (final p in players) {
          final key = '$teamName\x00${p.name}';
          final agg = map.putIfAbsent(key, () => _PA(p.name, teamName));
          agg.matches++;
          if (p.hasPlayedInnings) {
            agg.innings++;
            agg.totalRuns += p.runsScored;
            agg.totalBalls += p.ballsFaced;
            agg.fours += p.fours;
            agg.sixes += p.sixes;
            if (p.runsScored >= 100) {
              agg.hundreds++;
            } else if (p.runsScored >= 50) {
              agg.fifties++;
            }
            if (p.runsScored > agg.highScore) agg.highScore = p.runsScored;
            if (p.isOut) agg.dismissals++;
          }
          if (p.ballsBowled > 0) {
            agg.wickets += p.wicketsTaken;
            agg.runsConceded += p.runsConceded;
            agg.ballsBowled += p.ballsBowled;
            if (p.wicketsTaken >= 5) agg.fiveWickets++;
            if (p.wicketsTaken > agg.bestWkts ||
                (p.wicketsTaken == agg.bestWkts &&
                    p.wicketsTaken > 0 &&
                    p.runsConceded < agg.bestRuns)) {
              agg.bestWkts = p.wicketsTaken;
              agg.bestRuns = p.runsConceded;
            }
          }
        }
      }
      process(ms.team1Players, ms.setup.team1Name);
      process(ms.team2Players, ms.setup.team2Name);
    }
    return map;
  }

  Widget _buildStats() {
    final allStats = _computeStats().values.toList();

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── left sidebar ──────────────────────────────────────────────────
      Container(
        width: 110,
        color: const Color(0xFF081A11),
        child: ListView(children: [
          _statGroupHeader('Batting'),
          for (final cat in _kStatCats.where((c) => c.$3))
            _statCategoryTile(cat.$1, cat.$2),
          const SizedBox(height: 8),
          _statGroupHeader('Bowling'),
          for (final cat in _kStatCats.where((c) => !c.$3))
            _statCategoryTile(cat.$1, cat.$2),
          const SizedBox(height: 16),
        ]),
      ),
      // ── right table ───────────────────────────────────────────────────
      Expanded(
        child: allStats.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Play some matches to\nsee stats here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              )
            : _buildStatsTable(allStats),
      ),
    ]);
  }

  Widget _statGroupHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3),
        ),
      );

  Widget _statCategoryTile(int idx, String label) {
    final sel = _statsCategory == idx;
    return GestureDetector(
      onTap: () => setState(() => _statsCategory = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel
              ? const Color(0xFF1B5E20).withValues(alpha: 0.55)
              : Colors.transparent,
          border: sel
              ? const Border(
                  left: BorderSide(color: Colors.greenAccent, width: 3))
              : const Border(
                  left: BorderSide(color: Colors.transparent, width: 3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTable(List<_PA> all) {
    final sorted = List<_PA>.from(all);

    var headers = <String>[];
    var colW = <double>[];
    var primIdx = 0;
    List<String> Function(_PA) vals = (_) => [];

    switch (_statsCategory) {
      case 0: // Most Runs
        sorted.sort((a, b) => b.totalRuns != a.totalRuns
            ? b.totalRuns.compareTo(a.totalRuns)
            : a.totalBalls.compareTo(b.totalBalls));
        headers = ['M', 'RUNS', 'AVG', 'SR'];
        colW = [28.0, 42.0, 46.0, 44.0];
        primIdx = 1;
        vals = (p) => [
              '${p.matches}',
              '${p.totalRuns}',
              p.dismissals == 0
                  ? '${p.totalRuns}'
                  : (p.totalRuns / p.dismissals).toStringAsFixed(1),
              p.batSR.toStringAsFixed(1),
            ];

      case 1: // Highest Score
        sorted.sort((a, b) => b.highScore.compareTo(a.highScore));
        headers = ['HS', 'RUNS', 'AVG'];
        colW = [38.0, 44.0, 48.0];
        primIdx = 0;
        vals = (p) => [
              '${p.highScore}',
              '${p.totalRuns}',
              p.dismissals == 0
                  ? '-'
                  : (p.totalRuns / p.dismissals).toStringAsFixed(1),
            ];

      case 2: // Most Fours
        sorted.sort((a, b) => b.fours != a.fours
            ? b.fours.compareTo(a.fours)
            : b.totalRuns.compareTo(a.totalRuns));
        headers = ['M', 'INN', '4s', 'RUNS'];
        colW = [28.0, 32.0, 34.0, 44.0];
        primIdx = 2;
        vals = (p) =>
            ['${p.matches}', '${p.innings}', '${p.fours}', '${p.totalRuns}'];

      case 3: // Most Sixes
        sorted.sort((a, b) => b.sixes != a.sixes
            ? b.sixes.compareTo(a.sixes)
            : b.totalRuns.compareTo(a.totalRuns));
        headers = ['M', 'INN', '6s', 'RUNS'];
        colW = [28.0, 32.0, 34.0, 44.0];
        primIdx = 2;
        vals = (p) =>
            ['${p.matches}', '${p.innings}', '${p.sixes}', '${p.totalRuns}'];

      case 4: // Most Hundreds
        sorted.removeWhere((p) => p.hundreds == 0);
        sorted.sort((a, b) => b.hundreds != a.hundreds
            ? b.hundreds.compareTo(a.hundreds)
            : b.totalRuns.compareTo(a.totalRuns));
        headers = ['M', '100s', '50s', 'RUNS'];
        colW = [28.0, 36.0, 32.0, 44.0];
        primIdx = 1;
        vals = (p) => [
              '${p.matches}',
              '${p.hundreds}',
              '${p.fifties}',
              '${p.totalRuns}'
            ];

      case 5: // Most Fifties
        sorted.removeWhere((p) => p.fifties == 0);
        sorted.sort((a, b) => b.fifties != a.fifties
            ? b.fifties.compareTo(a.fifties)
            : b.totalRuns.compareTo(a.totalRuns));
        headers = ['M', '50s', '100s', 'RUNS'];
        colW = [28.0, 36.0, 36.0, 44.0];
        primIdx = 1;
        vals = (p) => [
              '${p.matches}',
              '${p.fifties}',
              '${p.hundreds}',
              '${p.totalRuns}'
            ];

      case 6: // Most Wickets
        sorted.removeWhere((p) => p.wickets == 0);
        sorted.sort((a, b) => b.wickets != a.wickets
            ? b.wickets.compareTo(a.wickets)
            : a.bowlAvg.compareTo(b.bowlAvg));
        headers = ['M', 'WKTS', 'AVG', 'ECO'];
        colW = [28.0, 38.0, 44.0, 40.0];
        primIdx = 1;
        vals = (p) => [
              '${p.matches}',
              '${p.wickets}',
              p.wickets == 0 ? '-' : p.bowlAvg.toStringAsFixed(1),
              p.economy.toStringAsFixed(2),
            ];

      case 7: // Most 5W Hauls
        sorted.removeWhere((p) => p.fiveWickets == 0);
        sorted.sort((a, b) => b.fiveWickets != a.fiveWickets
            ? b.fiveWickets.compareTo(a.fiveWickets)
            : b.wickets.compareTo(a.wickets));
        headers = ['M', '5W', 'WKTS', 'ECO'];
        colW = [28.0, 32.0, 38.0, 40.0];
        primIdx = 1;
        vals = (p) => [
              '${p.matches}',
              '${p.fiveWickets}',
              '${p.wickets}',
              p.economy.toStringAsFixed(2)
            ];

      default: // case 8: Best Bowling
        sorted.removeWhere((p) => p.wickets == 0);
        sorted.sort((a, b) => a.bestWkts != b.bestWkts
            ? b.bestWkts.compareTo(a.bestWkts)
            : a.bestRuns.compareTo(b.bestRuns));
        headers = ['BBI', 'WKTS', 'ECO'];
        colW = [42.0, 38.0, 40.0];
        primIdx = 0;
        vals = (p) => [
              '${p.bestWkts}/${p.bestRuns == 9999 ? "-" : p.bestRuns}',
              '${p.wickets}',
              p.economy.toStringAsFixed(2),
            ];
    }

    if (sorted.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No data yet for this category',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ),
      );
    }

    // Cap at top 10
    if (sorted.length > 10) sorted.length = 10;

    Widget hCell(String t, double w, bool prime) => SizedBox(
          width: w,
          child: Text(t,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: prime ? Colors.greenAccent : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        );

    Widget dCell(String t, double w, bool prime) => SizedBox(
          width: w,
          child: Text(t,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: prime ? Colors.greenAccent : Colors.white70,
                  fontSize: 12,
                  fontWeight: prime ? FontWeight.bold : FontWeight.normal)),
        );

    return Column(children: [
      // Header
      Container(
        color: const Color(0xFF0A2218),
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        child: Row(children: [
          const SizedBox(
              width: 20,
              child: Text('#',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 6),
          const Expanded(
              child: Text('PLAYER',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
          for (int ci = 0; ci < headers.length; ci++)
            hCell(headers[ci], colW[ci], ci == primIdx),
        ]),
      ),
      const Divider(height: 1, color: Colors.white10),
      // Rows
      Expanded(
        child: ListView.separated(
          itemCount: sorted.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white10),
          itemBuilder: (_, i) {
            final p = sorted[i];
            final v = vals(p);
            return Container(
              color: i.isEven
                  ? const Color(0xFF0D2218)
                  : const Color(0xFF0A1E15),
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              child: Row(children: [
                SizedBox(
                  width: 20,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: i < 3 ? Colors.amber : Colors.white38,
                          fontSize: 11,
                          fontWeight:
                              i < 3 ? FontWeight.bold : FontWeight.normal)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        Text(p.team,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                      ]),
                ),
                for (int ci = 0; ci < v.length; ci++)
                  dCell(v[ci], colW[ci], ci == primIdx),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  // ── squads tab ────────────────────────────────────────────────────────────

  Widget _buildSquads() {
    final teams = _allTeams;
    if (teams.isEmpty) {
      return const Center(
          child: Text('No squads', style: TextStyle(color: Colors.white54)));
    }

    // Clamp index in case teams shrink
    final idx = _squadTeamIdx.clamp(0, teams.length - 1);
    final team = teams[idx];

    final wks = team.players.where((p) => p.isWicketKeeper).toList();
    final batters = team.players
        .where((p) => !p.isWicketKeeper && p.role == PlayerRole.batter)
        .toList();
    final allRounders =
        team.players.where((p) => p.role == PlayerRole.allRounder).toList();
    final bowlers = team.players
        .where((p) => p.role == PlayerRole.bowler && !p.isWicketKeeper)
        .toList();

    return Column(children: [
      // ── Team selector ──────────────────────────────────────────────────
      Container(
        color: const Color(0xFF0A2218),
        height: 46,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: teams.length,
          itemBuilder: (_, i) {
            final sel = i == idx;
            return GestureDetector(
              onTap: () => setState(() => _squadTeamIdx = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? Colors.greenAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? Colors.greenAccent : Colors.white30),
                ),
                child: Text(
                  teams[i].name,
                  style: TextStyle(
                    color: sel ? const Color(0xFF0D2B1E) : Colors.white70,
                    fontWeight:
                        sel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ),

      // ── Player list ────────────────────────────────────────────────────
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
          children: [
            if (batters.isNotEmpty) ...[
              _squadRoleHeader('BATTERS', Icons.sports_cricket,
                  Colors.green.shade300),
              ..._playerPairs(batters),
              const SizedBox(height: 4),
            ],
            if (allRounders.isNotEmpty) ...[
              _squadRoleHeader('ALL-ROUNDERS', Icons.swap_horiz,
                  Colors.purple.shade300),
              ..._playerPairs(allRounders),
              const SizedBox(height: 4),
            ],
            if (wks.isNotEmpty) ...[
              _squadRoleHeader(
                  'WICKET KEEPERS', Icons.sports_cricket, Colors.blue.shade300),
              ..._playerPairs(wks),
              const SizedBox(height: 4),
            ],
            if (bowlers.isNotEmpty) ...[
              _squadRoleHeader('BOWLERS', Icons.offline_bolt,
                  Colors.orange.shade300),
              ..._playerPairs(bowlers),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _squadRoleHeader(String label, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4)),
        ]),
      );

  List<Widget> _playerPairs(List<PlayerInfo> players) {
    final rows = <Widget>[];
    for (int i = 0; i < players.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _squadPlayerCard(players[i])),
          const SizedBox(width: 8),
          i + 1 < players.length
              ? Expanded(child: _squadPlayerCard(players[i + 1]))
              : const Expanded(child: SizedBox()),
        ],
      ));
      rows.add(const SizedBox(height: 8));
    }
    return rows;
  }

  Widget _squadPlayerCard(PlayerInfo p) {
    final isC = p.isCaptain;
    final isWK = p.isWicketKeeper;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2B1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isC
                ? Colors.amber.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Avatar circle
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isC
                ? Colors.amber.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(
                color: isC
                    ? Colors.amber.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: isC
                ? const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 18)
                : isWK
                    ? const Icon(Icons.sports_cricket,
                        color: Colors.lightBlueAccent, size: 17)
                    : Icon(Icons.person,
                        color: Colors.white.withValues(alpha: 0.35), size: 19),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name row
                Row(children: [
                  Flexible(
                    child: Text(
                      isC ? '${p.name} (C)' : p.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isC ? Colors.amber : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (isWK) ...[
                    const SizedBox(width: 4),
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
                  ],
                ]),
                const SizedBox(height: 2),
                Text(_roleLabel(p),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ]),
        ),
      ]),
    );
  }

  String _roleLabel(PlayerInfo p) {
    if (p.isWicketKeeper) return 'Wicket Keeper';
    switch (p.role) {
      case PlayerRole.batter:
        return 'Batter';
      case PlayerRole.bowler:
        return p.bowlerType == BowlerType.fast
            ? 'Fast Bowler'
            : 'Spin Bowler';
      case PlayerRole.allRounder:
        return p.bowlerType == BowlerType.fast
            ? 'Batting Allrounder'
            : 'Bowling Allrounder';
    }
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
                  ? Colors.grey.shade800.withValues(alpha: 0.3)
                  : Colors.green.shade800.withValues(alpha: 0.3),
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

// ── Player aggregate for tournament-wide stats ────────────────────────────────

class _PA {
  final String name;
  final String team;

  int matches = 0;

  // Batting
  int innings = 0;
  int totalRuns = 0;
  int totalBalls = 0;
  int fours = 0;
  int sixes = 0;
  int hundreds = 0;
  int fifties = 0;
  int highScore = 0;
  int dismissals = 0;

  // Bowling
  int wickets = 0;
  int runsConceded = 0;
  int ballsBowled = 0;
  int fiveWickets = 0;
  int bestWkts = 0;
  int bestRuns = 9999;

  _PA(this.name, this.team);

  double get batSR => totalBalls == 0 ? 0 : totalRuns / totalBalls * 100;
  double get bowlAvg => wickets == 0 ? 0 : runsConceded / wickets;
  double get economy => ballsBowled == 0 ? 0 : runsConceded / ballsBowled * 6;
}
