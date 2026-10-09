import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models.dart';

// ── SavedTeam model ───────────────────────────────────────────────────────────

class SavedTeam {
  final String id;
  final String name;
  final List<PlayerInfo> players;
  final DateTime updatedAt;

  const SavedTeam({
    required this.id,
    required this.name,
    required this.players,
    required this.updatedAt,
  });

  factory SavedTeam.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SavedTeam(
      id: doc.id,
      name: d['name'] as String,
      players: (d['players'] as List<dynamic>)
          .map((p) => _piFromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

Map<String, dynamic> _piToJson(PlayerInfo p) => {
      'name': p.name,
      'role': p.role.name,
      'bowlerType': p.bowlerType?.name,
      'isCaptain': p.isCaptain,
      'isWicketKeeper': p.isWicketKeeper,
    };

PlayerInfo _piFromJson(Map<String, dynamic> m) => PlayerInfo(
      name: m['name'] as String,
      role: PlayerRole.values.firstWhere(
        (r) => r.name == m['role'],
        orElse: () => PlayerRole.batter,
      ),
      bowlerType: m['bowlerType'] == null
          ? null
          : BowlerType.values.firstWhere(
              (b) => b.name == m['bowlerType'],
              orElse: () => BowlerType.fast,
            ),
      isCaptain: (m['isCaptain'] as bool?) ?? false,
      isWicketKeeper: (m['isWicketKeeper'] as bool?) ?? false,
    );

// ── Service ───────────────────────────────────────────────────────────────────

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static final _google = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _db.collection('users').doc(currentUser!.uid).collection('teams');

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<UserCredential> signInWithGoogle() async {
    final gUser = await _google.signIn();
    if (gUser == null) throw Exception('Google sign-in cancelled');
    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  static Future<UserCredential> signInWithEmail(
          String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  static Future<UserCredential> registerWithEmail(
          String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  static Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // ── Teams CRUD ────────────────────────────────────────────────────────────

  static Stream<List<SavedTeam>> teamsStream() => _teamsRef
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SavedTeam.fromDoc).toList());

  static Future<List<SavedTeam>> loadTeams() async {
    final snap = await _teamsRef.orderBy('updatedAt', descending: true).get();
    return snap.docs.map(SavedTeam.fromDoc).toList();
  }

  static Future<void> saveTeam({
    String? id,
    required String name,
    required List<PlayerInfo> players,
  }) async {
    final data = {
      'name': name,
      'players': players.map(_piToJson).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      await _teamsRef.add(data);
    } else {
      await _teamsRef.doc(id).set(data);
    }
  }

  static Future<void> deleteTeam(String id) => _teamsRef.doc(id).delete();
}
