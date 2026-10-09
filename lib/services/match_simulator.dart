import 'dart:math';
import '../models.dart';
import '../tournament_models.dart';

class MatchSimulator {
  static final _rand = Random();

  static MatchState simulate(
    TournamentTeam team1,
    TournamentTeam team2, {
    required MatchFormat format,
    required int overs,
  }) {
    final setup = MatchSetup(
      team1Name: team1.name,
      team2Name: team2.name,
      team1Players: team1.players,
      team2Players: team2.players,
      format: format,
    );

    final ms = MatchState(setup);
    ms.team1BatsFirst = _rand.nextBool();

    final bat1 = ms.team1BatsFirst ? ms.team1Players : ms.team2Players;
    final bowl1 = ms.team1BatsFirst ? ms.team2Players : ms.team1Players;
    final bat2 = ms.team1BatsFirst ? ms.team2Players : ms.team1Players;
    final bowl2 = ms.team1BatsFirst ? ms.team1Players : ms.team2Players;

    final totalBalls = overs * 6;
    final isT20 = overs <= 20;

    // First innings
    final s1 = _genTotal(isT20: isT20, maxScore: null);
    _setBatting(bat1, s1.runs, s1.wickets, bowl1);
    _setBowling(bowl1, s1.runs, s1.wickets, s1.balls, totalBalls, isT20);
    ms.innings1 = _buildInn(bat1, bowl1, s1.runs, s1.wickets, s1.balls);

    // Second innings
    final team2Wins = _rand.nextBool();
    final target = s1.runs + 1;
    final s2 = _genTotal(isT20: isT20, maxScore: team2Wins ? null : target - 1);
    final runs2 = team2Wins
        ? s2.runs.clamp(target, target + 80)
        : s2.runs.clamp(50, target - 1);
    _setBatting(bat2, runs2, s2.wickets, bowl2);
    _setBowling(bowl2, runs2, s2.wickets, s2.balls, totalBalls, isT20);
    ms.innings2 = _buildInn(bat2, bowl2, runs2, s2.wickets, s2.balls);

    ms.currentInnings = 2;
    ms.matchOver = true;

    final battingFirst =
        ms.team1BatsFirst ? setup.team1Name : setup.team2Name;
    final chasing = ms.team1BatsFirst ? setup.team2Name : setup.team1Name;

    if (runs2 >= target) {
      ms.winnerName = chasing;
      final wk = 10 - s2.wickets;
      ms.matchResult = '$chasing won by $wk wicket${wk == 1 ? '' : 's'}';
    } else {
      ms.winnerName = battingFirst;
      final margin = s1.runs - runs2;
      ms.matchResult =
          '$battingFirst won by $margin run${margin == 1 ? '' : 's'}';
    }

    return ms;
  }

  // ── internals ─────────────────────────────────────────────────────────────

  static ({int runs, int wickets, int balls}) _genTotal({
    required bool isT20,
    required int? maxScore,
  }) {
    int runs;
    int wickets;

    if (maxScore != null) {
      runs = (maxScore - 1 - _rand.nextInt(55)).clamp(50, maxScore - 1);
      wickets = 7 + _rand.nextInt(4); // 7–10: chasing team likely fell short
    } else {
      final base = isT20 ? 120 : 200;
      final range = isT20 ? 81 : 141;
      runs = base + _rand.nextInt(range);
      wickets = _rand.nextBool()
          ? 3 + _rand.nextInt(5)  // won with wickets in hand
          : 7 + _rand.nextInt(4); // all-out or close
    }

    final maxBalls = isT20 ? 120 : 300;
    final balls = wickets >= 10
        ? (maxBalls * (0.55 + _rand.nextDouble() * 0.45)).round().clamp(6, maxBalls)
        : maxBalls;

    return (runs: runs, wickets: wickets.clamp(0, 10), balls: balls);
  }

