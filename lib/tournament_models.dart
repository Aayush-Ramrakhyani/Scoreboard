import 'dart:math';
import 'models.dart';
export 'models.dart' show MatchFormat;

class TournamentTeam {
  final String name;
  final List<PlayerInfo> players;
  const TournamentTeam({required this.name, required this.players});
}

class TournamentMatch {
  final String team1Name;
  final String team2Name;
  final String phase;
  MatchState? result;

  TournamentMatch({
    required this.team1Name,
    required this.team2Name,
    required this.phase,
  });

  bool get isPlayed => result != null;
  String get winnerName => result?.winnerName ?? '';
  bool get isTie => isPlayed && winnerName.isEmpty;
}

class TeamStanding {
  final String teamName;
  int played = 0, won = 0, lost = 0, tied = 0;
  double runsScored = 0, oversFaced = 0, runsConceded = 0, oversBowled = 0;

  TeamStanding(this.teamName);

  int get points => won * 2 + tied;

  double get nrr {
    if (oversFaced == 0) return 0;
    return (runsScored / oversFaced) -
        (oversBowled == 0 ? 0 : runsConceded / oversBowled);
  }

  String get nrrDisplay =>
      nrr >= 0 ? '+${nrr.toStringAsFixed(3)}' : nrr.toStringAsFixed(3);
}

void _applyMatchResult(
    TournamentMatch match, TeamStanding s1, TeamStanding s2, int ballsPerInnings) {
  final ms = match.result!;
  final maxBalls = ballsPerInnings;

  if (match.isTie) {
    s1.tied++;
    s2.tied++;
  } else if (match.winnerName == s1.teamName) {
    s1.won++;
    s2.lost++;
  } else {
    s2.won++;
    s1.lost++;
  }
  s1.played++;
  s2.played++;

  final TeamStanding bf, bs;
  if (ms.team1BatsFirst) {
    bf = s1;
    bs = s2;
  } else {
    bf = s2;
    bs = s1;
  }

  final inn1 = ms.innings1;
  final b1 = inn1.wickets >= 10 ? maxBalls.toDouble() : inn1.balls.toDouble();
  bf.runsScored += inn1.totalRuns;
  bf.oversFaced += b1 / 6.0;
  bs.runsConceded += inn1.totalRuns;
  bs.oversBowled += b1 / 6.0;

  final inn2 = ms.innings2;
  final b2 = inn2.wickets >= 10 ? maxBalls.toDouble() : inn2.balls.toDouble();
  bs.runsScored += inn2.totalRuns;
  bs.oversFaced += b2 / 6.0;
  bf.runsConceded += inn2.totalRuns;
  bf.oversBowled += b2 / 6.0;
}

class TournamentGroup {
  final String name;
  List<String> teamNames;
  final int advanceCount;
  List<TournamentMatch> matches = [];

  TournamentGroup({
    required this.name,
    required this.teamNames,
    required this.advanceCount,
  });

  void generateMatches() {
    matches.clear();
    for (int i = 0; i < teamNames.length; i++) {
      for (int j = i + 1; j < teamNames.length; j++) {
        matches.add(TournamentMatch(
          team1Name: teamNames[i],
          team2Name: teamNames[j],
          phase: name,
        ));
      }
    }
  }

  bool get isComplete => matches.every((m) => m.isPlayed);

  List<TeamStanding> computedStandings(int ballsPerInnings) {
    final map = {for (final n in teamNames) n: TeamStanding(n)};
    for (final m in matches) {
      if (!m.isPlayed) continue;
      _applyMatchResult(m, map[m.team1Name]!, map[m.team2Name]!, ballsPerInnings);
    }
    final list = map.values.toList();
    list.sort((a, b) => b.points != a.points
        ? b.points.compareTo(a.points)
        : b.nrr.compareTo(a.nrr));
    return list;
  }

  List<String> qualifiers(int ballsPerInnings) =>
      computedStandings(ballsPerInnings).take(advanceCount).map((s) => s.teamName).toList();
}

// Stable hash from team names — deterministic per tournament, unique per group composition.
int _teamSeed(List<String> names) {
  var h = 5381;
  for (final s in names) {
    for (final c in s.codeUnits) {
      h = ((h << 5) + h + c) & 0x7FFFFFFF;
    }
  }
  return h;
}

