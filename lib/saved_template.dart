import 'models.dart';
import 'tournament_models.dart';

// ── Team inside a template ────────────────────────────────────────────────────

class TemplateTeam {
  String name;
  List<PlayerInfo> players;

  TemplateTeam({required this.name, required this.players});

  Map<String, dynamic> toJson() => {
        'name': name,
        'players': players
            .map((p) => {
                  'name': p.name,
                  'role': p.role.index,
                  'bowlerType': p.bowlerType?.index,
                  'isWicketKeeper': p.isWicketKeeper,
                  'isCaptain': p.isCaptain,
                })
            .toList(),
      };

  factory TemplateTeam.fromJson(Map<String, dynamic> m) => TemplateTeam(
        name: m['name'] as String,
        players: (m['players'] as List).map((e) {
          final p = e as Map<String, dynamic>;
          return PlayerInfo(
            name: p['name'] as String,
            role: PlayerRole.values[p['role'] as int],
            bowlerType: p['bowlerType'] != null
                ? BowlerType.values[p['bowlerType'] as int]
                : null,
            isWicketKeeper: p['isWicketKeeper'] as bool? ?? false,
            isCaptain: p['isCaptain'] as bool? ?? false,
          );
        }).toList(),
      );

  TournamentTeam toTournamentTeam() => TournamentTeam(name: name, players: players);
}

// ── Segment config (multi-format series) ─────────────────────────────────────

class TemplateSegment {
  MatchFormat format;
  int matchCount;
  int days;

  TemplateSegment({required this.format, required this.matchCount, required this.days});

  Map<String, dynamic> toJson() => {
        'format': format.index,
        'matchCount': matchCount,
        'days': days,
      };

  factory TemplateSegment.fromJson(Map<String, dynamic> m) => TemplateSegment(
        format: MatchFormat.values[m['format'] as int],
        matchCount: m['matchCount'] as int,
        days: m['days'] as int? ?? 5,
      );

  String get label {
    final f = switch (format) {
      MatchFormat.t10 => 'T10',
      MatchFormat.t20 => 'T20',
      MatchFormat.odi => 'ODI',
      MatchFormat.hundred => '100',
      MatchFormat.test => 'Test',
    };
    return '$matchCount×$f';
  }
}

// ── Main template ─────────────────────────────────────────────────────────────

class SavedTemplate {
  String id;
  String name;
  String type; // 'series' | 'triseries' | 'tournament' | 'multiformat'
  List<TemplateTeam> teams;
  MatchFormat format;

  // Series
  int numMatches;
  int days;

  // Big Tournament
  int numGroups;
  int advanceCount;
  List<int> groupOf; // group index per team (0=GroupA, 1=GroupB …)

  // Multi-format
  List<TemplateSegment> segments;

  // Meta
  int season; // starts at 1, increments each time user plays
  int createdAt;
  int updatedAt;

  SavedTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.teams,
    required this.format,
    this.numMatches = 3,
    this.days = 5,
    this.numGroups = 1,
    this.advanceCount = 2,
    List<int>? groupOf,
    List<TemplateSegment>? segments,
    this.season = 1,
    required this.createdAt,
    required this.updatedAt,
  })  : groupOf = groupOf ?? [],
        segments = segments ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'teams': teams.map((t) => t.toJson()).toList(),
        'format': format.index,
        'numMatches': numMatches,
        'days': days,
        'numGroups': numGroups,
        'advanceCount': advanceCount,
        'groupOf': groupOf,
        'segments': segments.map((s) => s.toJson()).toList(),
        'season': season,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory SavedTemplate.fromJson(Map<String, dynamic> m) => SavedTemplate(
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] as String,
        teams: (m['teams'] as List)
            .map((t) => TemplateTeam.fromJson(t as Map<String, dynamic>))
            .toList(),
        format: MatchFormat.values[m['format'] as int],
        numMatches: m['numMatches'] as int? ?? 3,
        days: m['days'] as int? ?? 5,
        numGroups: m['numGroups'] as int? ?? 1,
        advanceCount: m['advanceCount'] as int? ?? 2,
        groupOf: (m['groupOf'] as List? ?? []).map((e) => e as int).toList(),
        segments: (m['segments'] as List? ?? [])
            .map((s) => TemplateSegment.fromJson(s as Map<String, dynamic>))
            .toList(),
        season: m['season'] as int? ?? 1,
        createdAt: m['createdAt'] as int,
        updatedAt: m['updatedAt'] as int,
      );

  String get typeLabel => switch (type) {
        'series' => 'Series',
        'triseries' => 'Tri-Series',
        'tournament' => 'Tournament',
        'multiformat' => 'Multi-Format',
        _ => type,
      };

  String get formatLabel => switch (format) {
        MatchFormat.t10 => 'T10',
        MatchFormat.t20 => 'T20',
        MatchFormat.odi => 'ODI',
        MatchFormat.hundred => '100',
        MatchFormat.test => 'Test',
      };

  String get teamsSummary {
    if (teams.length == 2) return '${teams[0].name} vs ${teams[1].name}';
    if (teams.length == 3) {
      return teams.map((t) => t.name).join(' · ');
    }
    return '${teams.length} teams';
  }

  // Compute overs from format + days
  int get overs => switch (format) {
        MatchFormat.t10 => 10,
        MatchFormat.t20 => 20,
        MatchFormat.odi => 50,
        MatchFormat.hundred => 20,
        MatchFormat.test => days * 90,
      };

  // Build AnyTournament ready to pass to TournamentHomeScreen
  AnyTournament buildTournament() {
    final tt = teams.map((t) => t.toTournamentTeam()).toList();
    switch (type) {
      case 'series':
        return SeriesHolder(SeriesState(
          teams: tt,
          overs: overs,
          format: format,
          days: days,
          totalMatches: numMatches,
        ));
      case 'triseries':
        return TriSeriesHolder(TriSeriesState(
          teams: tt,
          overs: overs,
          format: format,
        ));
      case 'tournament':
        List<List<String>>? assignments;
        if (groupOf.length == teams.length && numGroups > 1) {
          assignments = List.generate(numGroups, (_) => <String>[]);
          for (int i = 0; i < teams.length; i++) {
            final g = groupOf[i].clamp(0, numGroups - 1);
            assignments[g].add(teams[i].name);
          }
        }
        return BigTournamentHolder(BigTournamentState(
          teams: tt,
          overs: overs,
          format: format,
          numPhase1Groups: numGroups,
          phase1AdvanceCount: advanceCount,
          groupAssignments: assignments,
        ));
      case 'multiformat':
        return MultiFormatSeriesHolder(MultiFormatSeriesState(
          teams: tt,
          segments: segments
              .map((s) => FormatSegment(
                    format: s.format,
                    matchCount: s.matchCount,
                    team1Name: tt[0].name,
                    team2Name: tt[1].name,
                    days: s.days,
                  ))
              .toList(),
        ));
    }
    throw ArgumentError('Unknown template type: $type');
  }
}
