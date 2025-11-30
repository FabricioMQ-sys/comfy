import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../storage/local_storage.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _loading = false;

  final _registerFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dniController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  bool _isValidPhone(String value) {
    return RegExp(r'^9\d{8}$').hasMatch(value);
  }

  bool _isValidDni(String value) {
    return RegExp(r'^\d{8}$').hasMatch(value);
  }

  bool _isValidPin(String value) {
    return RegExp(r'^\d{4}$').hasMatch(value);
  }

  bool _isValidName(String value) {
    return RegExp(r"^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$").hasMatch(value);
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final name = _nameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final dni = _dniController.text.trim();
    final pin = _pinController.text.trim();

    // 1) Guardar localmente
    await LocalStorage.saveUserName(name);
    await LocalStorage.saveLastName(lastName);
    await LocalStorage.savePhone(phone);
    await LocalStorage.saveDni(dni);
    await LocalStorage.savePin(pin);

    // Asegurar saldo inicial
    double currentBalance = await LocalStorage.getBalance();
    if (currentBalance.isNaN || currentBalance < 0) {
      currentBalance = 0.0;
      await LocalStorage.saveBalance(currentBalance);
    }

    // 2) Guardar en Firestore (colección "users")
    try {
      final usersRef =
          FirebaseFirestore.instance.collection('users');

      await usersRef.doc(phone).set({
        'phone': phone,
        'name': name,
        'lastName': lastName,
        'dni': dni,
        'pin': pin, // ⚠️ MVP: PIN en texto plano (en prod debería ir hasheado)
        'balance': currentBalance,
        'isAdmin': false, // luego podemos crear un admin cambiando esto a true
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Si falla Firestore, igual dejamos el usuario local creado
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tu cuenta local se creó, pero hubo un error al sincronizar con la nube: $e',
            ),
          ),
        );
      }
    }

    setState(() => _loading = false);

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dniController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Fondo con degradado superior
                Container(
                  height: constraints.maxHeight * 0.35,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),

                        // Botón back
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Icono
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Título y subtítulo
                        Text(
                          'Crear cuenta Comfy',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Completa tus datos para comenzar a usar tu billetera digital.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Card con el formulario
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: _buildRegisterForm(theme),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRegisterForm(ThemeData theme) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
    );
    final focusedOutline = outline.copyWith(
      borderSide: BorderSide(
        color: theme.colorScheme.primary,
        width: 1.6,
      ),
    );

    InputDecoration baseDecoration(String label,
        {String? hint, String? prefix}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: outline,
        enabledBorder: outline,
        focusedBorder: focusedOutline,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
    }

    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Datos personales',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Nombres
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration:
                baseDecoration('Nombres', hint: 'Ej: Andy Fabricio'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Ingresa tus nombres.';
              if (!_isValidName(text)) {
                return 'Solo se permiten letras y espacios.';
              }
              if (text.length < 2) return 'El nombre es demasiado corto.';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Apellidos
          TextFormField(
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            decoration:
                baseDecoration('Apellidos', hint: 'Ej: Pérez García'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Ingresa tus apellidos.';
              if (!_isValidName(text)) {
                return 'Solo se permiten letras y espacios.';
              }
              if (text.length < 2) return 'El apellido es demasiado corto.';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // DNI
          TextFormField(
            controller: _dniController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 8,
            decoration: baseDecoration('DNI', hint: '8 dígitos')
                .copyWith(counterText: ''),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (!_isValidDni(text)) {
                return 'DNI inválido. Deben ser 8 dígitos numéricos.';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),

          // Celular
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: baseDecoration(
              'Celular',
              hint: '9xxxxxxxx',
              prefix: '+51 ',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Ingresa tu número de celular.';
              if (!_isValidPhone(text)) {
                return 'Número inválido. Debe iniciar en 9 y tener 9 dígitos.';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 8),

          Text(
            'Seguridad de acceso',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textInputAction: TextInputAction.next,
                  decoration: baseDecoration('PIN (4 dígitos)')
                      .copyWith(counterText: ''),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (!_isValidPin(text)) {
                      return 'Debe tener 4 dígitos numéricos.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _pinConfirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: baseDecoration('Confirmar PIN')
                      .copyWith(counterText: ''),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text != _pinController.text.trim()) {
                      return 'Los PIN no coinciden.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear cuenta'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
