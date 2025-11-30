import 'package:cloud_firestore/cloud_firestore.dart';
import '../storage/local_storage.dart';

class RemoteWalletService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Colecciones principales
  static CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  static CollectionReference<Map<String, dynamic>> get _txRef =>
      _db.collection('transactions');

  // Subcolecciones por usuario (para sincronización 1 a 1 con tu billetera local)
  static DocumentReference<Map<String, dynamic>> _userDoc(String phone) =>
      _usersRef.doc(phone);

  static CollectionReference<Map<String, dynamic>> _userTxCol(String phone) =>
      _userDoc(phone).collection('transactions');

  static CollectionReference<Map<String, dynamic>> _userGoalsCol(String phone) =>
      _userDoc(phone).collection('goals');

  /// Crea el usuario en Firestore si no existe.
  /// Usaremos el número de celular como ID del documento.
  static Future<void> ensureUser({
    required String phone,
    required String name,
  }) async {
    final docRef = _usersRef.doc(phone);
    final snap = await docRef.get();

    if (!snap.exists) {
      await docRef.set({
        'phone': phone,
        'name': name,
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Versión comodín que usa los datos guardados en LocalStorage
  /// (ideal para sincronizar al inicio o después de un cambio de perfil).
  static Future<void> ensureCurrentUser() async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return;

    final rawName = await LocalStorage.getUserName();
    final rawLastName = await LocalStorage.getLastName();
    final fullName = () {
      final name = (rawName ?? '').trim();
      final lastName = (rawLastName ?? '').trim();
      if (name.isEmpty && lastName.isEmpty) return 'Usuario Comfy';
      if (lastName.isEmpty) return name;
      return '$name $lastName';
    }();

    await ensureUser(phone: phone.trim(), name: fullName);
  }

  /// Devuelve el saldo remoto (o null si no existe usuario)
  static Future<double?> getRemoteBalance(String phone) async {
    final snap = await _usersRef.doc(phone).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return (data['balance'] as num?)?.toDouble();
  }

  /// Obtiene el doc de un usuario por teléfono.
  static Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    if (phone.trim().isEmpty) return null;
    final snap = await _usersRef.doc(phone.trim()).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return {
      ...data,
      'id': snap.id,
    };
  }

  /// Obtiene el usuario actual (según el phone guardado en LocalStorage).
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return null;
    return getUserByPhone(phone.trim());
  }

  /// Actualiza el saldo remoto del usuario actual (según LocalStorage).
  /// Llamaremos a esto después de `LocalStorage.saveBalance(...)`.
  static Future<void> updateCurrentUserBalance(double newBalance) async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.trim();

    // Aseguramos que el doc exista
    await ensureCurrentUser();

    await _userDoc(cleanPhone).set(
      {
        'balance': newBalance,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Sincroniza datos del usuario REMOTO -> LOCAL.
  /// Útil justo después del login/registro o al abrir la app.
  static Future<void> syncCurrentUserDownToLocal() async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return;

    final user = await getUserByPhone(phone.trim());
    if (user == null) return;

    final balance = (user['balance'] as num?)?.toDouble() ?? 0.0;
    final name = (user['name'] as String?) ?? '';
    final lastName = (user['lastName'] as String?) ?? '';
    final dni = (user['dni'] as String?) ?? '';

    if (name.trim().isNotEmpty) {
      await LocalStorage.saveUserName(name.trim());
    }
    if (lastName.trim().isNotEmpty) {
      await LocalStorage.saveLastName(lastName.trim());
    }
    if (dni.trim().isNotEmpty) {
      await LocalStorage.saveDni(dni.trim());
    }

    await LocalStorage.saveBalance(balance);
  }

  /// Sincroniza datos del usuario LOCAL -> REMOTO.
  /// Útil cuando el usuario actualiza su perfil o cuando migras datos legacy.
  static Future<void> syncCurrentUserUpFromLocal() async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.trim();

    final name = await LocalStorage.getUserName();
    final lastName = await LocalStorage.getLastName();
    final dni = await LocalStorage.getDni();
    final balance = await LocalStorage.getBalance();

    await _userDoc(cleanPhone).set(
      {
        'phone': cleanPhone,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'lastName': lastName.trim(),
        if (dni != null && dni.trim().isNotEmpty) 'dni': dni.trim(),
        'balance': balance,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Registra una transacción del usuario actual en la subcolección
  /// `users/{phone}/transactions/{txId}`.
  ///
  /// OJO: la colección global `transactions` la maneja TransactionService.
  static Future<void> addCurrentUserTransaction(
    Map<String, dynamic> tx,
  ) async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.trim();

    await ensureCurrentUser();

    // Aseguramos un ID estable
    String txId;
    if (tx['id'] != null) {
      txId = tx['id'].toString();
    } else {
      txId = DateTime.now().microsecondsSinceEpoch.toString();
      tx['id'] = txId;
    }

    final dataToSave = {
      ...tx,
      'ownerPhone': cleanPhone,
      'syncedAt': FieldValue.serverTimestamp(),
    };

    // Solo guardamos en la subcolección del usuario.
    await _userTxCol(cleanPhone).doc(txId).set(dataToSave);
  }


  /// Crea o actualiza una meta del usuario actual en Firestore.
  /// Se guarda en `users/{phone}/goals/{goalId}`.
  static Future<void> upsertCurrentUserGoal(
    Map<String, dynamic> goal,
  ) async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.trim();

    await ensureCurrentUser();

    String goalId;
    if (goal['id'] != null) {
      goalId = goal['id'].toString();
    } else {
      goalId = DateTime.now().microsecondsSinceEpoch.toString();
      goal['id'] = goalId;
    }

    await _userGoalsCol(cleanPhone).doc(goalId).set({
      ...goal,
      'ownerPhone': cleanPhone,
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina una meta del usuario actual en Firestore.
  static Future<void> deleteCurrentUserGoal(String goalId) async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return;
    final cleanPhone = phone.trim();

    await _userGoalsCol(cleanPhone).doc(goalId).delete();
  }

  /// Envía dinero entre dos celulares (comfy a comfy).
  /// - Descuenta al emisor
  /// - Suma al receptor (si no existe usuario, se crea con ese saldo)
  /// - Registra una transacción en la colección global "transactions"
  ///
  /// Esto es tu flujo "comfy a comfy" en la nube (entre dos wallets).
  static Future<void> sendMoney({
    required String fromPhone,
    required String toPhone,
    required double amount,
    required String fromName,
    String? description,
  }) async {
    final now = DateTime.now();

    await _db.runTransaction((txn) async {
      final fromRef = _usersRef.doc(fromPhone);
      final toRef = _usersRef.doc(toPhone);

      // Emisor
      final fromSnap = await txn.get(fromRef);
      if (!fromSnap.exists) {
        throw Exception('Tu usuario no existe en la nube.');
      }
      final fromData = fromSnap.data()!;
      double fromBalance =
          (fromData['balance'] as num?)?.toDouble() ?? 0.0;

      if (fromBalance < amount) {
        throw Exception('Saldo insuficiente en la nube.');
      }

      // Receptor
      final toSnap = await txn.get(toRef);
      double toBalance =
          (toSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;

      // Actualizar saldos
      txn.update(fromRef, {'balance': fromBalance - amount});

      if (toSnap.exists) {
        txn.update(toRef, {'balance': toBalance + amount});
      } else {
        txn.set(toRef, {
          'phone': toPhone,
          'name': 'Usuario Comfy',
          'balance': amount,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Registrar transacción global
      final txDoc = _txRef.doc();
      txn.set(txDoc, {
        'id': txDoc.id,
        'fromPhone': fromPhone,
        'toPhone': toPhone,
        'amount': amount,
        'description': description ?? '',
        'createdAt': now.toIso8601String(),
        'fromName': fromName,
      });
    });
  }
}
