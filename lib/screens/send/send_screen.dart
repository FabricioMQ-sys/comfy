import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../storage/local_storage.dart';
import '../../services/transaction_service.dart';
import '../../services/remote_wallet_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  bool _loading = false;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  /// Lee el saldo local y, si es posible, lo sincroniza con Firestore.
  Future<void> _loadBalance() async {
    double bal = await LocalStorage.getBalance();

    final phone = await LocalStorage.getPhone();
    if (phone != null && phone.trim().isNotEmpty) {
      try {
        final remote =
            await RemoteWalletService.getRemoteBalance(phone.trim());
        if (remote != null) {
          bal = remote;
          await LocalStorage.saveBalance(bal);
        }
      } catch (_) {
        // Si falla la nube, mantenemos el saldo local.
      }
    }

    if (!mounted) return;
    setState(() => _balance = bal);
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^9\d{8}$').hasMatch(value);
  }

  Future<bool> _confirmWithPin() async {
    final storedPin = await LocalStorage.getPin();
    if (storedPin == null) {
      // Si no hay PIN guardado (flujo raro), no bloqueamos el envío
      return true;
    }

    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirma con tu PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'PIN comfy',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final entered = pinController.text.trim();
              Navigator.pop(context, entered == storedPin);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (result != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN incorrecto o cancelado 😅'),
          ),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _sendMoney() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final phone = _phoneController.text.trim();
    final amount = double.tryParse(
          _amountController.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    if (amount > _balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asu, causa, no tienes tanto saldo 😅')),
      );
      setState(() => _loading = false);
      return;
    }

    // Confirmar con PIN
    final ok = await _confirmWithPin();
    if (!ok) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    // Datos del usuario actual
    final myPhone = await LocalStorage.getPhone();
    final myName = await LocalStorage.getUserName() ?? 'Usuario Comfy';
    final descText = _descController.text.trim();
    final txDescription =
        descText.isEmpty ? 'Enviado a $phone' : descText;

    if (myPhone == null || myPhone.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No encontramos tu número registrado 😥'),
          ),
        );
      }
      setState(() => _loading = false);
      return;
    }

    // Evitar que se envíe a sí mismo
    if (myPhone.trim() == phone) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No puedes enviarte dinero a ti mismo 😅'),
          ),
        );
      }
      setState(() => _loading = false);
      return;
    }

    try {
      // 👉 1) Enviar dinero en Firestore (entre dos comfy)
      await RemoteWalletService.sendMoney(
        fromPhone: myPhone.trim(),
        toPhone: phone,
        amount: amount,
        fromName: myName,
        description: txDescription,
      );

      // 👉 2) Sincronizar saldo remoto con el local (best-effort)
      double newBalance = _balance - amount;
      try {
        final remoteBalance =
            await RemoteWalletService.getRemoteBalance(myPhone.trim());
        if (remoteBalance != null) {
          newBalance = remoteBalance;
        }
      } catch (_) {
        // Si falla, usamos el cálculo local (_balance - amount)
      }

      await LocalStorage.saveBalance(newBalance);
      if (mounted) {
        setState(() {
          _balance = newBalance;
        });
      }

      // 👉 3) Construir la transacción para el historial
      final tx = {
        'amount': amount,
        'type': 'send',
        'to': phone,
        'date': DateTime.now().toIso8601String(),
        'description': txDescription,
      };

      // 👉 4) Guardar en colección global (TransactionService)
      await TransactionService.addTransaction(tx);

      // 👉 5) Guardar en subcolección del usuario (Firestore users/{phone}/transactions)
      await RemoteWalletService.addCurrentUserTransaction(tx);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listo causa, enviaste S/ $amount a $phone 👌'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        // Intento de resync rápido por si fue tema de saldo desactualizado
        try {
          final remoteBalance =
              await RemoteWalletService.getRemoteBalance(myPhone.trim());
          if (remoteBalance != null) {
            await LocalStorage.saveBalance(remoteBalance);
            setState(() {
              _balance = remoteBalance;
            });
          }
        } catch (_) {
          // ignoramos si también falla el resync
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo completar el envío: $e'),
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar dinero')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Card de saldo y contexto
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo disponible',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S/ ${_balance.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Envía dinero a amigos, familia o contactos usando su número de celular.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Formulario
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Número + botón QR
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Número del destinatario',
                            prefixText: '+51 ',
                            hintText: '9xxxxxxxx',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Ingresa el número del destinatario.';
                            }
                            if (!_isValidPhone(text)) {
                              return 'Número inválido. Debe ser 9 + 8 dígitos.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Escanear QR',
                        onPressed: () async {
                          final result =
                              await Navigator.pushNamed(context, '/scan-qr');
                          if (result is String) {
                            var phone = result.trim();
                            phone = phone
                                .replaceAll('+51', '')
                                .replaceAll(' ', '');
                            setState(() {
                              _phoneController.text = phone;
                            });
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Monto
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Monto a enviar',
                      prefixText: 'S/ ',
                      hintText: 'Ej: 10.00',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      final amount = double.tryParse(
                        text.replaceAll(',', '.'),
                      );
                      if (amount == null || amount <= 0) {
                        return 'Ingresa un monto válido.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Descripción opcional
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText:
                          'Ej: delivery, almuerzo, préstamo a amigo, etc.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 1,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _sendMoney,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Confirmar envío'),
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