// Builds a schedule that round-robins through groups:
//   match 1 from group A, match 1 from group B, match 1 from group C, match 1 from group D,
//   match 2 from group A, match 2 from group B, ...
// Within each group slot, picks randomly among candidates whose teams haven't
// just played (seeded so the order is identical on every save/resume cycle).
List<TournamentMatch> _buildSchedule(List<TournamentGroup> groups, int seed) {
  final rng = Random(seed);
  // Separate pool per group
  final pools = groups.map((g) => g.matches.toList()).toList();
  final result = <TournamentMatch>[];

  while (pools.any((p) => p.isNotEmpty)) {
    for (int gi = 0; gi < pools.length; gi++) {
      if (pools[gi].isEmpty) continue;

      final lastTeams = result.isEmpty
          ? <String>{}
          : {result.last.team1Name, result.last.team2Name};

      // Prefer a match whose teams haven't just played; fall back to any.
      final valid = pools[gi]
          .where((m) =>
              !lastTeams.contains(m.team1Name) &&
              !lastTeams.contains(m.team2Name))
          .toList();
      final pick =
          valid.isNotEmpty ? valid[rng.nextInt(valid.length)] : pools[gi].first;
      pools[gi].remove(pick);
      result.add(pick);
    }
  }
  return result;
}

// ── Series ────────────────────────────────────────────────────────────────────

class SeriesState {
  final List<TournamentTeam> teams;
  final int overs;
  final MatchFormat format;
  final int days;
  final int totalMatches;
  List<TournamentMatch> matches = [];

  int get ballsPerInnings {
    if (format == MatchFormat.test) return 0;
    return overs * (format == MatchFormat.hundred ? 5 : 6);
  }

  SeriesState({
    required this.teams,
    required this.overs,
    required this.totalMatches,
    this.format = MatchFormat.t20,
    this.days = 5,
  }) {
    for (int i = 0; i < totalMatches; i++) {
      matches.add(TournamentMatch(
        team1Name: teams[i.isEven ? 0 : 1].name,
        team2Name: teams[i.isEven ? 1 : 0].name,
        phase: 'Match ${i + 1}',
      ));
    }
  }

  int winsFor(String name) =>
      matches.where((m) => m.isPlayed && m.winnerName == name).length;
  int get ties => matches.where((m) => m.isPlayed && m.isTie).length;
  bool get isComplete => matches.every((m) => m.isPlayed);

  String get seriesResult {
    if (!isComplete) return '';
    final w1 = winsFor(teams[0].name);
    final w2 = winsFor(teams[1].name);
    if (w1 > w2) return '${teams[0].name} wins the series $w1–$w2';
    if (w2 > w1) return '${teams[1].name} wins the series $w2–$w1';
    return 'Series Tied $w1–$w2';
  }
}

// ── Tri-Series ────────────────────────────────────────────────────────────────

class TriSeriesState {
  final List<TournamentTeam> teams;
  final int overs;
  final MatchFormat format;
  List<TournamentMatch> leagueMatches = [];
  TournamentMatch? finalMatch;

  int get ballsPerInnings => overs * (format == MatchFormat.hundred ? 5 : 6);

  TriSeriesState({required this.teams, required this.overs, this.format = MatchFormat.t20}) {
    // Each pair plays twice → 6 matches
    for (int round = 0; round < 2; round++) {
      for (int i = 0; i < teams.length; i++) {
        for (int j = i + 1; j < teams.length; j++) {
          leagueMatches.add(TournamentMatch(
            team1Name: teams[round.isEven ? i : j].name,
            team2Name: teams[round.isEven ? j : i].name,
            phase: 'League',
          ));
        }
      }
    }
    leagueMatches.shuffle();
  }

  List<TeamStanding> get standings {
    final map = {for (final t in teams) t.name: TeamStanding(t.name)};
    for (final m in leagueMatches) {
      if (!m.isPlayed) continue;
      _applyMatchResult(m, map[m.team1Name]!, map[m.team2Name]!, ballsPerInnings);
    }
    final list = map.values.toList();
    list.sort((a, b) => b.points != a.points
        ? b.points.compareTo(a.points)
        : b.nrr.compareTo(a.nrr));
    return list;
  }

