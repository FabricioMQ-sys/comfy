import 'package:flutter/material.dart';
import '../../storage/local_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _lastName = '';
  String _dni = '';
  String _phone = '';

  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  bool _savingPhone = false;
  bool _savingPin = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await LocalStorage.getUserName() ?? '';
    final lastName = await LocalStorage.getLastName() ?? '';
    final dni = await LocalStorage.getDni() ?? '';
    final phone = await LocalStorage.getPhone() ?? '';

    setState(() {
      _name = name;
      _lastName = lastName;
      _dni = dni;
      _phone = phone;
      _phoneController.text = phone;
    });
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^9\d{8}$').hasMatch(value);
  }

  bool _isValidPin(String value) {
    return RegExp(r'^\d{4}$').hasMatch(value);
  }

  Future<void> _savePhone() async {
    final text = _phoneController.text.trim();
    if (!_isValidPhone(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Número inválido. Debe empezar en 9 y tener 9 dígitos.',
          ),
        ),
      );
      return;
    }

    setState(() => _savingPhone = true);
    await LocalStorage.savePhone(text);
    setState(() {
      _savingPhone = false;
      _phone = text;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Celular actualizado ✅')),
    );
  }

  Future<void> _changePin() async {
    final newPin = _pinController.text.trim();
    final confirmPin = _pinConfirmController.text.trim();

    if (!_isValidPin(newPin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El PIN debe tener 4 dígitos numéricos.'),
        ),
      );
      return;
    }
    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los PIN no coinciden.')),
      );
      return;
    }

    setState(() => _savingPin = true);
    await LocalStorage.savePin(newPin);
    setState(() => _savingPin = false);

    _pinController.clear();
    _pinConfirmController.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN actualizado correctamente.')),
    );
  }

  Future<void> _logout() async {
    // NO borra datos locales, solo vuelve al login
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  String _initials() {
    final n = _name.trim();
    final l = _lastName.trim();
    if (n.isEmpty && l.isEmpty) return '?';
    final n1 = n.isNotEmpty ? n[0] : '';
    final l1 = l.isNotEmpty ? l[0] : '';
    return (n1 + l1).toUpperCase();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = [ _name, _lastName ]
        .where((p) => p.trim().isNotEmpty)
        .join(' ')
        .trim();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // Fondo degradado superior
                  Container(
                    height: 210,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        // AppBar custom
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tu perfil comfy',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Header con avatar y datos cortos
                        Row(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.18),
                                border: Border.all(
                                  color: Colors.white70,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _initials(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName.isEmpty
                                        ? 'Comfy user'
                                        : fullName,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _phone.isNotEmpty
                                        ? '+51 $_phone'
                                        : 'Completa tu número para recibir pagos',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tu PIN protege tus movimientos en Comfy.',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Card grande que se "mete" en el contenido
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user_outlined,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Aquí puedes revisar tus datos y actualizar tu número y PIN en cualquier momento.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // Datos personales
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datos personales',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: const Text('Nombre'),
                              subtitle: Text(
                                _name.isEmpty ? '-' : _name,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const Divider(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.badge_outlined),
                              title: const Text('Apellidos'),
                              subtitle: Text(
                                _lastName.isEmpty ? '-' : _lastName,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const Divider(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.credit_card_outlined),
                              title: const Text('DNI'),
                              subtitle: Text(
                                _dni.isEmpty ? '-' : _dni,
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: const Text(
                                'No editable',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Contacto (celular editable)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contacto',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Usamos tu celular para identificarte y que te puedan enviar dinero con QR.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Celular',
                                prefixText: '+51 ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _savingPhone ? null : _savePhone,
                                icon: _savingPhone
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('Guardar celular'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Seguridad / PIN
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seguridad',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tu PIN se pide para enviar dinero o mover plata de tus metas. No lo compartas con nadie.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              decoration: const InputDecoration(
                                labelText: 'Nuevo PIN (4 dígitos)',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinConfirmController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              decoration: const InputDecoration(
                                labelText: 'Confirmar nuevo PIN',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _savingPin ? null : _changePin,
                                icon: _savingPin
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.lock_reset),
                                label: const Text('Actualizar PIN'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Cerrar sesión
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: Colors.red.withOpacity(0.05),
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'Volverás a la pantalla de inicio de sesión.',
                        style: TextStyle(fontSize: 11),
                      ),
                      onTap: _logout,
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
