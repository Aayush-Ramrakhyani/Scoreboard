import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../tournament_models.dart';
import '../services/motm_service.dart';

class HistoryEntry {
  final String id;
  final String? firestoreId; // non-null for Firestore-backed tournament entries
  final String type; // 'match' | 'series' | 'triseries' | 'multiformat' | 'tournament'
  final String title;
  final String result;
  final String format;
  final int timestamp;
  final String? mom; // Man of the Match / Tournament

  const HistoryEntry({
    required this.id,
    this.firestoreId,
    required this.type,
    required this.title,
    required this.result,
    required this.format,
    required this.timestamp,
    this.mom,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (firestoreId != null) 'firestoreId': firestoreId,
        'type': type,
        'title': title,
        'result': result,
        'format': format,
        'ts': timestamp,
        if (mom != null) 'mom': mom,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> m) => HistoryEntry(
        id: m['id'] as String,
        firestoreId: m['firestoreId'] as String?,
        type: m['type'] as String,
        title: m['title'] as String,
        result: m['result'] as String,
        format: m['format'] as String,
        timestamp: m['ts'] as int,
        mom: m['mom'] as String?,
      );
}

class HistoryDatabase {
  static const _kHistory = 'match_history';
  static const _maxEntries = 200;

  static String _fmtLabel(MatchFormat f) => switch (f) {
        MatchFormat.t10 => 'T10',
        MatchFormat.t20 => 'T20',
        MatchFormat.odi => 'ODI',
        MatchFormat.test => 'Test',
        _ => 'Cricket',
      };

  static Future<void> addMatch(MatchState ms) {
    final mom = MotmService.calculateMotm(ms);
    return _add(HistoryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: 'match',
      title: '${ms.setup.team1Name} vs ${ms.setup.team2Name}',
      result: ms.matchResult.isNotEmpty ? ms.matchResult : 'Match completed',
      format: _fmtLabel(ms.setup.format),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      mom: mom != null ? '${mom.playerName} (${mom.teamName})' : null,
    ));
  }

  static List<TournamentMatch> _playedMatches(AnyTournament t) {
    final out = <TournamentMatch>[];
    switch (t) {
      case SeriesHolder(:var state):
        out.addAll(state.matches.where((m) => m.isPlayed));
      case TriSeriesHolder(:var state):
        out.addAll(state.leagueMatches.where((m) => m.isPlayed));
        if (state.finalMatch?.isPlayed == true) out.add(state.finalMatch!);
      case BigTournamentHolder(:var state):
        out.addAll(state.phase1Schedule.where((m) => m.isPlayed));
        out.addAll(state.phase2Schedule.where((m) => m.isPlayed));
        if (state.sf1?.isPlayed == true) out.add(state.sf1!);
        if (state.sf2?.isPlayed == true) out.add(state.sf2!);
        if (state.finalMatch?.isPlayed == true) out.add(state.finalMatch!);
      case MultiFormatSeriesHolder(:var state):
        for (final seg in state.segments) {
          out.addAll(seg.matches.where((m) => m.isPlayed));
        }
    }
    return out;
  }

  static Future<void> addTournament(AnyTournament t) async {
    late String type, title, result, format;
    switch (t) {
      case SeriesHolder(:var state):
        type = 'series';
        title = '${state.teams[0].name} vs ${state.teams[1].name}';
        result = state.seriesResult.isNotEmpty ? state.seriesResult : 'Series completed';
        format = '${state.totalMatches}-match ${_fmtLabel(state.format)}';
      case TriSeriesHolder(:var state):
        type = 'triseries';
        title = 'Tri-Series · ${state.teams.map((x) => x.name).join(', ')}';
        result = state.isComplete ? '${state.champion} wins the Tri-Series!' : 'Tri-Series completed';
        format = _fmtLabel(state.format);
      case BigTournamentHolder(:var state):
        type = 'tournament';
        title = 'Tournament · ${state.teams.length} teams';
        result = state.isComplete ? '${state.champion} wins the Tournament!' : 'Tournament completed';
        format = _fmtLabel(state.format);
      case MultiFormatSeriesHolder(:var state):
        type = 'multiformat';
        title = '${state.team1Name} vs ${state.team2Name}';
        result = state.isComplete ? state.overallResult : 'Series completed';
        format = 'Multi-Format';
    }
    final mott = MotmService.calculateMott(_playedMatches(t));
    await _add(HistoryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      result: result,
      format: format,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      mom: mott != null ? '${mott.playerName} (${mott.teamName})' : null,
    ));
  }

  static Future<void> _add(HistoryEntry entry) async {
    final all = await loadAll();
    all.insert(0, entry);
    if (all.length > _maxEntries) all.removeRange(_maxEntries, all.length);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHistory, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<List<HistoryEntry>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kHistory);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> removeEntry(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHistory, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kHistory);
  }
}