  bool get leagueComplete => leagueMatches.every((m) => m.isPlayed);

  void trySetupFinal() {
    if (!leagueComplete || finalMatch != null) return;
    final top2 = standings.take(2).toList();
    finalMatch = TournamentMatch(
      team1Name: top2[0].teamName,
      team2Name: top2[1].teamName,
      phase: 'Final',
    );
  }

  bool get isComplete => leagueComplete && finalMatch?.isPlayed == true;
  String get champion => finalMatch?.winnerName ?? '';
}

// ── Big Tournament ────────────────────────────────────────────────────────────

class BigTournamentState {
  final List<TournamentTeam> teams;
  final int overs;
  final MatchFormat format;
  final int numPhase1Groups;
  final int phase1AdvanceCount;

  int get ballsPerInnings => overs * (format == MatchFormat.hundred ? 5 : 6);

  List<TournamentGroup> phase1Groups = [];
  List<TournamentGroup>? phase2Groups;
  List<TournamentMatch> phase1Schedule = [];
  List<TournamentMatch> phase2Schedule = [];
  TournamentMatch? sf1, sf2;
  TournamentMatch? finalMatch;

  BigTournamentState({
    required this.teams,
    required this.overs,
    required this.numPhase1Groups,
    required this.phase1AdvanceCount,
    this.format = MatchFormat.t20,
    List<List<String>>? groupAssignments,
  }) {
    _buildPhase1(groupAssignments);
  }

  void _buildPhase1(List<List<String>>? assignments) {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    for (int i = 0; i < numPhase1Groups; i++) {
      final List<String> names;
      if (assignments != null) {
        names = List.from(assignments[i]);
      } else {
        final per = teams.length ~/ numPhase1Groups;
        names = teams.sublist(i * per, i * per + per).map((t) => t.name).toList();
      }
      final g = TournamentGroup(
        name: 'Group ${labels[i]}',
        teamNames: names,
        advanceCount: phase1AdvanceCount,
      )..generateMatches();
      phase1Groups.add(g);
    }
    final p1Names = phase1Groups.expand((g) => g.teamNames).toList();
    phase1Schedule = _buildSchedule(phase1Groups, _teamSeed(p1Names));
  }

  int get phase1QualifierCount => numPhase1Groups * phase1AdvanceCount;
  bool get phase1Complete => phase1Groups.every((g) => g.isComplete);

  void tryAdvancePhase1() {
    if (!phase1Complete) return;
    final count = phase1QualifierCount;
    if (count == 8) {
      _buildPhase2();
    } else if (count >= 4) {
      _buildSemis(phase1Groups);
    } else if (count == 2) {
      final q = phase1Groups.expand((g) => g.qualifiers(ballsPerInnings)).toList();
      finalMatch = TournamentMatch(team1Name: q[0], team2Name: q[1], phase: 'Final');
    }
  }

  void _buildPhase2() {
    final half = phase1Groups.length ~/ 2;
    final sg1Names =
        phase1Groups.take(half).expand((g) => g.qualifiers(ballsPerInnings)).toList();
    final sg2Names =
        phase1Groups.skip(half).expand((g) => g.qualifiers(ballsPerInnings)).toList();
    phase2Groups = [
      TournamentGroup(name: 'Super Group 1', teamNames: sg1Names, advanceCount: 2)
        ..generateMatches(),
      TournamentGroup(name: 'Super Group 2', teamNames: sg2Names, advanceCount: 2)
        ..generateMatches(),
    ];
    final p2Names = phase2Groups!.expand((g) => g.teamNames).toList();
    phase2Schedule = _buildSchedule(phase2Groups!, _teamSeed(p2Names));
  }

  bool get phase2Complete => phase2Groups?.every((g) => g.isComplete) ?? false;

  void tryAdvancePhase2() {
    if (phase2Groups == null || !phase2Complete) return;
    _buildSemis(phase2Groups!);
  }

