import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../saved_template.dart';
import '../tournament_models.dart';
import '../database/app_database.dart';

class TemplateService {
  static CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('templates');
  }

  static String newId() => _col().doc().id;

  static Future<List<SavedTemplate>> loadAll() async {
    try {
      final snap = await _col().orderBy('updatedAt', descending: true).get();
      return snap.docs.map((d) => SavedTemplate.fromJson(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<SavedTemplate>> loadByType(String type) async {
    try {
      final snap = await _col()
          .where('type', isEqualTo: type)
          .orderBy('updatedAt', descending: true)
          .get();
      return snap.docs.map((d) => SavedTemplate.fromJson(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(SavedTemplate t) async {
    t.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _col().doc(t.id).set(t.toJson());
  }

  static Future<void> delete(String id) async {
    await _col().doc(id).delete();
  }

  /// Increment season counter and update in Firestore.
  static Future<void> incrementSeason(SavedTemplate t) async {
    t.season++;
    await save(t);
  }

  // ── Tournament progress (auto-save across devices) ────────────────────────

  static DocumentReference<Map<String, dynamic>> _progressDoc() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('activeTournament');
  }

  static Future<void> saveTournamentProgress(AnyTournament t,
      {String? title, String? firestoreId}) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final (type, json) = AppDatabase.tournamentToJson(t);
    await _progressDoc().set({
      'type': type,
      'state': json,
      'title': title,
      if (firestoreId != null) 'firestoreId': firestoreId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> clearTournamentProgress() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await _progressDoc().delete();
    } catch (_) {}
  }

  /// Returns `(tournament, firestoreId)` or null if no progress saved.
  static Future<(AnyTournament, String?)?> loadTournamentProgress() async {
    if (FirebaseAuth.instance.currentUser == null) return null;
    try {
      final doc = await _progressDoc().get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      final type = data['type'] as String?;
      final state = data['state'] as Map<String, dynamic>?;
      if (type == null || state == null) return null;
      final t = AppDatabase.tournamentFromJson(type, state);
      if (t == null) return null;
      return (t, data['firestoreId'] as String?);
    } catch (_) {
      return null;
    }
  }
}
