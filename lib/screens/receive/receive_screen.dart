import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../storage/local_storage.dart';
import '../../services/remote_wallet_service.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  String _name = '';
  String _phone = '';
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await LocalStorage.getUserName();
    final phone = await LocalStorage.getPhone();
    double balance = await LocalStorage.getBalance();

    final cleanPhone = phone?.trim() ?? '';

    // Intentar sincronizar saldo con Firestore (best-effort)
    if (cleanPhone.isNotEmpty) {
      try {
        final remoteBalance =
            await RemoteWalletService.getRemoteBalance(cleanPhone);
        if (remoteBalance != null) {
          balance = remoteBalance;
          await LocalStorage.saveBalance(remoteBalance);
        }
      } catch (_) {
        // Si falla la nube, seguimos mostrando el saldo local.
      }
    }

    if (!mounted) return;

    setState(() {
      _name =
          (name == null || name.trim().isEmpty) ? 'Usuario Comfy' : name;
      _phone = phone ?? '9xxxxxxxx';
      _balance = balance;
    });
  }

  Future<void> _copyPhoneToClipboard() async {
    await Clipboard.setData(ClipboardData(text: '+51 $_phone'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Número copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrData = '+51$_phone';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recibir dinero'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header usuario + saldo
              Text(
                'Comparte tu QR o tu número para que te depositen directo a tu Comfy.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      _name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+51 $_phone',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _copyPhoneToClipboard,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar número'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Saldo actual: S/ ${_balance.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 24),

              // Card QR
              Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 220,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Escanea este código para usar tu número en otra app o enviar desde otra Comfy.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Cuando alguien te envíe dinero desde otra Comfy Wallet, '
                'verás el movimiento en tu historial y tu saldo se actualizará automáticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