  void _buildSemis(List<TournamentGroup> groups) {
    if (groups.length >= 2) {
      final g1 = groups[0].computedStandings(ballsPerInnings);
      final g2 = groups[1].computedStandings(ballsPerInnings);
      sf1 = TournamentMatch(
          team1Name: g1[0].teamName, team2Name: g2[1].teamName, phase: 'Semi-Final 1');
      sf2 = TournamentMatch(
          team1Name: g2[0].teamName, team2Name: g1[1].teamName, phase: 'Semi-Final 2');
    } else {
      final g = groups[0].computedStandings(ballsPerInnings);
      sf1 = TournamentMatch(
          team1Name: g[0].teamName, team2Name: g[3].teamName, phase: 'Semi-Final 1');
      sf2 = TournamentMatch(
          team1Name: g[1].teamName, team2Name: g[2].teamName, phase: 'Semi-Final 2');
    }
  }

  bool get semisReady => sf1 != null && sf2 != null;
  bool get semisComplete => sf1?.isPlayed == true && sf2?.isPlayed == true;

  void trySetupFinal() {
    if (!semisComplete || finalMatch != null) return;
    finalMatch = TournamentMatch(
        team1Name: sf1!.winnerName,
        team2Name: sf2!.winnerName,
        phase: 'Final');
  }

  bool get isComplete => finalMatch?.isPlayed == true;
  String get champion => finalMatch?.winnerName ?? '';

  TournamentTeam teamByName(String name) =>
      teams.firstWhere((t) => t.name == name);
}

// ── Multi-Format Series ───────────────────────────────────────────────────────

class FormatSegment {
  final MatchFormat format;
  final int matchCount;
  final int days; // Test only
  final String team1Name;
  final String team2Name;
  final List<TournamentMatch> matches;

  FormatSegment({
    required this.format,
    required this.matchCount,
    required this.team1Name,
    required this.team2Name,
    this.days = 5,
  }) : matches = [] {
    for (int i = 0; i < matchCount; i++) {
      matches.add(TournamentMatch(
        team1Name: i.isEven ? team1Name : team2Name,
        team2Name: i.isEven ? team2Name : team1Name,
        phase: 'Match ${i + 1}',
      ));
    }
  }

  String get formatLabel => switch (format) {
    MatchFormat.t10 => 'T10',
    MatchFormat.t20 => 'T20',
    MatchFormat.odi => 'ODI',
    MatchFormat.hundred => 'Hundred',
    MatchFormat.test => 'Test',
  };

  int get overs => switch (format) {
    MatchFormat.t10 => 10,
    MatchFormat.t20 => 20,
    MatchFormat.odi => 50,
    MatchFormat.hundred => 20,
    MatchFormat.test => days * 90,
  };

  int get ballsPerInnings {
    if (format == MatchFormat.test) return 0;
    return overs * (format == MatchFormat.hundred ? 5 : 6);
  }

  bool get isComplete => matches.every((m) => m.isPlayed);
  int get playedCount => matches.where((m) => m.isPlayed).length;

  int winsFor(String name) =>
      matches.where((m) => m.isPlayed && m.winnerName == name).length;
  int get ties => matches.where((m) => m.isPlayed && m.isTie).length;

  /// Returns winner name, empty string for tie, null if undecided.
  String? get winner {
    final needed = (matchCount ~/ 2) + 1;
    if (winsFor(team1Name) >= needed) return team1Name;
    if (winsFor(team2Name) >= needed) return team2Name;
    if (isComplete) {
      final w1 = winsFor(team1Name);
      final w2 = winsFor(team2Name);
      if (w1 > w2) return team1Name;
      if (w2 > w1) return team2Name;
      return ''; // tied
    }
    return null;
  }

  String get resultText {
    final w = winner;
    if (w == null) return '';
    final w1 = winsFor(team1Name);
    final w2 = winsFor(team2Name);
    if (w.isEmpty) return '$formatLabel Series tied $w1–$w2';
    final wWins = w == team1Name ? w1 : w2;
    final lWins = w == team1Name ? w2 : w1;
    return '$w won the $formatLabel Series $wWins–$lWins';
  }
}

class MultiFormatSeriesState {
  final List<TournamentTeam> teams;
  final List<FormatSegment> segments;

  MultiFormatSeriesState({required this.teams, required this.segments});

  String get team1Name => teams[0].name;
  String get team2Name => teams[1].name;
  bool get isComplete => segments.every((s) => s.isComplete);

