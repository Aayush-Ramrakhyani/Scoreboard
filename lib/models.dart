import 'package:flutter/material.dart';

enum PlayerRole { batter, bowler, allRounder }
enum BowlerType { fast, spin }
enum MatchFormat { t10, t20, odi, hundred, test }

class FallOfWicket {
  final int wicketNumber;
  final int score;
  final int balls; // legal balls at time of dismissal
  final String batsmanName;
  const FallOfWicket({
    required this.wicketNumber,
    required this.score,
    required this.balls,
    required this.batsmanName,
  });
}

class PartnershipEntry {
  final String bat1Name;
  final int bat1Runs;
  final int bat1Balls;
  final String bat2Name;
  final int bat2Runs;
  final int bat2Balls;
  final int totalRuns;
  final int totalBalls;
  const PartnershipEntry({
    required this.bat1Name,
    required this.bat1Runs,
    required this.bat1Balls,
    required this.bat2Name,
    required this.bat2Runs,
    required this.bat2Balls,
    required this.totalRuns,
    required this.totalBalls,
  });
}

class PlayerInfo {
  final String name;
  final PlayerRole role;
  final BowlerType? bowlerType;
  final bool isCaptain;
  final bool isWicketKeeper;

  const PlayerInfo({
    required this.name,
    required this.role,
    this.bowlerType,
    this.isCaptain = false,
    this.isWicketKeeper = false,
  });
}

class Player {
  String name;
  PlayerRole role;
  BowlerType? bowlerType;
  bool isCaptain;
  bool isWicketKeeper;

  // batting
  int runsScored = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;
  bool isOut = false;
  bool hasPlayedInnings = false;
  String dismissalInfo = '';

  // bowling
  int ballsBowled = 0;
  int runsConceded = 0;
  int wicketsTaken = 0;
  int widesBowled = 0;
  int noBallsBowled = 0;
  int maidens = 0;
  int _lastOverStartRuns = 0;

  Player(
    this.name, {
    this.role = PlayerRole.batter,
    this.bowlerType,
    this.isCaptain = false,
    this.isWicketKeeper = false,
  });

  double get strikeRate =>
      ballsFaced == 0 ? 0 : (runsScored / ballsFaced) * 100;

  // Default over display (6-ball overs)
  String get oversString => setsString(6);

  // Parameterized for non-6-ball formats (e.g. Hundred uses setSize=5)
  String setsString(int setSize) {
    final completed = ballsBowled ~/ setSize;
    final rem = ballsBowled % setSize;
    return '$completed.$rem';
  }

  double get economy {
    if (ballsBowled == 0) return 0;
    return (runsConceded / ballsBowled) * 6;
  }

  void startNewOver() => _lastOverStartRuns = runsConceded;
  bool checkMaiden() => runsConceded == _lastOverStartRuns;

  List<({String label, Color color})> get badges {
    final list = <({String label, Color color})>[];
    if (isWicketKeeper) list.add((label: 'WK', color: const Color(0xFF1565C0)));
    if (isCaptain) list.add((label: 'C', color: const Color(0xFFF9A825)));
    switch (role) {
      case PlayerRole.bowler:
        if (bowlerType != null) {
          list.add((
            label: bowlerType == BowlerType.fast ? 'Fast' : 'Spin',
            color: bowlerType == BowlerType.fast
                ? const Color(0xFFBF360C)
                : const Color(0xFF4527A0),
          ));
        }
      case PlayerRole.allRounder:
        if (bowlerType != null) {
          list.add((
            label: bowlerType == BowlerType.fast ? 'AR-F' : 'AR-S',
            color: bowlerType == BowlerType.fast
                ? const Color(0xFFBF360C)
                : const Color(0xFF6A1B9A),
          ));
        }
      case PlayerRole.batter:
        list.add((label: 'Bat', color: const Color(0xFF2E7D32)));
    }
    return list;
  }
}

class Innings {
  final List<Player> battingTeamPlayers;
  final List<Player> bowlingTeamPlayers;
  int totalRuns = 0;
  int wickets = 0;
  int balls = 0;
  List<String> ballLog = [];
  List<List<String>> overHistory = [];
  int wides = 0;
  int noBalls = 0;
  int byes = 0;
  int legByes = 0;
  bool isComplete = false;

  int strikerIndex = 0;
  int nonStrikerIndex = 1;
  int nextBatsmanIndex = 2;
  int currentBowlerIndex = 0;

