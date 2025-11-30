import 'package:cloud_firestore/cloud_firestore.dart';
import '../storage/local_storage.dart';

class TransactionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Colección global de transacciones (útil para panel admin / analytics)
  static CollectionReference<Map<String, dynamic>> get _txRef =>
      _db.collection('transactions');

  /// Subcolección de transacciones por usuario:
  /// users/{phone}/transactions
  static CollectionReference<Map<String, dynamic>> _userTxRef(String phone) {
    return _db
        .collection('users')
        .doc(phone)
        .collection('transactions');
  }

  /// Obtiene el teléfono del usuario logueado (desde LocalStorage)
  static Future<String?> _getCurrentPhone() async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return null;
    return phone.trim();
  }

  /// Obtiene todas las transacciones del usuario actual
  /// desde la subcolección: users/{phone}/transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final phone = await _getCurrentPhone();
    if (phone == null) return [];

    final snapshot = await _userTxRef(phone).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        ...data,
        // Aseguramos que siempre haya un id
        'id': data['id'] ?? doc.id,
      };
    }).toList();
  }

  /// Igual que antes, pero ahora los datos vienen de Firestore
  /// (subcolección del usuario) y se ordenan por fecha
  static Future<List<Map<String, dynamic>>> getTransactionsSorted() async {
    final txs = await getTransactions();

    txs.sort((a, b) {
      final da = _parseDate(a);
      final db = _parseDate(b);

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return txs;
  }

  static DateTime? _parseDate(Map<String, dynamic> tx) {
    final raw = tx['date'] ?? tx['createdAt'];

    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Registra la transacción:
  /// 1) En users/{phone}/transactions/{id}
  /// 2) En la colección global transactions/{id}
  static Future<void> addTransaction(Map<String, dynamic> tx) async {
    final phone = await _getCurrentPhone();
    if (phone == null) return;

    final now = DateTime.now();
    final map = Map<String, dynamic>.from(tx);

    // Fecha en String para que tu lógica actual siga funcionando
    map['date'] ??= now.toIso8601String();

    // Asociamos la transacción al usuario actual
    map['userPhone'] = phone;

    // Referencia a la subcolección del usuario
    final userCol = _userTxRef(phone);

    // Creamos un doc nuevo o usamos el id que venga
    String id;
    if (map['id'] != null && map['id'].toString().isNotEmpty) {
      id = map['id'].toString();
    } else {
      final docRef = userCol.doc();
      id = docRef.id;
      map['id'] = id;
    }

    // Timestamp de servidor opcional
    map['createdAt'] ??= FieldValue.serverTimestamp();

    // 1) Guardar en subcolección del usuario
    await userCol.doc(id).set(map);

    // 2) Guardar en colección global (merge para no pisar campos si ya existe)
    await _txRef.doc(id).set(map, SetOptions(merge: true));
  }

  /// Borra TODAS las transacciones de este usuario en Firestore
  /// desde la subcolección users/{phone}/transactions.
  /// (Opcionalmente podrías también limpiar la global si quisieras).
  static Future<void> clearAll() async {
    final phone = await _getCurrentPhone();
    if (phone == null) return;

    // Borramos de la subcolección del usuario
    final snapshot = await _userTxRef(phone).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Opcional: también borrar de la colección global
    // final globalSnap = await _txRef.where('userPhone', isEqualTo: phone).get();
    // for (final doc in globalSnap.docs) {
    //   await doc.reference.delete();
    // }
  }
}
