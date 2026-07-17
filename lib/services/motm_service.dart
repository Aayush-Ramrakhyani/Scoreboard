import '../models.dart';
import '../tournament_models.dart';

class MotmResult {
  final String playerName;
  final String teamName;
  final String statsLine;
  final PlayerRole role;
  final bool isWicketKeeper;

  const MotmResult({
    required this.playerName,
    required this.teamName,
    required this.statsLine,
    required this.role,
    required this.isWicketKeeper,
  });

  String get roleLabel {
    if (isWicketKeeper && role == PlayerRole.batter) return 'Batter (WK)';
    return switch (role) {
      PlayerRole.batter => 'Batter',
      PlayerRole.bowler => 'Bowler',
      PlayerRole.allRounder =>
        isWicketKeeper ? 'All-Rounder (WK)' : 'All-Rounder',
    };
  }
}

class MotmService {
  // ── Per-match scoring ─────────────────────────────────────────────────────

  static double _battingScore(Player p) {
    if (!p.hasPlayedInnings && p.ballsFaced == 0) return 0;
    double s = p.runsScored * 2.0 + p.fours * 0.25 + p.sixes * 1.0;
    if (p.runsScored >= 100) { s += 35; }
    else if (p.runsScored >= 50) { s += 15; }
    if (!p.isOut) { s += 5; }
    if (p.ballsFaced > 0 && p.runsScored >= 15) {
      final sr = p.strikeRate;
      if (sr >= 200) { s += 20; }
      else if (sr >= 150) { s += 10; }
      else if (sr >= 120) { s += 3; }
    }
    return s;
  }

  static double _bowlingScore(Player p) {
    if (p.ballsBowled == 0) return 0;
    double s = p.wicketsTaken * 20.0 + p.maidens * 5;
    if (p.wicketsTaken >= 5) { s += 30; }
    else if (p.wicketsTaken >= 3) { s += 10; }
    if (p.ballsBowled >= 12) {
      final eco = p.economy;
      if (eco <= 5.0) { s += 15; }
      else if (eco <= 7.0) { s += 5; }
    }
    return s;
  }

  static double _score(Player p) => switch (p.role) {
        PlayerRole.allRounder => _battingScore(p) + _bowlingScore(p),
        PlayerRole.bowler when !p.isWicketKeeper => _bowlingScore(p),
        _ => _battingScore(p),
      };

  static String _singleStatsLine(Player p) {
    final parts = <String>[];
    if (p.hasPlayedInnings || p.ballsFaced > 0) {
      var line = '${p.runsScored}${p.isOut ? '' : '*'} (${p.ballsFaced}b)';
      final ex = [
        if (p.fours > 0) '${p.fours}×4',
        if (p.sixes > 0) '${p.sixes}×6',
      ];
      if (ex.isNotEmpty) line += ' · ${ex.join(', ')}';
      parts.add(line);
    }
    if (p.ballsBowled > 0) {
      final ov = '${p.ballsBowled ~/ 6}.${p.ballsBowled % 6}';
      parts.add('${p.wicketsTaken}/${p.runsConceded} ($ov ov)');
    }
    return parts.join(' · ');
  }

  /// Man of the Match for a single completed [MatchState].
  static MotmResult? calculateMotm(MatchState ms) {
    final all = [
      ...ms.team1Players.map((p) => (p, ms.setup.team1Name)),
      ...ms.team2Players.map((p) => (p, ms.setup.team2Name)),
    ].where((x) => x.$1.hasPlayedInnings || x.$1.ballsBowled > 0).toList();

    if (all.isEmpty) return null;
    all.sort((a, b) => _score(b.$1).compareTo(_score(a.$1)));
    final (p, team) = all.first;
    return MotmResult(
      playerName: p.name,
      teamName: team,
      statsLine: _singleStatsLine(p),
      role: p.role,
      isWicketKeeper: p.isWicketKeeper,
    );
  }

  // ── Tournament-aggregate scoring ──────────────────────────────────────────