  FormatSegment? segmentFor(TournamentMatch match) {
    for (final seg in segments) {
      if (seg.matches.contains(match)) return seg;
    }
    return null;
  }

  bool isMatchPlayable(TournamentMatch match) {
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (!seg.matches.contains(match)) continue;
      // All previous segments must be fully played
      for (int j = 0; j < i; j++) {
        if (!segments[j].isComplete) return false;
      }
      // Must be the first unplayed match in this segment
      final firstUnplayed =
          seg.matches.firstWhere((m) => !m.isPlayed, orElse: () => match);
      return identical(firstUnplayed, match);
    }
    return false;
  }

  String get overallResult {
    if (!isComplete) return '';
    int t1f = 0, t2f = 0;
    for (final seg in segments) {
      final w = seg.winner;
      if (w == team1Name) {
        t1f++;
      } else if (w == team2Name) {
        t2f++;
      }
    }
    if (t1f > t2f) { return '$team1Name won the tour $t1f–$t2f'; }
    if (t2f > t1f) { return '$team2Name won the tour $t2f–$t1f'; }
    return 'Tour ended level $t1f–$t2f';
  }
}

// ── International Cup ─────────────────────────────────────────────────────────

enum CupType { odiWorldCup, t20WorldCup, asiaCup, championsTrophy }

class InternationalCupState {
  final CupType cupType;
  final List<TournamentTeam> teams;

  List<TournamentGroup> phase1Groups = [];
  List<TournamentMatch> phase1Schedule = [];
  List<TournamentGroup>? phase2Groups;
  List<TournamentMatch> phase2Schedule = [];
  TournamentMatch? sf1, sf2, finalMatch;

  InternationalCupState({
    required this.cupType,
    required this.teams,
    required List<List<String>> groupAssignments,
  }) {
    _buildPhase1(groupAssignments);
  }

  InternationalCupState.restore({
    required this.cupType,
    required this.teams,
  });

  String get title => switch (cupType) {
        CupType.odiWorldCup => 'ICC ODI World Cup',
        CupType.t20WorldCup => 'ICC T20 World Cup',
        CupType.asiaCup => 'Asia Cup',
        CupType.championsTrophy => 'ICC Champions Trophy',
      };

  MatchFormat get format => switch (cupType) {
        CupType.t20WorldCup || CupType.asiaCup => MatchFormat.t20,
        _ => MatchFormat.odi,
      };

  int get overs => format == MatchFormat.t20 ? 20 : 50;
  int get ballsPerInnings => overs * 6;
  int get phase1AdvanceCount => cupType == CupType.odiWorldCup ? 4 : 2;

  bool get hasPhase2 =>
      cupType == CupType.t20WorldCup || cupType == CupType.asiaCup;
  bool get hasSemiFinals => cupType != CupType.asiaCup;

  bool get phase1Complete => phase1Groups.every((g) => g.isComplete);
  bool get phase2Complete => phase2Groups?.every((g) => g.isComplete) ?? false;
  bool get semisComplete => sf1?.isPlayed == true && sf2?.isPlayed == true;
  bool get isComplete => finalMatch?.isPlayed == true;
  String get champion => finalMatch?.winnerName ?? '';

  TournamentTeam teamByName(String name) =>
      teams.firstWhere((t) => t.name == name);

  void _buildPhase1(List<List<String>> assignments) {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    for (int i = 0; i < assignments.length; i++) {
      final g = TournamentGroup(
        name: assignments.length == 1 ? 'Group Stage' : 'Group ${labels[i]}',
        teamNames: List.from(assignments[i]),
        advanceCount: phase1AdvanceCount,
      )..generateMatches();
      phase1Groups.add(g);
    }
    final p1Names = phase1Groups.expand((g) => g.teamNames).toList();
    phase1Schedule = _buildSchedule(phase1Groups, _teamSeed(p1Names));
  }

  void tryAdvancePhase1() {
    if (!phase1Complete) return;
    if (phase2Groups != null || sf1 != null || finalMatch != null) return;
    if (hasPhase2) {
      _buildPhase2();
    } else {
      _buildSemis(phase1Groups);
    }
  }

