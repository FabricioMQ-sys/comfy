import 'package:cloud_firestore/cloud_firestore.dart';

import '../storage/local_storage.dart';
import 'transaction_service.dart';
import 'goal_service.dart';

class DemoDataService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Crea una cuenta demo en Firestore y deja todo listo en LocalStorage
  /// Teléfono: +51 999 111 222
  /// PIN: 1234
  static Future<void> createDemoUserAndData() async {
    const demoPhone = '999111222';
    const demoPin = '1234';

    // 1) Definir datos base de la cuenta demo
    const name = 'Cuenta Demo';
    const lastName = 'Comfy';
    const dni = '00000000';
    const initialBalance = 150.0;

    final userRef = _db.collection('users').doc(demoPhone);

    // 2) Crear / actualizar documento de usuario en Firestore
    await userRef.set(
      {
        'phone': demoPhone,
        'name': name,
        'lastName': lastName,
        'dni': dni,
        'pin': demoPin,
        'balance': initialBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 3) Limpiar metas anteriores de la cuenta demo (si existían)
    final goalsRef = userRef.collection('goals');
    final oldGoalsSnap = await goalsRef.get();
    for (final doc in oldGoalsSnap.docs) {
      await doc.reference.delete();
    }

    // 4) Crear algunas metas demo
    final now = DateTime.now();
    final goal1Id = goalsRef.doc().id;
    final goal2Id = goalsRef.doc().id;

    await goalsRef.doc(goal1Id).set({
      'id': goal1Id,
      'name': 'Fondo de emergencia',
      'target': 300.0,
      'saved': 80.0,
      'createdAt': now.toIso8601String(),
      'deadline': null,
      'lockLevel': 2,
    });

    await goalsRef.doc(goal2Id).set({
      'id': goal2Id,
      'name': 'Salir a comer con amigos',
      'target': 120.0,
      'saved': 40.0,
      'createdAt': now.toIso8601String(),
      'deadline':
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      'lockLevel': 1,
    });

    // 5) Borrar transacciones anteriores de este usuario en la colección global
    final txSnap = await _db
        .collection('transactions')
        .where('userPhone', isEqualTo: demoPhone)
        .get();
    for (final doc in txSnap.docs) {
      await doc.reference.delete();
    }

    // 6) Crear algunas transacciones demo
    final txCollection = _db.collection('transactions');

    Future<void> _addTx(Map<String, dynamic> base) async {
      final docRef = txCollection.doc();
      await docRef.set({
        ...base,
        'id': docRef.id,
        'userPhone': demoPhone,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _addTx({
      'amount': 100.0,
      'type': 'receive',
      'description': 'Depósito inicial demo',
      'date': now.subtract(const Duration(days: 5)).toIso8601String(),
    });

    await _addTx({
      'amount': 20.0,
      'type': 'send',
      'to': '988776655',
      'description': 'Yape a amigo',
      'date': now.subtract(const Duration(days: 3)).toIso8601String(),
      'category': 'gasto_general',
    });

    await _addTx({
      'amount': 15.5,
      'type': 'goal_add',
      'goalId': goal1Id,
      'goalName': 'Fondo de emergencia',
      'description': 'Aporte automático a meta',
      'date': now.subtract(const Duration(days: 2)).toIso8601String(),
      'category': 'meta_aporte',
    });

    await _addTx({
      'amount': 12.0,
      'type': 'send',
      'to': '977665544',
      'description': 'Café y snacks',
      'date': now.subtract(const Duration(days: 1)).toIso8601String(),
      'category': 'gasto_hormiga_cafe',
      'isHormiga': true,
    });

    // 7) Dejar LocalStorage listo para entrar directo al /home con la demo
    await LocalStorage.saveUserName(name);
    await LocalStorage.saveLastName(lastName);
    await LocalStorage.savePhone(demoPhone);
    await LocalStorage.saveDni(dni);
    await LocalStorage.savePin(demoPin);
    await LocalStorage.saveBalance(initialBalance);

    // Opcional: si GoalService / TransactionService tienen caches locales,
    // se pueden recalcular luego en las pantallas con sus métodos normales.
  }
}