  List<FallOfWicket> fallOfWickets = [];
  List<PartnershipEntry> partnerships = [];

  // Partnership snapshot tracking
  int _pStartRuns = 0;
  int _pStartBalls = 0;
  Map<int, ({int runs, int balls})> _pStartStats = {};

  Innings(this.battingTeamPlayers, this.bowlingTeamPlayers);

  Player get striker => battingTeamPlayers[strikerIndex];
  Player get nonStriker => battingTeamPlayers[nonStrikerIndex];
  Player get currentBowler => bowlingTeamPlayers[currentBowlerIndex];

  void startPartnership() {
    _pStartRuns = totalRuns;
    _pStartBalls = balls;
    _pStartStats = {
      strikerIndex: (
        runs: battingTeamPlayers[strikerIndex].runsScored,
        balls: battingTeamPlayers[strikerIndex].ballsFaced,
      ),
      nonStrikerIndex: (
        runs: battingTeamPlayers[nonStrikerIndex].runsScored,
        balls: battingTeamPlayers[nonStrikerIndex].ballsFaced,
      ),
    };
  }

  void savePartnership({required int outIdx, required int partnerIdx}) {
    final b1 = battingTeamPlayers[outIdx];
    final b2 = battingTeamPlayers[partnerIdx];
    final b1s = _pStartStats[outIdx] ?? (runs: 0, balls: 0);
    final b2s = _pStartStats[partnerIdx] ?? (runs: 0, balls: 0);
    partnerships.add(PartnershipEntry(
      bat1Name: b1.name,
      bat1Runs: b1.runsScored - b1s.runs,
      bat1Balls: b1.ballsFaced - b1s.balls,
      bat2Name: b2.name,
      bat2Runs: b2.runsScored - b2s.runs,
      bat2Balls: b2.ballsFaced - b2s.balls,
      totalRuns: totalRuns - _pStartRuns,
      totalBalls: balls - _pStartBalls,
    ));
    // Reset to prevent double-save if innings ends immediately after
    _pStartRuns = totalRuns;
    _pStartBalls = balls;
    _pStartStats = {};
  }

  void saveCurrentPartnership() {
    if (balls == _pStartBalls && totalRuns == _pStartRuns) return;
    final b1 = battingTeamPlayers[strikerIndex];
    final b2 = battingTeamPlayers[nonStrikerIndex];
    final b1s = _pStartStats[strikerIndex] ?? (runs: 0, balls: 0);
    final b2s = _pStartStats[nonStrikerIndex] ?? (runs: 0, balls: 0);
    partnerships.add(PartnershipEntry(
      bat1Name: b1.name,
      bat1Runs: b1.runsScored - b1s.runs,
      bat1Balls: b1.ballsFaced - b1s.balls,
      bat2Name: b2.name,
      bat2Runs: b2.runsScored - b2s.runs,
      bat2Balls: b2.ballsFaced - b2s.balls,
      totalRuns: totalRuns - _pStartRuns,
      totalBalls: balls - _pStartBalls,
    ));
  }

  // Parameterized display for different set sizes
  String oversDisplayFor(int setSize) {
    final completed = balls ~/ setSize;
    final rem = balls % setSize;
    return '$completed.$rem';
  }

  String get oversDisplay => oversDisplayFor(6);

  int get totalExtras => wides + noBalls + byes + legByes;
  bool get isOverComplete => balls % 6 == 0 && balls > 0;
}

class MatchSetup {
  String team1Name;
  String team2Name;
  List<PlayerInfo> team1Players;
  List<PlayerInfo> team2Players;
  MatchFormat format;
  int days; // Test only: 3, 4, or 5

  MatchSetup({
    required this.team1Name,
    required this.team2Name,
    required this.team1Players,
    required this.team2Players,
    required this.format,
    this.days = 5,
  });

  bool get isHundred => format == MatchFormat.hundred;
  bool get isTest => format == MatchFormat.test;

  // Balls per "over" (5 for Hundred, 6 for everything else)
  int get setSize => isHundred ? 5 : 6;

  // Overs per innings for display and quota math
  int get overs {
    switch (format) {
      case MatchFormat.t10: return 10;
      case MatchFormat.t20: return 20;
      case MatchFormat.odi: return 50;
      case MatchFormat.hundred: return 20; // 20 sets of 5 = 100 balls
      case MatchFormat.test: return days * 90; // total match overs (not per-innings)
    }
  }

