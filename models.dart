class Player {
  String name;
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

  Player(this.name);

  double get strikeRate =>
      ballsFaced == 0 ? 0 : (runsScored / ballsFaced) * 100;

  String get oversString {
    final completedOvers = ballsBowled ~/ 6;
    final rem = ballsBowled % 6;
    return '$completedOvers.$rem';
  }

  double get economy {
    if (ballsBowled == 0) return 0;
    return (runsConceded / ballsBowled) * 6;
  }

  void startNewOver() {
    _lastOverStartRuns = runsConceded;
  }

  bool checkMaiden() {
    return runsConceded == _lastOverStartRuns;
  }
}

class Innings {
  final List<Player> battingTeamPlayers;
  final List<Player> bowlingTeamPlayers;
  int totalRuns = 0;
  int wickets = 0;
  int balls = 0; // legal balls
  List<String> ballLog = []; // per-ball log for current over
  List<List<String>> overHistory = [];
  List<String> extras = []; // W, NB, B, LB descriptions
  int wides = 0;
  int noBalls = 0;
  int byes = 0;
  int legByes = 0;
  bool isComplete = false;

  int strikerIndex = 0;
  int nonStrikerIndex = 1;
  int nextBatsmanIndex = 2;
  int currentBowlerIndex = 0;
  int? previousBowlerIndex;

  Innings(this.battingTeamPlayers, this.bowlingTeamPlayers);

  Player get striker => battingTeamPlayers[strikerIndex];
  Player get nonStriker => battingTeamPlayers[nonStrikerIndex];
  Player get currentBowler => bowlingTeamPlayers[currentBowlerIndex];

  String get oversDisplay {
    final completedOvers = balls ~/ 6;
    final rem = balls % 6;
    return '$completedOvers.$rem';
  }

  int get totalExtras => wides + noBalls + byes + legByes;

  bool get isOverComplete => balls % 6 == 0 && balls > 0;
}

class MatchSetup {
  String team1Name;
  String team2Name;
  List<String> team1PlayerNames;
  List<String> team2PlayerNames;
  int overs;

  MatchSetup({
    required this.team1Name,
    required this.team2Name,
    required this.team1PlayerNames,
    required this.team2PlayerNames,
    required this.overs,
  });
}

class MatchState {
  final MatchSetup setup;
  late List<Player> team1Players;
  late List<Player> team2Players;
  late Innings innings1;
  late Innings innings2;
  int currentInnings = 1; // 1 or 2
  bool team1BatsFirst = true;
  bool matchOver = false;
  String matchResult = '';

  MatchState(this.setup) {
    team1Players = setup.team1PlayerNames.map((n) => Player(n)).toList();
    team2Players = setup.team2PlayerNames.map((n) => Player(n)).toList();
  }

  void startInnings() {
    if (currentInnings == 1) {
      final batting = team1BatsFirst ? team1Players : team2Players;
      final bowling = team1BatsFirst ? team2Players : team1Players;
      innings1 = Innings(batting, bowling);
      innings1.battingTeamPlayers[0].hasPlayedInnings = true;
      innings1.battingTeamPlayers[1].hasPlayedInnings = true;
    } else {
      final batting = team1BatsFirst ? team2Players : team1Players;
      final bowling = team1BatsFirst ? team1Players : team2Players;
      innings2 = Innings(batting, bowling);
      innings2.battingTeamPlayers[0].hasPlayedInnings = true;
      innings2.battingTeamPlayers[1].hasPlayedInnings = true;
    }
  }

  Innings get currentInningsObj => currentInnings == 1 ? innings1 : innings2;

  int get target => currentInnings == 2 ? innings1.totalRuns + 1 : 0;

  int get runsNeeded =>
      currentInnings == 2 ? target - innings2.totalRuns : 0;

  int get ballsRemaining =>
      currentInnings == 2
          ? (setup.overs * 6) - innings2.balls
          : 0;

  String get battingTeamName {
    if (currentInnings == 1) {
      return team1BatsFirst ? setup.team1Name : setup.team2Name;
    } else {
      return team1BatsFirst ? setup.team2Name : setup.team1Name;
    }
  }

  String get bowlingTeamName {
    if (currentInnings == 1) {
      return team1BatsFirst ? setup.team2Name : setup.team1Name;
    } else {
      return team1BatsFirst ? setup.team1Name : setup.team2Name;
    }
  }
}
