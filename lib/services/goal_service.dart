import 'package:cloud_firestore/cloud_firestore.dart';
import '../storage/local_storage.dart';

class GoalService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String?> _getCurrentPhone() async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return null;
    return phone.trim();
  }

  static CollectionReference<Map<String, dynamic>> _goalsRef(String phone) {
    return _db.collection('users').doc(phone).collection('goals');
  }

  /// Trae las metas del usuario actual desde Firestore
  static Future<List<Map<String, dynamic>>> getGoals() async {
    final phone = await _getCurrentPhone();
    if (phone == null) return [];

    final snapshot = await _goalsRef(phone)
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        ...data,
        'id': data['id'] ?? doc.id,
      };
    }).toList();
  }

  /// Crea una meta nueva en Firestore
  static Future<void> addGoal(Map<String, dynamic> goal) async {
    final phone = await _getCurrentPhone();
    if (phone == null) return;

    final goals = _goalsRef(phone);

    // Si no viene id, generamos uno
    final String id = (goal['id']?.toString().isNotEmpty ?? false)
        ? goal['id'].toString()
        : goals.doc().id;

    final data = {
      ...goal,
      'id': id,
      'createdAt': goal['createdAt'] ?? FieldValue.serverTimestamp(),
    };

    await goals.doc(id).set(data, SetOptions(merge: true));
  }

  /// Actualiza una meta existente
  static Future<void> updateGoal(Map<String, dynamic> updatedGoal) async {
    final phone = await _getCurrentPhone();
    if (phone == null) return;

    final id = updatedGoal['id']?.toString();
    if (id == null || id.isEmpty) return;

    final goals = _goalsRef(phone);
    await goals.doc(id).set(updatedGoal, SetOptions(merge: true));
  }

  /// Elimina una meta
  static Future<void> deleteGoal(String id) async {
    final phone = await _getCurrentPhone();
    if (phone == null) return;

    final goals = _goalsRef(phone);
    await goals.doc(id).delete();
  }

  /// Suma monto a la meta (campo `saved`) usando transacción de Firestore
  static Future<void> addToGoal(String id, double amount) async {
    final phone = await _getCurrentPhone();
    if (phone == null) return;
    if (amount <= 0) return;

    final docRef = _goalsRef(phone).doc(id);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final currentSaved =
          (data['saved'] as num?)?.toDouble() ?? 0.0;

      txn.update(docRef, {
        'saved': currentSaved + amount,
      });
    });
  }
}
