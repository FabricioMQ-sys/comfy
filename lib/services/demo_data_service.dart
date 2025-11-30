import 'package:cloud_firestore/cloud_firestore.dart';

class DemoDataService {
  static const String demoPhone = '999111222';
  static const String demoPin = '1234';

  /// Crea / actualiza un usuario demo COMPLETO en Firestore:
  /// - Documento en `users/{demoPhone}`
  /// - Metas en `users/{demoPhone}/goals`
  /// - Movimientos en colección global `transactions`
  static Future<void> createDemoUserInFirestore() async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();

    // 1) USER DOC -----------------------------------------------------------
    final userRef = db.collection('users').doc(demoPhone);

    await userRef.set(
      {
        'phone': demoPhone,
        'name': 'Usuario Demo',
        'lastName': 'Comfy',
        'dni': '12345678',
        'pin': demoPin, // MVP: texto plano, luego se puede encriptar
        'balance': 250.0,
        'isDemo': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 2) GOALS SUBCOLLECTION -----------------------------------------------
    final goalsRef = userRef.collection('goals');

    // Borramos metas previas demo (opcional, para dejar limpio)
    final existingGoals = await goalsRef.get();
    for (final doc in existingGoals.docs) {
      await doc.reference.delete();
    }

    // Creamos algunas metas de ejemplo
    final metaViajeRef = goalsRef.doc();
    await metaViajeRef.set({
      'id': metaViajeRef.id,
      'title': 'Viaje con amigos',
      'emoji': '✈️',
      'targetAmount': 800.0,
      'saved': 150.0,
      'color': 0xFF4CAF50,
      'deadline':
          DateTime(now.year, now.month + 2, 1).toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
      'isDemo': true,
    });

    final metaLaptopRef = goalsRef.doc();
    await metaLaptopRef.set({
      'id': metaLaptopRef.id,
      'title': 'Laptop para estudios',
      'emoji': '💻',
      'targetAmount': 2500.0,
      'saved': 400.0,
      'color': 0xFF1976D2,
      'deadline':
          DateTime(now.year, now.month + 6, 1).toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
      'isDemo': true,
    });

    // 3) TRANSACTIONS GLOBALES ---------------------------------------------
    final txRef = db.collection('transactions');

    // (Opcional) borrar transacciones demo previas de este usuario
    final existingTx = await txRef
        .where('isDemo', isEqualTo: true)
        .where('userPhone', isEqualTo: demoPhone)
        .get();

    for (final doc in existingTx.docs) {
      await doc.reference.delete();
    }

    // Ingreso grande (freelance)
    await txRef.add({
      'userPhone': demoPhone,
      'type': 'receive',
      'amount': 150.0,
      'fromPhone': 'external',
      'toPhone': demoPhone,
      'description': 'Freelance diseño landing',
      'createdAt': now.subtract(const Duration(days: 5)).toIso8601String(),
      'isDemo': true,
    });

    // Gasto delivery (gasto hormiga)
    await txRef.add({
      'userPhone': demoPhone,
      'type': 'send',
      'amount': 35.0,
      'fromPhone': demoPhone,
      'toPhone': '987654321',
      'description': 'Delivery comida',
      'category': 'gasto_hormiga_delivery',
      'isHormiga': true,
      'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      'isDemo': true,
    });

    // Cafecito (gasto hormiga)
    await txRef.add({
      'userPhone': demoPhone,
      'type': 'send',
      'amount': 12.0,
      'fromPhone': demoPhone,
      'toPhone': '999888777',
      'description': 'Cafecito con amig@s',
      'category': 'gasto_hormiga_cafe',
      'isHormiga': true,
      'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      'isDemo': true,
    });

    // Aporte a meta (goal_add)
    await txRef.add({
      'userPhone': demoPhone,
      'type': 'goal_add',
      'amount': 20.0,
      'fromPhone': demoPhone,
      'toPhone': 'meta_viaje', // etiqueta simbólica
      'description': 'Aporte a meta viaje',
      'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      'isDemo': true,
    });

    // Podrías añadir más movimientos si quieres que el coach/historial
    // tengan más variación de categorías.
  }
}
