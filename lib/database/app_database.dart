import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../tournament_models.dart';

class AppDatabase {
  static const _kMatch = 'match_save';
  static const _kTournType = 'tourn_type';
  static const _kTourn = 'tourn_save';

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<bool> hasSavedMatch() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kMatch);
  }

  static Future<void> saveMatch(MatchState ms) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMatch, jsonEncode(_msToJson(ms)));
  }

  static Future<MatchState?> loadMatch() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kMatch);
    if (raw == null) return null;
    try {
      return _msFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearMatch() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kMatch);
  }

  static Future<bool> hasSavedTournament() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kTourn);
  }

  static Future<String?> savedTournamentType() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTournType);
  }

  static Future<void> saveTournament(AnyTournament t) async {
    final p = await SharedPreferences.getInstance();
    final (type, json) = switch (t) {
      SeriesHolder(:var state) => ('series', _seriesToJson(state)),
      TriSeriesHolder(:var state) => ('triseries', _triSeriesToJson(state)),
      BigTournamentHolder(:var state) => ('big', _bigToJson(state)),
      MultiFormatSeriesHolder(:var state) => ('multiformat', _mfsToJson(state)),
    };
    await p.setString(_kTournType, type);
    await p.setString(_kTourn, jsonEncode(json));
  }

  static Future<AnyTournament?> loadTournament() async {
    final p = await SharedPreferences.getInstance();
    final type = p.getString(_kTournType);
    final raw = p.getString(_kTourn);
    if (type == null || raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return switch (type) {
        'series' => SeriesHolder(_seriesFromJson(m)),
        'triseries' => TriSeriesHolder(_triSeriesFromJson(m)),
        'big' => BigTournamentHolder(_bigFromJson(m)),
        'multiformat' => MultiFormatSeriesHolder(_mfsFromJson(m)),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearTournament() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTournType);
    await p.remove(_kTourn);
  }

  // ── PlayerInfo ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _piToJson(PlayerInfo p) => {
        'n': p.name,
        'r': p.role.index,
        'bt': p.bowlerType?.index,
        'c': p.isCaptain,
        'wk': p.isWicketKeeper,
      };

  static PlayerInfo _piFromJson(Map<String, dynamic> m) => PlayerInfo(
        name: m['n'] as String,
        role: PlayerRole.values[m['r'] as int],
        bowlerType:
            m['bt'] != null ? BowlerType.values[m['bt'] as int] : null,
        isCaptain: m['c'] as bool? ?? false,
        isWicketKeeper: m['wk'] as bool? ?? false,
      );

  // ── Player (with stats) ─────────────────────────────────────────────────────

  static Map<String, dynamic> _pToJson(Player p) => {
        'n': p.name,
        'r': p.role.index,
        'bt': p.bowlerType?.index,
        'c': p.isCaptain,
        'wk': p.isWicketKeeper,
        'rs': p.runsScored,
        'bf': p.ballsFaced,
        'f4': p.fours,
        's6': p.sixes,
        'out': p.isOut,
        'hp': p.hasPlayedInnings,
        'di': p.dismissalInfo,
        'bb': p.ballsBowled,
        'rc': p.runsConceded,
        'wt': p.wicketsTaken,
        'wb': p.widesBowled,
        'nb': p.noBallsBowled,
        'md': p.maidens,
      };

  static Player _pFromJson(Map<String, dynamic> m) {
    final p = Player(
      m['n'] as String,
      role: PlayerRole.values[m['r'] as int],
      bowlerType:
          m['bt'] != null ? BowlerType.values[m['bt'] as int] : null,
      isCaptain: m['c'] as bool? ?? false,
      isWicketKeeper: m['wk'] as bool? ?? false,
    );
    p.runsScored = m['rs'] as int? ?? 0;
    p.ballsFaced = m['bf'] as int? ?? 0;
    p.fours = m['f4'] as int? ?? 0;
    p.sixes = m['s6'] as int? ?? 0;
    p.isOut = m['out'] as bool? ?? false;
    p.hasPlayedInnings = m['hp'] as bool? ?? false;
    p.dismissalInfo = m['di'] as String? ?? '';
    p.ballsBowled = m['bb'] as int? ?? 0;
    p.runsConceded = m['rc'] as int? ?? 0;
    p.wicketsTaken = m['wt'] as int? ?? 0;
    p.widesBowled = m['wb'] as int? ?? 0;
    p.noBallsBowled = m['nb'] as int? ?? 0;
    p.maidens = m['md'] as int? ?? 0;
    return p;
  }

  // ── FallOfWicket ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _fowToJson(FallOfWicket f) => {
        'wn': f.wicketNumber,
        'sc': f.score,
        'b': f.balls,
        'bn': f.batsmanName,
      };

  static FallOfWicket _fowFromJson(Map<String, dynamic> m) => FallOfWicket(
        wicketNumber: m['wn'] as int,
        score: m['sc'] as int,
        balls: m['b'] as int,
        batsmanName: m['bn'] as String,
      );

  // ── PartnershipEntry ──────────────────────────────────────────────────────

  static Map<String, dynamic> _partToJson(PartnershipEntry p) => {
        'b1n': p.bat1Name,
        'b1r': p.bat1Runs,
        'b1b': p.bat1Balls,
        'b2n': p.bat2Name,
        'b2r': p.bat2Runs,
        'b2b': p.bat2Balls,
        'tr': p.totalRuns,
        'tb': p.totalBalls,
      };

  static PartnershipEntry _partFromJson(Map<String, dynamic> m) =>
      PartnershipEntry(
        bat1Name: m['b1n'] as String,
        bat1Runs: m['b1r'] as int,
        bat1Balls: m['b1b'] as int,
        bat2Name: m['b2n'] as String,
        bat2Runs: m['b2r'] as int,
        bat2Balls: m['b2b'] as int,
        totalRuns: m['tr'] as int,
        totalBalls: m['tb'] as int,
      );

  // ── Innings ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _innToJson(Innings inn) => {
        'tr': inn.totalRuns,
        'wk': inn.wickets,
        'b': inn.balls,
        'bl': inn.ballLog,
        'oh': inn.overHistory,
        'wd': inn.wides,
        'nbr': inn.noBalls,
        'by': inn.byes,
        'lb': inn.legByes,
        'ic': inn.isComplete,
        'si': inn.strikerIndex,
        'ns': inn.nonStrikerIndex,
        'nbi': inn.nextBatsmanIndex,
        'cb': inn.currentBowlerIndex,
        'fw': inn.fallOfWickets.map(_fowToJson).toList(),
        'ps': inn.partnerships.map(_partToJson).toList(),
      };

  static Innings _innFromJson(
    Map<String, dynamic> m,
    List<Player> batting,
    List<Player> bowling,
  ) {
    final inn = Innings(batting, bowling);
    inn.totalRuns = m['tr'] as int? ?? 0;
    inn.wickets = m['wk'] as int? ?? 0;
    inn.balls = m['b'] as int? ?? 0;
    inn.ballLog = List<String>.from(m['bl'] as List? ?? []);
    inn.overHistory = (m['oh'] as List?)
            ?.map((o) => List<String>.from(o as List))
            .toList() ??
        [];
    inn.wides = m['wd'] as int? ?? 0;
    inn.noBalls = m['nbr'] as int? ?? 0;
    inn.byes = m['by'] as int? ?? 0;
    inn.legByes = m['lb'] as int? ?? 0;
    inn.isComplete = m['ic'] as bool? ?? false;
    inn.strikerIndex = m['si'] as int? ?? 0;
    inn.nonStrikerIndex = m['ns'] as int? ?? 1;
    inn.nextBatsmanIndex = m['nbi'] as int? ?? 2;
    inn.currentBowlerIndex = m['cb'] as int? ?? 0;
    inn.fallOfWickets = (m['fw'] as List?)
            ?.map((f) => _fowFromJson(f as Map<String, dynamic>))
            .toList() ??
        [];
    inn.partnerships = (m['ps'] as List?)
            ?.map((p) => _partFromJson(p as Map<String, dynamic>))
            .toList() ??
        [];
    return inn;
  }

  // ── MatchSetup ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _setupToJson(MatchSetup s) => {
        't1': s.team1Name,
        't2': s.team2Name,
        'p1': s.team1Players.map(_piToJson).toList(),
        'p2': s.team2Players.map(_piToJson).toList(),
        'f': s.format.index,
        'd': s.days,
      };

  static MatchSetup _setupFromJson(Map<String, dynamic> m) => MatchSetup(
        team1Name: m['t1'] as String,
        team2Name: m['t2'] as String,
        team1Players: (m['p1'] as List)
            .map((p) => _piFromJson(p as Map<String, dynamic>))
            .toList(),
        team2Players: (m['p2'] as List)
            .map((p) => _piFromJson(p as Map<String, dynamic>))
            .toList(),
        format: MatchFormat.values[m['f'] as int],
        days: m['d'] as int? ?? 5,
      );

  // ── MatchState ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _msToJson(MatchState ms) {
    final m = <String, dynamic>{
      'setup': _setupToJson(ms.setup),
      't1p': ms.team1Players.map(_pToJson).toList(),
      't2p': ms.team2Players.map(_pToJson).toList(),
      'tbf': ms.team1BatsFirst,
      'ci': ms.currentInnings,
      'mo': ms.matchOver,
      'mr': ms.matchResult,
      'wn': ms.winnerName,
      'i1': _innToJson(ms.innings1),
    };
    if (ms.currentInnings >= 2) m['i2'] = _innToJson(ms.innings2);
    if (ms.innings3 != null) m['i3'] = _innToJson(ms.innings3!);
    if (ms.innings4 != null) m['i4'] = _innToJson(ms.innings4!);
    return m;
  }

  static MatchState _msFromJson(Map<String, dynamic> m) {
    final setup = _setupFromJson(m['setup'] as Map<String, dynamic>);
    final ms = MatchState(setup);

    ms.team1Players = (m['t1p'] as List)
        .map((p) => _pFromJson(p as Map<String, dynamic>))
        .toList();
    ms.team2Players = (m['t2p'] as List)
        .map((p) => _pFromJson(p as Map<String, dynamic>))
        .toList();
    ms.team1BatsFirst = m['tbf'] as bool;
    ms.currentInnings = m['ci'] as int;
    ms.matchOver = m['mo'] as bool? ?? false;
    ms.matchResult = m['mr'] as String? ?? '';
    ms.winnerName = m['wn'] as String? ?? '';

    final bat1 = ms.team1BatsFirst ? ms.team1Players : ms.team2Players;
    final bowl1 = ms.team1BatsFirst ? ms.team2Players : ms.team1Players;
    ms.innings1 = _innFromJson(m['i1'] as Map<String, dynamic>, bat1, bowl1);

    if (m['i2'] != null) {
      final bat2 = ms.team1BatsFirst ? ms.team2Players : ms.team1Players;
      final bowl2 = ms.team1BatsFirst ? ms.team1Players : ms.team2Players;
      ms.innings2 =
          _innFromJson(m['i2'] as Map<String, dynamic>, bat2, bowl2);
    }
    if (m['i3'] != null) {
      ms.innings3 =
          _innFromJson(m['i3'] as Map<String, dynamic>, bat1, bowl1);
    }
    if (m['i4'] != null) {
      final bat2 = ms.team1BatsFirst ? ms.team2Players : ms.team1Players;
      final bowl2 = ms.team1BatsFirst ? ms.team1Players : ms.team2Players;
      ms.innings4 =
          _innFromJson(m['i4'] as Map<String, dynamic>, bat2, bowl2);
    }
    return ms;
  }

  // ── TournamentTeam ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _ttToJson(TournamentTeam t) => {
        'n': t.name,
        'p': t.players.map(_piToJson).toList(),
      };

  static TournamentTeam _ttFromJson(Map<String, dynamic> m) => TournamentTeam(
        name: m['n'] as String,
        players: (m['p'] as List)
            .map((p) => _piFromJson(p as Map<String, dynamic>))
            .toList(),
      );

  // ── TournamentMatch ────────────────────────────────────────────────────────

  static Map<String, dynamic> _tmToJson(TournamentMatch tm) => {
        't1': tm.team1Name,
        't2': tm.team2Name,
        'ph': tm.phase,
        'r': tm.result != null ? _msToJson(tm.result!) : null,
      };

  static TournamentMatch _tmFromJson(Map<String, dynamic> m) {
    final tm = TournamentMatch(
      team1Name: m['t1'] as String,
      team2Name: m['t2'] as String,
      phase: m['ph'] as String,
    );
    if (m['r'] != null) {
      tm.result = _msFromJson(m['r'] as Map<String, dynamic>);
    }
    return tm;
  }

  // ── SeriesState ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _seriesToJson(SeriesState s) => {
        'teams': s.teams.map(_ttToJson).toList(),
        'overs': s.overs,
        'format': s.format.index,
        'days': s.days,
        'total': s.totalMatches,
        'results': s.matches
            .map((m) => m.result != null ? _msToJson(m.result!) : null)
            .toList(),
      };

  static SeriesState _seriesFromJson(Map<String, dynamic> m) {
    final s = SeriesState(
      teams: (m['teams'] as List)
          .map((t) => _ttFromJson(t as Map<String, dynamic>))
          .toList(),
      overs: m['overs'] as int,
      format: MatchFormat.values[m['format'] as int],
      days: m['days'] as int? ?? 5,
      totalMatches: m['total'] as int,
    );
    final results = m['results'] as List;
    for (int i = 0; i < results.length && i < s.matches.length; i++) {
      if (results[i] != null) {
        s.matches[i].result =
            _msFromJson(results[i] as Map<String, dynamic>);
      }
    }
    return s;
  }

  // ── TriSeriesState ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _triSeriesToJson(TriSeriesState s) => {
        'teams': s.teams.map(_ttToJson).toList(),
        'overs': s.overs,
        'format': s.format.index,
        'league': s.leagueMatches.map(_tmToJson).toList(),
        'final': s.finalMatch != null ? _tmToJson(s.finalMatch!) : null,
      };

  static TriSeriesState _triSeriesFromJson(Map<String, dynamic> m) {
    final s = TriSeriesState(
      teams: (m['teams'] as List)
          .map((t) => _ttFromJson(t as Map<String, dynamic>))
          .toList(),
      overs: m['overs'] as int,
      format: MatchFormat.values[m['format'] as int],
    );
    s.leagueMatches
      ..clear()
      ..addAll((m['league'] as List)
          .map((lm) => _tmFromJson(lm as Map<String, dynamic>)));
    if (m['final'] != null) {
      s.finalMatch = _tmFromJson(m['final'] as Map<String, dynamic>);
    }
    return s;
  }

  // ── BigTournamentState ─────────────────────────────────────────────────────

  static Map<String, dynamic> _bigToJson(BigTournamentState s) => {
        'teams': s.teams.map(_ttToJson).toList(),
        'overs': s.overs,
        'format': s.format.index,
        'npg': s.numPhase1Groups,
        'pac': s.phase1AdvanceCount,
        'p1g': s.phase1Groups
            .map((g) => {
                  'teams': g.teamNames,
                  'matches': g.matches.map(_tmToJson).toList(),
                })
            .toList(),
        'p2g': s.phase2Groups
            ?.map((g) => {
                  'teams': g.teamNames,
                  'matches': g.matches.map(_tmToJson).toList(),
                })
            .toList(),
        'sf1': s.sf1 != null ? _tmToJson(s.sf1!) : null,
        'sf2': s.sf2 != null ? _tmToJson(s.sf2!) : null,
        'fin': s.finalMatch != null ? _tmToJson(s.finalMatch!) : null,
      };

  static BigTournamentState _bigFromJson(Map<String, dynamic> m) {
    final teams = (m['teams'] as List)
        .map((t) => _ttFromJson(t as Map<String, dynamic>))
        .toList();
    final p1gData = m['p1g'] as List;
    final groupAssignments = p1gData
        .map((g) =>
            List<String>.from((g as Map<String, dynamic>)['teams'] as List))
        .toList();

    final s = BigTournamentState(
      teams: teams,
      overs: m['overs'] as int,
      format: MatchFormat.values[m['format'] as int],
      numPhase1Groups: m['npg'] as int,
      phase1AdvanceCount: m['pac'] as int,
      groupAssignments: groupAssignments,
    );

    // Patch phase1 match results
    for (int gi = 0; gi < s.phase1Groups.length && gi < p1gData.length; gi++) {
      final savedMatches =
          (p1gData[gi] as Map<String, dynamic>)['matches'] as List;
      for (int mi = 0;
          mi < s.phase1Groups[gi].matches.length && mi < savedMatches.length;
          mi++) {
        final sm = savedMatches[mi] as Map<String, dynamic>;
        if (sm['r'] != null) {
          s.phase1Groups[gi].matches[mi].result =
              _msFromJson(sm['r'] as Map<String, dynamic>);
        }
      }
    }

    // Advance from phase1 (deterministic from results)
    s.tryAdvancePhase1();

    // Patch phase2 if it was built
    final p2gData = m['p2g'] as List?;
    if (p2gData != null && s.phase2Groups != null) {
      for (int gi = 0;
          gi < s.phase2Groups!.length && gi < p2gData.length;
          gi++) {
        final savedMatches =
            (p2gData[gi] as Map<String, dynamic>)['matches'] as List;
        for (int mi = 0;
            mi < s.phase2Groups![gi].matches.length &&
                mi < savedMatches.length;
            mi++) {
          final sm = savedMatches[mi] as Map<String, dynamic>;
          if (sm['r'] != null) {
            s.phase2Groups![gi].matches[mi].result =
                _msFromJson(sm['r'] as Map<String, dynamic>);
          }
        }
      }
      s.tryAdvancePhase2();
    }

    // Patch sf1 / sf2
    void patchSf(TournamentMatch? existing, Map<String, dynamic>? saved,
        void Function(TournamentMatch) setter) {
      if (saved == null) return;
      final target = existing ?? _tmFromJson(saved);
      if (existing == null) setter(target);
      if (saved['r'] != null && target.result == null) {
        target.result = _msFromJson(saved['r'] as Map<String, dynamic>);
      }
    }

    patchSf(s.sf1, m['sf1'] as Map<String, dynamic>?,
        (tm) => s.sf1 = tm);
    patchSf(s.sf2, m['sf2'] as Map<String, dynamic>?,
        (tm) => s.sf2 = tm);

    // Build final from semis, then patch result
    s.trySetupFinal();

    final finData = m['fin'] as Map<String, dynamic>?;
    if (finData != null) {
      if (s.finalMatch == null) {
        s.finalMatch = _tmFromJson(finData);
      } else if (finData['r'] != null && s.finalMatch!.result == null) {
        s.finalMatch!.result =
            _msFromJson(finData['r'] as Map<String, dynamic>);
      }
    }

    return s;
  }

  // ── Public serialization wrappers (used by live session) ──────────────────

  static Map<String, dynamic> matchStateToJson(MatchState ms) => _msToJson(ms);
  static MatchState matchStateFromJson(Map<String, dynamic> m) => _msFromJson(m);

  static (String, Map<String, dynamic>) tournamentToJson(AnyTournament t) =>
      switch (t) {
        SeriesHolder(:var state) => ('series', _seriesToJson(state)),
        TriSeriesHolder(:var state) => ('triseries', _triSeriesToJson(state)),
        BigTournamentHolder(:var state) => ('big', _bigToJson(state)),
        MultiFormatSeriesHolder(:var state) => ('multiformat', _mfsToJson(state)),
      };

  static AnyTournament? tournamentFromJson(String type, Map<String, dynamic> m) =>
      switch (type) {
        'series' => SeriesHolder(_seriesFromJson(m)),
        'triseries' => TriSeriesHolder(_triSeriesFromJson(m)),
        'big' => BigTournamentHolder(_bigFromJson(m)),
        'multiformat' => MultiFormatSeriesHolder(_mfsFromJson(m)),
        _ => null,
      };

  // ── MultiFormatSeriesState ─────────────────────────────────────────────────

  static Map<String, dynamic> _mfsToJson(MultiFormatSeriesState s) => {
        'teams': s.teams.map(_ttToJson).toList(),
        'segments': s.segments
            .map((seg) => {
                  'format': seg.format.index,
                  'count': seg.matchCount,
                  'days': seg.days,
                  't1': seg.team1Name,
                  't2': seg.team2Name,
                  'results': seg.matches
                      .map((m) =>
                          m.result != null ? _msToJson(m.result!) : null)
                      .toList(),
                })
            .toList(),
      };

  static MultiFormatSeriesState _mfsFromJson(Map<String, dynamic> m) {
    final teams = (m['teams'] as List)
        .map((t) => _ttFromJson(t as Map<String, dynamic>))
        .toList();
    final segments = (m['segments'] as List).map((s) {
      final sm = s as Map<String, dynamic>;
      final seg = FormatSegment(
        format: MatchFormat.values[sm['format'] as int],
        matchCount: sm['count'] as int,
        days: sm['days'] as int? ?? 5,
        team1Name: sm['t1'] as String,
        team2Name: sm['t2'] as String,
      );
      final results = sm['results'] as List;
      for (int i = 0; i < seg.matches.length && i < results.length; i++) {
        if (results[i] != null) {
          seg.matches[i].result =
              _msFromJson(results[i] as Map<String, dynamic>);
        }
      }
      return seg;
    }).toList();
    return MultiFormatSeriesState(teams: teams, segments: segments);
  }
}