  void _buildPhase2() {
    final isAsiaCup = cupType == CupType.asiaCup;
    if (isAsiaCup) {
      final all = phase1Groups
          .expand((g) => g.qualifiers(ballsPerInnings))
          .toList();
      phase2Groups = [
        TournamentGroup(name: 'Super 4', teamNames: all, advanceCount: 2)
          ..generateMatches(),
      ];
    } else {
      // T20 WC: cross-group Super 8
      final half = phase1Groups.length ~/ 2;
      final sg1 = phase1Groups
          .take(half)
          .expand((g) => g.qualifiers(ballsPerInnings))
          .toList();
      final sg2 = phase1Groups
          .skip(half)
          .expand((g) => g.qualifiers(ballsPerInnings))
          .toList();
      phase2Groups = [
        TournamentGroup(name: 'Super 8 Group 1', teamNames: sg1, advanceCount: 2)
          ..generateMatches(),
        TournamentGroup(name: 'Super 8 Group 2', teamNames: sg2, advanceCount: 2)
          ..generateMatches(),
      ];
    }
    final p2Names = phase2Groups!.expand((g) => g.teamNames).toList();
    phase2Schedule = _buildSchedule(phase2Groups!, _teamSeed(p2Names));
  }

  void tryAdvancePhase2() {
    if (phase2Groups == null || !phase2Complete) return;
    if (sf1 != null || finalMatch != null) return;
    if (hasSemiFinals) {
      _buildSemis(phase2Groups!);
    } else {
      // Asia Cup: top 2 of Super 4 → direct final
      final st = phase2Groups![0].computedStandings(ballsPerInnings);
      finalMatch = TournamentMatch(
          team1Name: st[0].teamName, team2Name: st[1].teamName, phase: 'Final');
    }
  }

  void _buildSemis(List<TournamentGroup> groups) {
    if (groups.length == 1) {
      final st = groups[0].computedStandings(ballsPerInnings);
      sf1 = TournamentMatch(
          team1Name: st[0].teamName, team2Name: st[3].teamName, phase: 'Semi-Final 1');
      sf2 = TournamentMatch(
          team1Name: st[1].teamName, team2Name: st[2].teamName, phase: 'Semi-Final 2');
    } else {
      final g1 = groups[0].computedStandings(ballsPerInnings);
      final g2 = groups[1].computedStandings(ballsPerInnings);
      sf1 = TournamentMatch(
          team1Name: g1[0].teamName, team2Name: g2[1].teamName, phase: 'Semi-Final 1');
      sf2 = TournamentMatch(
          team1Name: g2[0].teamName, team2Name: g1[1].teamName, phase: 'Semi-Final 2');
    }
  }

  void trySetupFinal() {
    if (sf1?.isPlayed != true || sf2?.isPlayed != true || finalMatch != null) return;
    finalMatch = TournamentMatch(
        team1Name: sf1!.winnerName, team2Name: sf2!.winnerName, phase: 'Final');
  }

  List<TournamentMatch> get allPlayedMatches {
    final out = <TournamentMatch>[];
    for (final g in phase1Groups) {
      out.addAll(g.matches.where((m) => m.isPlayed));
    }
    if (phase2Groups != null) {
      for (final g in phase2Groups!) {
        out.addAll(g.matches.where((m) => m.isPlayed));
      }
    }
    if (sf1?.isPlayed == true) out.add(sf1!);
    if (sf2?.isPlayed == true) out.add(sf2!);
    if (finalMatch?.isPlayed == true) out.add(finalMatch!);
    return out;
  }
}

// ── Discriminated union passed to TournamentHomeScreen ────────────────────────

sealed class AnyTournament {
  const AnyTournament();
}

class SeriesHolder extends AnyTournament {
  final SeriesState state;
  const SeriesHolder(this.state);
}

class TriSeriesHolder extends AnyTournament {
  final TriSeriesState state;
  const TriSeriesHolder(this.state);
}

class BigTournamentHolder extends AnyTournament {
  final BigTournamentState state;
  const BigTournamentHolder(this.state);
}

class MultiFormatSeriesHolder extends AnyTournament {
  final MultiFormatSeriesState state;
  const MultiFormatSeriesHolder(this.state);
}

class InternationalCupHolder extends AnyTournament {
  final InternationalCupState state;
  const InternationalCupHolder(this.state);
}
