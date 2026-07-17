import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../tournament_models.dart';
import '../database/app_database.dart';
import '../database/history_database.dart';

class TournamentHistoryService {
  static CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tournamentHistory');
  }

  static String newId() => _col().doc().id;

  /// Upsert full tournament data (runs after every match and at completion).
  static Future<void> save(
    String id,
    AnyTournament t, {
    String? title,
    bool isComplete = false,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final (type, state) = AppDatabase.tournamentToJson(t);
    await _col().doc(id).set({
      'id': id,
      'type': type,
      'title': _buildTitle(title, t),
      'result': _buildResult(t),
      'format': _buildFormat(t),
      'isComplete': isComplete,
      'state': state,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Load summary cards for the history list (no full state).
  static Future<List<HistoryEntry>> loadSummaries() async {
    if (FirebaseAuth.instance.currentUser == null) return [];
    try {
      final snap = await _col()
          .orderBy('updatedAt', descending: true)
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        final ts =
            (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch;
        return HistoryEntry(
          id: d.id,
          firestoreId: d.id,
          type: data['type'] as String? ?? 'tournament',
          title: data['title'] as String? ?? '',
          result: data['result'] as String? ?? '',
          format: data['format'] as String? ?? '',
          timestamp: ts,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Load full tournament state for the detail view.
  static Future<AnyTournament?> loadById(String id) async {
    if (FirebaseAuth.instance.currentUser == null) return null;
    try {
      final doc = await _col().doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      final type = data['type'] as String?;
      final state = data['state'] as Map<String, dynamic>?;
      if (type == null || state == null) return null;
      return AppDatabase.tournamentFromJson(type, state);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteById(String id) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await _col().doc(id).delete();
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final snap = await _col().get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  // ── display helpers ───────────────────────────────────────────────────────

  static String _buildTitle(String? custom, AnyTournament t) {
    if (custom != null) return custom;
    return switch (t) {
      SeriesHolder h =>
        '${h.state.teams[0].name} vs ${h.state.teams[1].name} Series',
      TriSeriesHolder h =>
        'Tri-Series · ${h.state.teams.map((x) => x.name).join(', ')}',
      BigTournamentHolder h => 'Tournament · ${h.state.teams.length} teams',
      MultiFormatSeriesHolder h =>
        '${h.state.team1Name} vs ${h.state.team2Name}',
    };
  }

  static String _buildResult(AnyTournament t) => switch (t) {
        SeriesHolder h => h.state.seriesResult.isNotEmpty
            ? h.state.seriesResult
            : 'In progress',
        TriSeriesHolder h =>
          h.state.isComplete ? '${h.state.champion} wins!' : 'In progress',
        BigTournamentHolder h =>
          h.state.isComplete ? '${h.state.champion} wins!' : 'In progress',
        MultiFormatSeriesHolder h =>
          h.state.isComplete ? h.state.overallResult : 'In progress',
      };

  static String _buildFormat(AnyTournament t) => switch (t) {
        SeriesHolder h =>
          '${h.state.totalMatches}-match ${_fmtLabel(h.state.format)}',
        TriSeriesHolder h => _fmtLabel(h.state.format),
        BigTournamentHolder h => _fmtLabel(h.state.format),
        MultiFormatSeriesHolder _ => 'Multi-Format',
      };

  static String _fmtLabel(MatchFormat f) => switch (f) {
        MatchFormat.t10 => 'T10',
        MatchFormat.t20 => 'T20',
        MatchFormat.odi => 'ODI',
        MatchFormat.test => 'Test',
        _ => 'Cricket',
      };
}