  static void _setBatting(
    List<Player> batting,
    int total,
    int wickets,
    List<Player> bowling,
  ) {
    final n = batting.length.clamp(0, 11);
    if (n == 0) return;

    // Position weights: top order scores most
    final weights = List.generate(n, (i) {
      if (i < 3) return 4.0 + _rand.nextDouble() * 4.0;
      if (i < 6) return 1.5 + _rand.nextDouble() * 2.0;
      if (i < 9) return 0.3 + _rand.nextDouble() * 0.8;
      return 0.05 + _rand.nextDouble() * 0.25;
    });

    final wSum = weights.reduce((a, b) => a + b);
    final runs = weights.map((w) => (w / wSum * total).round()).toList();

    // Fix rounding drift on index 0
    final diff = total - runs.reduce((a, b) => a + b);
    runs[0] = (runs[0] + diff).clamp(0, 999);

    for (int i = 0; i < n; i++) {
      final p = batting[i];
      p.hasPlayedInnings = true;
      p.battingPosition = i + 1;
      p.runsScored = runs[i].clamp(0, 250);

      final srPct = i < 3
          ? 100 + _rand.nextInt(70)   // top order: 100–170
          : 75 + _rand.nextInt(55);   // rest: 75–130
      p.ballsFaced =
          (p.runsScored / (srPct / 100.0)).round().clamp(1, 200);
      p.fours = (p.runsScored / 22.0).floor().clamp(0, p.runsScored ~/ 4);
      p.sixes = (p.runsScored / 38.0).floor().clamp(0, p.runsScored ~/ 6);

      if (i < wickets) {
        p.isOut = true;
        p.dismissalInfo = _dismissal(bowling);
      }
    }
  }

  static String _dismissal(List<Player> bowling) {
    final bowlers = bowling
        .where((b) =>
            b.role == PlayerRole.bowler || b.role == PlayerRole.allRounder)
        .toList();
    final name = bowlers.isNotEmpty
        ? bowlers[_rand.nextInt(bowlers.length)].name
        : bowling[_rand.nextInt(bowling.length)].name;
    const modes = ['b', 'c sub b', 'lbw b', 'c&b'];
    return '${modes[_rand.nextInt(modes.length)]} $name';
  }

  static void _setBowling(
    List<Player> bowling,
    int totalRuns,
    int wickets,
    int balls,
    int maxBalls,
    bool isT20,
  ) {
    final candidates = bowling
        .where((b) =>
            b.role == PlayerRole.bowler ||
            (b.role == PlayerRole.allRounder && b.bowlerType != null))
        .toList();
    if (candidates.isEmpty) candidates.addAll(bowling.take(5));

    // Max overs per bowler: T20 = 4, ODI/Test = 10
    final maxBowlerOvers = isT20 ? 4 : 10;
    final totalOvers = balls ~/ 6;
    // Need enough bowlers so no single bowler exceeds their quota
    final minBowlers = ((totalOvers + maxBowlerOvers - 1) ~/ maxBowlerOvers).clamp(1, 11);
    final count = minBowlers.clamp(1, candidates.length);
    candidates.shuffle(_rand);
    final bowlers = candidates.take(count).toList();

    final overs = totalOvers;
    final baseOvers = count > 0 ? overs ~/ count : 0;
    final extra = overs - baseOvers * count;

    final wkDist = _distribute(wickets, count);
    final runsDist = _distribute(totalRuns, count);

    for (int i = 0; i < bowlers.length; i++) {
      final p = bowlers[i];
      final ov = (baseOvers + (i < extra ? 1 : 0)).clamp(0, maxBowlerOvers);
      p.bowlingPosition = i + 1;
      p.ballsBowled = ov * 6;
      p.wicketsTaken = wkDist[i];
      p.runsConceded = runsDist[i];
      p.maidens = (ov >= 2 && p.runsConceded < ov * 4)
          ? _rand.nextInt((ov ~/ 2).clamp(1, 3))
          : 0;
    }
  }

  static List<int> _distribute(int total, int n) {
    if (n == 0) return [];
    final result = List.filled(n, 0);
    var remaining = total;
    for (int i = 0; i < n - 1; i++) {
      final share =
          ((remaining / (n - i)) * (0.5 + _rand.nextDouble())).round()
              .clamp(0, remaining);
      result[i] = share;
      remaining -= share;
    }
    result[n - 1] = remaining.clamp(0, total);
    return result;
  }

  static Innings _buildInn(
      List<Player> bat, List<Player> bowl, int runs, int wk, int balls) {
    final inn = Innings(bat, bowl);
    inn.totalRuns = runs;
    inn.wickets = wk;
    inn.balls = balls;
    inn.isComplete = true;
    inn.strikerIndex = 0;
    inn.nonStrikerIndex = 1;
    inn.nextBatsmanIndex = (wk + 2).clamp(2, 10);
    inn.currentBowlerIndex = 0;
    return inn;
  }
}
