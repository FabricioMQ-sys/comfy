import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../storage/local_storage.dart';
import '../../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _hasAccount = false;
  bool _loading = false;

  String? _storedName;
  String? _storedLastName;
  String? _storedPhone;

  final _pinFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _loginPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _useDemoAccount() async {
    setState(() => _loading = true);

    const demoPhone = '999111222';
    const demoPin = '1234';
    const name = 'Cuenta Demo';
    const lastName = 'Comfy';
    const dni = '00000000';
    const initialBalance = 150.0;

    try {
      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(demoPhone);

      // 1) Crear / actualizar usuario demo en Firestore
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

      // 2) Limpiar metas anteriores del demo (si existían)
      final goalsRef = userRef.collection('goals');
      final oldGoalsSnap = await goalsRef.get();
      for (final doc in oldGoalsSnap.docs) {
        await doc.reference.delete();
      }

      // 3) Crear metas demo
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

      // 4) Limpiar transacciones anteriores del demo
      final txCollection = db.collection('transactions');
      final oldTxSnap =
          await txCollection.where('userPhone', isEqualTo: demoPhone).get();
      for (final doc in oldTxSnap.docs) {
        await doc.reference.delete();
      }

      Future<void> _addTx(Map<String, dynamic> base) async {
        final docRef = txCollection.doc();
        await docRef.set({
          ...base,
          'id': docRef.id,
          'userPhone': demoPhone,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 5) Crear algunas transacciones demo
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

      // 6) Dejar LocalStorage listo para entrar directo al home
      await LocalStorage.saveUserName(name);
      await LocalStorage.saveLastName(lastName);
      await LocalStorage.savePhone(demoPhone);
      await LocalStorage.saveDni(dni);
      await LocalStorage.savePin(demoPin);
      await LocalStorage.saveBalance(initialBalance);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta demo lista: +51 999111222 / PIN 1234'),
        ),
      );

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear la cuenta demo: $e'),
        ),
      );
    }
  }


  Future<void> _loadUserData() async {
    final name = await LocalStorage.getUserName();
    final lastName = await LocalStorage.getLastName();
    final phone = await LocalStorage.getPhone();
    final pin = await LocalStorage.getPin();

    setState(() {
      _storedName = name;
      _storedLastName = lastName;
      _storedPhone = phone;
      _hasAccount = pin != null;
      if (phone != null && phone.trim().isNotEmpty) {
        _phoneController.text = phone.trim();
      }
    });
  }

  bool _isValidPin(String value) {
    return RegExp(r'^\d{4}$').hasMatch(value);
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^9\d{8}$').hasMatch(value);
  }

  String _maskPhone(String phone) {
    // Ej: 993639006 -> 993****06
    if (phone.length <= 4) return '****';
    final start = phone.substring(0, 3);
    final end = phone.substring(phone.length - 2);
    return '$start****$end';
  }

  Future<void> _loginWithPin() async {
    if (!_pinFormKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final enteredPin = _loginPinController.text.trim();

    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un número de celular válido (9 + 8 dígitos).'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(phone);
      final doc = await docRef.get();

      if (!doc.exists) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No encontramos una cuenta Comfy con ese número.'),
          ),
        );
        return;
      }

      final data = doc.data() ?? {};

      // 🔐 PIN remoto (puede ser null si el user se creó con ensureUser)
      String? remotePin = data['pin'] as String?;

      if (remotePin != null) {
        // Caso normal: validamos directo contra Firestore
        if (remotePin != enteredPin) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN incorrecto. Inténtalo nuevamente.'),
            ),
          );
          return;
        }
      } else {
        // Caso legado: el doc existe pero no tiene PIN almacenado
        // Intentamos usar el PIN guardado en local (si hubiera)
        final localPin = await LocalStorage.getPin();

        if (localPin == null || localPin != enteredPin) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'PIN incorrecto. Si nunca configuraste PIN en este dispositivo, regístrate de nuevo.'),
            ),
          );
          return;
        }

        // Si coincide con el PIN local, aprovechamos para subirlo a Firestore
        await docRef.set(
          {'pin': localPin},
          SetOptions(merge: true),
        );
        remotePin = localPin;
      }

      // ✅ Login OK: combinamos datos remotos con locales para hidratar LocalStorage
      final remoteName = (data['name'] as String?) ?? '';
      final remoteLastName = (data['lastName'] as String?) ?? '';
      final remoteDni = (data['dni'] as String?) ?? '';
      final remoteBalance = (data['balance'] as num?)?.toDouble();

      final localName = await LocalStorage.getUserName();
      final localLastName = await LocalStorage.getLastName();
      final localDni = await LocalStorage.getDni();
      final localBalance = await LocalStorage.getBalance();

      final finalName =
          remoteName.isNotEmpty ? remoteName : (localName ?? '');
      final finalLastName =
          remoteLastName.isNotEmpty ? remoteLastName : (localLastName ?? '');
      final finalDni = remoteDni.isNotEmpty ? remoteDni : (localDni ?? '');
      final finalBalance = remoteBalance ?? localBalance;

      await LocalStorage.saveUserName(finalName);
      await LocalStorage.saveLastName(finalLastName);
      await LocalStorage.savePhone(phone);
      if (finalDni.isNotEmpty) {
        await LocalStorage.saveDni(finalDni);
      }
      await LocalStorage.savePin(enteredPin);
      await LocalStorage.saveBalance(finalBalance);

      if (!mounted) return;
      setState(() => _loading = false);

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocurrió un error al iniciar sesión: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _loginPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Fondo con gradiente
            Container(
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [comfyPrimary, Color(0xFF8B9BFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Contenido
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                children: [
                  // Header (logo + título)
                  Column(
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/logo_comfy.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Comfy Wallet',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Inicia sesión con tu celular y PIN',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Card de login
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _pinFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acceso con PIN',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),

                            if (_storedName != null) ...[
                              Text(
                                '${_storedName!}${_storedLastName != null ? ' ${_storedLastName!}' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (_storedPhone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Último celular usado: +51 ${_maskPhone(_storedPhone!)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                            ],

                            // 📱 Celular
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Celular',
                                prefixText: '+51 ',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Ingresa tu número de celular.';
                                }
                                if (!_isValidPhone(text)) {
                                  return 'Número inválido (9 + 8 dígitos).';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // 🔒 PIN
                            TextFormField(
                              controller: _loginPinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              decoration: const InputDecoration(
                                labelText: 'PIN',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (!_isValidPin(text)) {
                                  return 'PIN inválido (4 dígitos numéricos).';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _loading ? null : _loginWithPin,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Entrar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text(
                      '¿Aún no tienes cuenta? Regístrate',
                      style: TextStyle(color: Color(0xFF2E7D32)),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _useDemoAccount,
                    child: const Text(
                      'Probar con cuenta demo',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
