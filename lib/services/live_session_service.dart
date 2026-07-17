import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models.dart';
import '../tournament_models.dart';
import '../database/app_database.dart';

class LiveSessionService {
  static const _col = 'live';

  // Set when TournamentHomeScreen starts a live session; read by MatchScreen.
  static String? _activeTournamentCode;
  static String? get activeTournamentCode => _activeTournamentCode;
  static void setActiveTournamentCode(String? code) =>
      _activeTournamentCode = code;

  static CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection(_col);

  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return String.fromCharCodes(
        List.generate(6, (_) => chars.codeUnitAt(rand.nextInt(chars.length))));
  }

  static String? _hostName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName?.isNotEmpty == true) return user!.displayName;
    return user?.email ?? 'Host';
  }

  // ── Compact live tick (used for instant score updates) ────────────────────
  // ~300 bytes vs ~10-30KB for full matchState — propagates to viewers faster.

  static Map<String, dynamic> buildTick(MatchState ms) {
    if (ms.matchOver) {
      return {
        'ci': ms.currentInnings,
        'mo': true,
        'mr': ms.matchResult,
        't1': ms.setup.team1Name,
        't2': ms.setup.team2Name,
        'tbf': ms.team1BatsFirst,
        'r': 0, 'w': 0, 'b': 0, 'tg': 0,
        'bpi': ms.setup.ballsPerInnings,
        'bl': <String>[],
        'sx': {'n': '', 'r': 0, 'b': 0},
        'nsx': {'n': '', 'r': 0, 'b': 0},
        'bw': {'n': '', 'b': 0, 'r': 0, 'w': 0},
      };
    }
    final inn = ms.currentInningsObj;
    final striker = inn.striker;
    final nonStriker = inn.nonStriker;
    final bowler = inn.currentBowler;
    return {
      'r': inn.totalRuns,
      'w': inn.wickets,
      'b': inn.balls,
      'bl': List<String>.from(inn.ballLog),
      'ci': ms.currentInnings,
      'mo': false,
      'mr': ms.matchResult,
      't1': ms.setup.team1Name,
      't2': ms.setup.team2Name,
      'tbf': ms.team1BatsFirst,
      'tg': ms.target,
      'bpi': ms.setup.ballsPerInnings,
      'sx': {'n': striker.name, 'r': striker.runsScored, 'b': striker.ballsFaced},
      'nsx': {'n': nonStriker.name, 'r': nonStriker.runsScored, 'b': nonStriker.ballsFaced},
      'bw': {
        'n': bowler.name,
        'b': bowler.ballsBowled,
        'r': bowler.runsConceded,
        'w': bowler.wicketsTaken,
      },
    };
  }

  // Separate write so it reaches Firestore before the larger full-state write.
  static Future<void> pushLiveTick(String code, MatchState ms) async {
    await _ref.doc(code).update({'liveTick': buildTick(ms)});
  }

  // ── Standalone match ──────────────────────────────────────────────────────

  static Future<String> createMatchSession(MatchState ms) async {
    final code = generateCode();
    await _ref.doc(code).set({
      'type': 'match',
      'hostName': _hostName(),
      'matchState': AppDatabase.matchStateToJson(ms),
      'liveTick': buildTick(ms),
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  static Future<void> pushStandaloneMatch(String code, MatchState ms) async {
    await _ref.doc(code).update({
      'matchState': AppDatabase.matchStateToJson(ms),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Tournament / series session ───────────────────────────────────────────

  static Future<String> createTournamentSession(AnyTournament t,
      {String? title}) async {
    final code = generateCode();
    final (type, json) = AppDatabase.tournamentToJson(t);
    await _ref.doc(code).set({
      'type': type,
      'tournamentTitle': title,
      'hostName': _hostName(),
      'tournamentState': json,
      'currentMatchState': null,
      'liveTick': null,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activeTournamentCode = code;
    return code;
  }

  static Future<void> pushTournamentState(String code, AnyTournament t,
      {String? title}) async {
    final (_, json) = AppDatabase.tournamentToJson(t);
    await _ref.doc(code).update({
      if (title != null) 'tournamentTitle': title,
      'tournamentState': json,
      'currentMatchState': null,
      'liveTick': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> pushTournamentCurrentMatch(
      String code, MatchState ms) async {
    await _ref.doc(code).update({
      'currentMatchState': AppDatabase.matchStateToJson(ms),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Session control ───────────────────────────────────────────────────────

  static Future<void> endSession(String code) async {
    await _ref.doc(code).update({
      'isActive': false,
      'currentMatchState': null,
      'liveTick': null,
    });
    if (_activeTournamentCode == code) _activeTournamentCode = null;
  }

  static Future<bool> sessionExists(String code) async =>
      (await _ref.doc(code).get()).exists;

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchSession(
          String code) =>
      _ref.doc(code).snapshots();
}