  // Total balls per innings (0 = unlimited for Test)
  int get ballsPerInnings {
    if (isTest) return 0;
    return overs * setSize; // T10=60, T20=120, ODI=300, Hundred=100
  }

  String get formatLabel {
    switch (format) {
      case MatchFormat.t10: return 'T10';
      case MatchFormat.t20: return 'T20';
      case MatchFormat.odi: return 'ODI';
      case MatchFormat.hundred: return 'The Hundred';
      case MatchFormat.test: return 'Test ($days days)';
    }
  }
}

class MatchState {
  final MatchSetup setup;
  late List<Player> team1Players;
  late List<Player> team2Players;
  late Innings innings1;
  late Innings innings2;
  Innings? innings3; // Test 2nd innings for team that batted 1st
  Innings? innings4; // Test 2nd innings for team that batted 2nd
  int currentInnings = 1;
  bool team1BatsFirst = true;
  bool matchOver = false;
  String matchResult = '';
  String winnerName = '';

  MatchState(this.setup) {
    team1Players = _makePlayers(setup.team1Players);
    team2Players = _makePlayers(setup.team2Players);
  }

  List<Player> _makePlayers(List<PlayerInfo> infos) => infos
      .map((pi) => Player(pi.name,
          role: pi.role,
          bowlerType: pi.bowlerType,
          isCaptain: pi.isCaptain,
          isWicketKeeper: pi.isWicketKeeper))
      .toList();

  void _resetBattingStats(List<Player> players) {
    for (final p in players) {
      p.runsScored = 0;
      p.ballsFaced = 0;
      p.fours = 0;
      p.sixes = 0;
      p.isOut = false;
      p.hasPlayedInnings = false;
      p.dismissalInfo = '';
    }
  }

  void startInnings() {
    if (currentInnings == 1) {
      final batting = team1BatsFirst ? team1Players : team2Players;
      final bowling = team1BatsFirst ? team2Players : team1Players;
      innings1 = Innings(batting, bowling);
    } else if (currentInnings == 2) {
      final batting = team1BatsFirst ? team2Players : team1Players;
      final bowling = team1BatsFirst ? team1Players : team2Players;
      innings2 = Innings(batting, bowling);
    } else if (currentInnings == 3) {
      // Same batting team as inn1 — reset their batting stats for 2nd innings
      final batting = team1BatsFirst ? team1Players : team2Players;
      final bowling = team1BatsFirst ? team2Players : team1Players;
      _resetBattingStats(batting);
      innings3 = Innings(batting, bowling);
    } else if (currentInnings == 4) {
      // Same batting team as inn2 — reset their batting stats for 2nd innings
      final batting = team1BatsFirst ? team2Players : team1Players;
      final bowling = team1BatsFirst ? team1Players : team2Players;
      _resetBattingStats(batting);
      innings4 = Innings(batting, bowling);
    }
  }

  Innings get currentInningsObj {
    switch (currentInnings) {
      case 1:
        return innings1;
      case 2:
        return innings2;
      case 3:
        return innings3!;
      case 4:
        return innings4!;
      default:
        return innings2;
    }
  }

  // Odd innings (1,3) → same team bats as inn1. Even (2,4) → opposite.
  String get battingTeamName => currentInnings.isOdd
      ? (team1BatsFirst ? setup.team1Name : setup.team2Name)
      : (team1BatsFirst ? setup.team2Name : setup.team1Name);

  String get bowlingTeamName => currentInnings.isOdd
      ? (team1BatsFirst ? setup.team2Name : setup.team1Name)
      : (team1BatsFirst ? setup.team1Name : setup.team2Name);

  int get target {
    if (setup.isTest) {
      if (currentInnings == 4) {
        // Team B needs: (inn1 + inn3) − inn2 + 1
        return innings1.totalRuns + (innings3?.totalRuns ?? 0) - innings2.totalRuns + 1;
      }
      return 0;
    }
    return currentInnings == 2 ? innings1.totalRuns + 1 : 0;
  }

  int get runsNeeded {
    if (!setup.isTest && currentInnings == 2) return target - innings2.totalRuns;
    if (setup.isTest && currentInnings == 4) return target - innings4!.totalRuns;
    return 0;
  }

  int get ballsRemaining {
    if (setup.isTest) return 0; // no ball limit per innings in Test
    if (currentInnings == 2) return setup.ballsPerInnings - innings2.balls;
    return 0;
  }
}