  static double _aggBattingScore(_AggPlayer a) {
    double s = a.totalRuns * 2.0 + a.fours * 0.25 + a.sixes * 1.0;
    s += a.hundreds * 35 + a.fifties * 15 + a.notOuts * 5;
    if (a.totalBalls > 0 && a.totalRuns >= 30) {
      final sr = a.totalRuns / a.totalBalls * 100;
      if (sr >= 200) { s += 20; }
      else if (sr >= 150) { s += 10; }
      else if (sr >= 120) { s += 3; }
    }
    return s;
  }

  static double _aggBowlingScore(_AggPlayer a) {
    double s = a.wickets * 20.0 + a.fiveWickets * 30 + a.maidens * 5;
    if (a.ballsBowled >= 12) {
      final eco = a.runsConceded / a.ballsBowled * 6;
      if (eco <= 5.0) { s += 20; }
      else if (eco <= 7.0) { s += 8; }
    }
    return s;
  }

  static double _aggScore(_AggPlayer a) => switch (a.role) {
        PlayerRole.allRounder => _aggBattingScore(a) + _aggBowlingScore(a),
        PlayerRole.bowler when !a.isWicketKeeper => _aggBowlingScore(a),
        _ => _aggBattingScore(a),
      };

  static String _aggStatsLine(_AggPlayer a) {
    final parts = <String>[];
    if (a.totalRuns > 0 || a.totalBalls > 0) {
      final buf = StringBuffer('${a.totalRuns} runs');
      if (a.highScore > 0) buf.write(' · HS ${a.highScore}');
      if (a.hundreds > 0) buf.write(' · ${a.hundreds}×100');
      if (a.fifties > 0) buf.write(' · ${a.fifties}×50');
      parts.add(buf.toString());
    }
    if (a.ballsBowled > 0) {
      final eco = a.runsConceded / a.ballsBowled * 6;
      parts.add('${a.wickets} wkts · Eco ${eco.toStringAsFixed(1)}');
    }
    return parts.join(' · ');
  }

  /// Man of the Tournament from all played [TournamentMatch] objects.
  static MotmResult? calculateMott(List<TournamentMatch> matches) {
    final map = <String, _AggPlayer>{};
    for (final m in matches) {
      final ms = m.result;
      if (ms == null) continue;
      void agg(List<Player> players, String team) {
        for (final p in players) {
          if (!p.hasPlayedInnings && p.ballsBowled == 0) continue;
          final a = map.putIfAbsent(
            '$team\x00${p.name}',
            () => _AggPlayer(p.name, team, p.role, p.isWicketKeeper),
          );
          if (p.hasPlayedInnings || p.ballsFaced > 0) {
            a.totalRuns += p.runsScored;
            a.totalBalls += p.ballsFaced;
            a.fours += p.fours;
            a.sixes += p.sixes;
            if (p.runsScored >= 100) { a.hundreds++; }
            else if (p.runsScored >= 50) { a.fifties++; }
            if (!p.isOut) { a.notOuts++; }
            if (p.runsScored > a.highScore) { a.highScore = p.runsScored; }
          }
          if (p.ballsBowled > 0) {
            a.wickets += p.wicketsTaken;
            a.runsConceded += p.runsConceded;
            a.ballsBowled += p.ballsBowled;
            a.maidens += p.maidens;
            if (p.wicketsTaken >= 5) a.fiveWickets++;
          }
        }
      }
      agg(ms.team1Players, ms.setup.team1Name);
      agg(ms.team2Players, ms.setup.team2Name);
    }

    if (map.isEmpty) return null;
    final ranked = map.values.toList()
      ..sort((a, b) => _aggScore(b).compareTo(_aggScore(a)));
    final best = ranked.first;
    return MotmResult(
      playerName: best.name,
      teamName: best.team,
      statsLine: _aggStatsLine(best),
      role: best.role,
      isWicketKeeper: best.isWicketKeeper,
    );
  }
}

class _AggPlayer {
  final String name;
  final String team;
  final PlayerRole role;
  final bool isWicketKeeper;
  int totalRuns = 0, totalBalls = 0, fours = 0, sixes = 0;
  int hundreds = 0, fifties = 0, notOuts = 0, highScore = 0;
  int wickets = 0, runsConceded = 0, ballsBowled = 0, maidens = 0, fiveWickets = 0;
  _AggPlayer(this.name, this.team, this.role, this.isWicketKeeper);
}
