import 'dart:async';
import 'package:flutter/material.dart';

import '../../storage/local_storage.dart';
import '../../services/goal_service.dart';
import '../../services/transaction_service.dart';
import '../../services/gamification_service.dart';
import '../../services/remote_wallet_service.dart';
import '../../widgets/comfy_bottom_nav.dart';
import 'goal_history_screen.dart';
import '../../widgets/coach_chat_bubble.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Map<String, dynamic>> _goals = [];
  bool _loading = true;

  bool _showCreateForm = false;
  Map<String, dynamic>? _goalForAdd;
  Map<String, dynamic>? _goalForEdit;

  final _createFormKey = GlobalKey<FormState>();
  final _addFormKey = GlobalKey<FormState>();
  final _editFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _deadlineController = TextEditingController();

  final _addAmountController = TextEditingController();

  final _editNameController = TextEditingController();
  final _editTargetController = TextEditingController();
  final _editDeadlineController = TextEditingController();

  // Gamificación
  double _totalSavedToGoals = 0;
  int _level = 1;
  int _points = 0;
  double _remainingToNext = 0;
  double _nextLevelAt = 100;

  // Candado de metas
  int _createLockLevel = 0; // 0 = flexible, 1 = medio, 2 = fuerte
  int _editLockLevel = 0;

  // Saldo actual para calcular % en metas
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadGamification();
  }

  Future<void> _loadGoals() async {
    final goals = await GoalService.getGoals();

    // 1) Leemos saldo local
    double balance = await LocalStorage.getBalance();

    // 2) Intentamos sincronizar con saldo remoto en Firestore (best-effort)
    final phone = await LocalStorage.getPhone();
    if (phone != null && phone.trim().isNotEmpty) {
      try {
        final remote =
            await RemoteWalletService.getRemoteBalance(phone.trim());
        if (remote != null) {
          balance = remote;
          // Cache local actualizada
          await LocalStorage.saveBalance(balance);
        }
      } catch (_) {
        // Si falla Firestore (offline, permisos, etc.), seguimos con el saldo local.
      }
    }

    if (!mounted) return;
    setState(() {
      _goals = goals;
      _currentBalance = balance;
      _loading = false;
    });
  }


  Future<void> _loadGamification() async {
    final stats = await GamificationService.getSavingStats();
    setState(() {
      _totalSavedToGoals =
          (stats['totalSavedToGoals'] as num?)?.toDouble() ?? 0.0;
      _level = stats['level'] as int? ?? 1;
      _points = stats['points'] as int? ?? 0;
      _remainingToNext =
          (stats['remainingToNext'] as num?)?.toDouble() ?? 0.0;
      _nextLevelAt = (stats['nextLevelAt'] as num?)?.toDouble() ?? 100.0;
    });
  }

  Future<void> _pickDeadline(
    TextEditingController controller,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      controller.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  DateTime? _parseDeadline(String? deadline) {
    if (deadline == null || deadline.isEmpty) return null;
    try {
      final parts = deadline.split('/');
      if (parts.length != 3) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createGoal() async {
    if (!_createFormKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final target =
        double.tryParse(_targetController.text.trim().replaceAll(',', '.')) ??
            0;
    final deadlineText = _deadlineController.text.trim();

    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();

    final goal = {
      'id': id,
      'name': name,
      'target': target,
      'saved': 0.0,
      'createdAt': now.toIso8601String(),
      'deadline': deadlineText.isEmpty ? null : deadlineText,
      'lockLevel': _createLockLevel,
    };

    await GoalService.addGoal(goal);

    _nameController.clear();
    _targetController.clear();
    _deadlineController.clear();
    _createLockLevel = 0;

    setState(() {
      _showCreateForm = false;
    });

    await _loadGoals();
    await _loadGamification();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meta creada en tu bóveda 💪')),
    );
  }

  Future<bool> _askPin() async {
    final pinStored = await LocalStorage.getPin();
    if (pinStored == null) return true; // sin PIN configurado

    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirma con tu PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'PIN',
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
              if (controller.text.trim() == pinStored) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN incorrecto')),
                );
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    return ok ?? false;
  }

  Future<void> _addMoneyToGoal() async {
    if (_goalForAdd == null) return;
    if (!_addFormKey.currentState!.validate()) return;

    final ok = await _askPin();
    if (!ok) return;

    final amount = double.tryParse(
            _addAmountController.text.trim().replaceAll(',', '.')) ??
        0.0;
    if (amount <= 0) return;

    final balance = await LocalStorage.getBalance();
    if (amount > balance) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes saldo suficiente 😅')),
      );
      return;
    }

    // 1) Descontar de saldo (local + remoto)
    final newBalance = balance - amount;
    await LocalStorage.saveBalance(newBalance);
    await RemoteWalletService.updateCurrentUserBalance(newBalance);

    final goalId = _goalForAdd!['id'];
    final goalName = _goalForAdd!['name'];

    // 2) Sumar a meta (en Firestore)
    await GoalService.addToGoal(goalId, amount);

    // 3) Registrar transacción para gamificación (local + Firestore)
    final tx = {
      'amount': amount,
      'type': 'goal_add',
      'date': DateTime.now().toIso8601String(),
      'goalId': goalId,
      'goalName': goalName,
    };

    await TransactionService.addTransaction(tx);
    await RemoteWalletService.addCurrentUserTransaction(tx);

    _addAmountController.clear();
    setState(() {
      _goalForAdd = null;
    });

    await _loadGoals();
    await _loadGamification();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Guardaste S/ $amount en "$goalName" 💚',
        ),
      ),
    );
  }

  Future<void> _showWithdrawDialog(Map<String, dynamic> goal) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    String reason = 'Emergencia';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final saved = (goal['saved'] as num?)?.toDouble() ?? 0.0;

          return AlertDialog(
            title: Text('Retirar de "${goal['name']}"'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tienes S/ ${saved.toStringAsFixed(2)} en esta meta.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto a retirar (S/)',
                      hintText: 'Ej: 50.00',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      final amount =
                          double.tryParse(text.replaceAll(',', '.'));
                      if (amount == null || amount <= 0) {
                        return 'Monto inválido';
                      }
                      if (amount > saved) {
                        return 'No puedes retirar más de lo ahorrado';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: const InputDecoration(
                      labelText: '¿Por qué retiras?',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Emergencia',
                        child: Text('Emergencia'),
                      ),
                      DropdownMenuItem(
                        value: 'Disfrutar',
                        child: Text('Disfrutar / gusto personal'),
                      ),
                      DropdownMenuItem(
                        value: 'Pagar deuda',
                        child: Text('Pagar deuda'),
                      ),
                      DropdownMenuItem(
                        value: 'Otro',
                        child: Text('Otro'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          reason = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final amount = double.parse(
                      amountController.text.trim().replaceAll(',', '.'));

                  Navigator.pop(context); // cerramos el primer diálogo

                  await _confirmWithdraw(goal, amount, reason);
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmWithdraw(
    Map<String, dynamic> goal,
    double amount,
    String reason,
  ) async {
    // Nivel de candado (0: libre, 1: leve, 2+: fuerte)
    final int lockLevel = (goal['lockLevel'] as int?) ?? 0;

    final bool proceed = await _showCountdownDialog(
      goalName: goal['name'] as String? ?? '',
      amount: amount,
      reason: reason,
      lockLevel: lockLevel,
    );

    if (!proceed) return;

    final okPin = await _askPin();
    if (!okPin) return;

    final saved = (goal['saved'] as num?)?.toDouble() ?? 0.0;
    if (amount > saved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya no tienes tanto en la meta 😅')),
      );
      return;
    }

    // 1) Sumar al saldo principal (local + remoto)
    final currentBalance = await LocalStorage.getBalance();
    final newBalance = currentBalance + amount;
    await LocalStorage.saveBalance(newBalance);
    await RemoteWalletService.updateCurrentUserBalance(newBalance);

    // 2) Restar de la meta en Firestore
    await GoalService.addToGoal(goal['id'], -amount);

    // 3) Registrar transacción (local + Firestore)
    final tx = {
      'amount': amount,
      'type': 'goal_withdraw',
      'date': DateTime.now().toIso8601String(),
      'goalId': goal['id'],
      'goalName': goal['name'],
      'reason': reason,
    };

    await TransactionService.addTransaction(tx);
    await RemoteWalletService.addCurrentUserTransaction(tx);

    await _loadGoals();
    await _loadGamification();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Retiraste S/ ${amount.toStringAsFixed(2)} de "${goal['name']}"',
        ),
      ),
    );
  }

  Future<bool> _showCountdownDialog({
    required String goalName,
    required double amount,
    required String reason,
    required int lockLevel,
  }) async {
    int seconds = 30;
    Timer? timer;

    String extraMsg;
    if (reason == 'Disfrutar') {
      extraMsg =
          'Disfrutar también es válido 😌\n\nSolo confirma si este retiro está alineado con tu meta "$goalName".';
    } else if (reason == 'Emergencia') {
      extraMsg =
          'Si es una emergencia, está bien usar tu ahorro.\nCuando puedas, intenta reponerlo💚';
    } else {
      extraMsg = 'Tómate unos segundos para pensar si este retiro es necesario 😉';
    }

    if (lockLevel >= 2) {
      extraMsg +=
          '\n\nCandado fuerte activado 🔒: marcaste esta meta como importante.';
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (timer == null) {
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (!dialogContext.mounted) {
                  t.cancel();
                  return;
                }
                if (seconds <= 1) {
                  t.cancel();
                  Navigator.of(dialogContext).pop(true); // auto-confirmar
                } else {
                  seconds--;
                  setStateDialog(() {});
                }
              });
            }

            return AlertDialog(
              title: const Text('¿Seguro que quieres retirar?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vas a retirar S/ ${amount.toStringAsFixed(2)} de "$goalName".',
                  ),
                  const SizedBox(height: 8),
                  Text(extraMsg),
                  const SizedBox(height: 12),
                  Text(
                    'Tómate un respiro... ⏳\nTe quedan $seconds segundos para pensarlo.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Retirar'),
                ),
              ],
            );
          },
        );
      },
    );

    timer?.cancel();
    return result ?? false;
  }

  Future<void> _editGoal(Map<String, dynamic> goal) async {
    _goalForEdit = goal;
    _editNameController.text = goal['name'] as String? ?? '';
    _editTargetController.text =
        (goal['target'] as num?)?.toStringAsFixed(2) ?? '';
    _editDeadlineController.text = (goal['deadline'] as String?) ?? '';
    _editLockLevel = (goal['lockLevel'] as int?) ?? 0;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar meta'),
        content: Form(
          key: _editFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _editNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Ingresa un nombre';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _editTargetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto objetivo (S/)',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final target =
                        double.tryParse(text.replaceAll(',', '.'));
                    if (target == null || target <= 0) {
                      return 'Monto inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _editDeadlineController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Plazo (opcional)',
                    hintText: 'Toca para elegir fecha',
                  ),
                  onTap: () => _pickDeadline(_editDeadlineController),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _editLockLevel,
                  decoration: const InputDecoration(
                    labelText: 'Nivel de candado',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Flexible'),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Medio'),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Fuerte'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _editLockLevel = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _goalForEdit = null;
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (!_editFormKey.currentState!.validate()) return;

              final updated = Map<String, dynamic>.from(_goalForEdit!);

              final newName = _editNameController.text.trim();
              final newTarget = double.tryParse(
                      _editTargetController.text
                          .trim()
                          .replaceAll(',', '.')) ??
                  0.0;
              final newDeadline = _editDeadlineController.text.trim();

              final currentSaved =
                  (updated['saved'] as num?)?.toDouble() ?? 0.0;
              final fixedTarget =
                  newTarget < currentSaved ? currentSaved : newTarget;

              updated['name'] = newName;
              updated['target'] = fixedTarget;
              updated['deadline'] =
                  newDeadline.isEmpty ? null : newDeadline;
              updated['lockLevel'] = _editLockLevel;

              await GoalService.updateGoal(updated);
              await _loadGoals();
              await _loadGamification();

              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meta actualizada ✅')),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal) async {
    final String name = goal['name'] as String? ?? '';
    final double saved = (goal['saved'] as num?)?.toDouble() ?? 0.0;
    final String id = goal['id'] as String;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: Text(
          saved > 0
              ? 'Esta meta tiene S/ ${saved.toStringAsFixed(2)} ahorrados.\n\n'
                  'Si la eliminas, ese monto volverá a tu saldo principal.\n\n'
                  '¿Seguro que quieres borrar "$name"?'
              : '¿Seguro que quieres borrar "$name"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      // 1) Si hay dinero ahorrado, devolverlo al saldo (local + remoto)
      if (saved > 0) {
        final currentBalance = await LocalStorage.getBalance();
        final newBalance = currentBalance + saved;
        await LocalStorage.saveBalance(newBalance);
        await RemoteWalletService.updateCurrentUserBalance(newBalance);

        // 2) Registrar transacción tipo "goal_refund" (local + Firestore)
        final tx = {
          'amount': saved,
          'type': 'goal_refund',
          'date': DateTime.now().toIso8601String(),
          'goalId': id,
          'goalName': name,
          'description': 'Se eliminó la meta y se devolvió el ahorro',
        };

        await TransactionService.addTransaction(tx);
        await RemoteWalletService.addCurrentUserTransaction(tx);
      }

      // 3) Eliminar la meta (Firestore)
      await GoalService.deleteGoal(id);
      await _loadGoals();
      await _loadGamification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meta eliminada y saldo actualizado')),
      );
    }
  }

  String _lockLevelLabelShort(int level) {
    switch (level) {
      case 0:
        return 'Flexible';
      case 1:
        return 'Medio';
      case 2:
      default:
        return 'Fuerte';
    }
  }

  Color _lockLevelColor(int level) {
    switch (level) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.amber;
      case 2:
      default:
        return Colors.redAccent;
    }
  }

  String _goalStatusLabel(double progress, DateTime? deadline) {
    if (progress >= 1.0) return 'Completada';
    if (deadline == null) return 'Sin plazo';

    final now = DateTime.now();
    if (now.isAfter(deadline)) return 'Fuera de plazo';
    return 'En curso';
  }

  Color _goalStatusColor(double progress, DateTime? deadline) {
    final label = _goalStatusLabel(progress, deadline);
    switch (label) {
      case 'Completada':
        return Colors.green;
      case 'Fuera de plazo':
        return Colors.redAccent;
      case 'En curso':
        return Colors.blue;
      case 'Sin plazo':
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _deadlineController.dispose();
    _addAmountController.dispose();
    _editNameController.dispose();
    _editTargetController.dispose();
    _editDeadlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bóveda de metas'),
      ),
      bottomNavigationBar: const ComfyBottomNav(currentIndex: 1),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    await _loadGoals();
                    await _loadGamification();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildVaultHeader(theme),
                        const SizedBox(height: 16),
                        _buildCreateGoalSection(theme),
                        const SizedBox(height: 16),
                        _buildGoalsList(theme),
                        const SizedBox(height: 16),
                        if (_goalForAdd != null) _buildAddMoneySection(theme),
                      ],
                    ),
                  ),
                ),
                const CoachChatBubble(),
              ],
            ),
    );
  }

  /// HEADER TIPO BÓVEDA
  Widget _buildVaultHeader(ThemeData theme) {
    final totalInGoals = _goals.fold<double>(
      0.0,
      (sum, g) => sum + ((g['saved'] as num?)?.toDouble() ?? 0.0),
    );
    final totalWealth = _currentBalance + totalInGoals;
    final percentInGoals =
        totalWealth <= 0 ? 0.0 : (totalInGoals / totalWealth).clamp(0.0, 1.0);

    final double progress = _nextLevelAt == 0
        ? 0.0
        : (_totalSavedToGoals / _nextLevelAt).clamp(0.0, 1.0).toDouble();

    String levelText;
    if (_level == 1) {
      levelText = 'Ahorrista inicial';
    } else if (_level == 2) {
      levelText = 'Ahorrista constante';
    } else if (_level == 3) {
      levelText = 'Ahorrista avanzado';
    } else {
      levelText = 'Maestro del ahorro';
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icono bóveda
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.1),
              ),
              child: Icon(
                Icons.savings,
                color: theme.colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            // Info principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu bóveda de metas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    levelText,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ahorro en metas: S/ ${totalInGoals.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    _level < 4
                        ? 'Te faltan S/ ${_remainingToNext.toStringAsFixed(2)} para subir a nivel ${_level + 1}'
                        : 'Has alcanzado el nivel máximo actual.',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Puntos Comfy: $_points',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // % en metas
            Column(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: percentInGoals,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                      Center(
                        child: Text(
                          '${(percentInGoals * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'En metas',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateGoalSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tus metas en la bóveda',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showCreateForm = !_showCreateForm;
                });
              },
              icon: Icon(_showCreateForm ? Icons.close : Icons.add),
              label: Text(_showCreateForm ? 'Cancelar' : 'Crear meta'),
            ),
          ],
        ),
        if (_showCreateForm)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _createFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la meta',
                        hintText: 'Ej: Viaje, estudios, emergencia…',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Ingresa un nombre para la meta';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monto objetivo (S/)',
                        hintText: 'Ej: 300.00',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        final target = double.tryParse(
                            text.replaceAll(',', '.'));
                        if (target == null || target <= 0) {
                          return 'Monto inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _deadlineController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Plazo (opcional)',
                        hintText: 'Toca para elegir fecha',
                      ),
                      onTap: () => _pickDeadline(_deadlineController),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _createLockLevel,
                      decoration: const InputDecoration(
                        labelText: 'Nivel de candado',
                        helperText:
                            'Mientras más alto, más difícil retirar por impulso',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text('Flexible'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Medio'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('Fuerte'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _createLockLevel = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _createGoal,
                        child: const Text('Guardar meta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGoalsList(ThemeData theme) {
    if (_goals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text(
          'Aún no tienes metas en tu bóveda. Crea una y comienza a ahorrar.',
        ),
      );
    }

    return Column(
      children: _goals.map((goal) {
        final saved = (goal['saved'] as num?)?.toDouble() ?? 0.0;
        final target = (goal['target'] as num?)?.toDouble() ?? 0.0;
        final double progress = target == 0
            ? 0.0
            : (saved / target).clamp(0.0, 1.0).toDouble();
        final percent = (progress * 100).toStringAsFixed(0);
        final deadlineStr = goal['deadline'] as String?;
        final lockLevel = (goal['lockLevel'] as int?) ?? 0;
        final deadline = _parseDeadline(deadlineStr);

        final statusLabel = _goalStatusLabel(progress, deadline);
        final statusColor = _goalStatusColor(progress, deadline);
        final lockLabel = _lockLevelLabelShort(lockLevel);
        final lockColor = _lockLevelColor(lockLevel);

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + chips
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal['name'] as String? ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Chip(
                                label: Text(
                                  statusLabel,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor:
                                    statusColor.withOpacity(0.08),
                                labelStyle: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                label: Text(
                                  'Candado: $lockLabel',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor:
                                    lockColor.withOpacity(0.08),
                                labelStyle: TextStyle(
                                  color: lockColor,
                                  fontSize: 11,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editGoal(goal),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteGoal(goal),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progreso
                Text(
                  'S/ ${saved.toStringAsFixed(2)} de S/ ${target.toStringAsFixed(2)} ($percent%)',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                if (deadlineStr != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.event, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Plazo: $deadlineStr',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // Acciones
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _goalForAdd = goal;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar dinero'),
                      ),
                      TextButton.icon(
                        onPressed: () => _showWithdrawDialog(goal),
                        icon: const Icon(Icons.attach_money),
                        label: const Text('Retirar'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GoalHistoryScreen(
                                goalId: goal['id'] as String,
                                goalName: goal['name'] as String? ?? '',
                              ),
                            ),
                          );
                        },
                        child: const Text('Ver movimientos'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddMoneySection(ThemeData theme) {
    final goal = _goalForAdd!;
    final saved = (goal['saved'] as num?)?.toDouble() ?? 0.0;
    final target = (goal['target'] as num?)?.toDouble() ?? 0.0;

    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _addFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agregar dinero a "${goal['name']}"',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Llevas S/ ${saved.toStringAsFixed(2)} de S/ ${target.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto a agregar (S/)',
                  hintText: 'Ej: 20.00',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  final amount =
                      double.tryParse(text.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) {
                    return 'Monto inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _goalForAdd = null;
                        _addAmountController.clear();
                      });
                    },
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addMoneyToGoal,
                    child: const Text('Guardar en la meta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
