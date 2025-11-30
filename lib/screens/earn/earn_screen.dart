import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';
import '../../services/goal_service.dart';
import '../../storage/local_storage.dart';
import '../../widgets/comfy_bottom_nav.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  bool _loading = true;

  double _currentBalance = 0.0;
  double _totalMonthExpenses = 0.0;
  double _totalHormiga = 0.0;
  double _potentialMonthlySaving = 0.0;

  // metas
  List<Map<String, dynamic>> _goals = [];
  String? _selectedGoalId;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final txs = await TransactionService.getTransactions();
    final balance = await LocalStorage.getBalance();
    final goals = await GoalService.getGoals();

    final now = DateTime.now();
    double monthExpenses = 0.0;
    double monthHormiga = 0.0;

    for (final tx in txs) {
      final rawDate = tx['date'];
      DateTime? d;
      if (rawDate is String) d = DateTime.tryParse(rawDate);
      if (rawDate is DateTime) d = rawDate;
      if (d == null) continue;

      if (d.year == now.year && d.month == now.month) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount <= 0) continue;

        final type = (tx['type'] as String?) ?? '';
        final isIncome =
            type == 'receive' || type == 'earn' || type == 'goal_refund';

        if (!isIncome) {
          monthExpenses += amount;
          if (_isHormiga(tx)) {
            monthHormiga += amount;
          }
        }
      }
    }

    final potential = monthHormiga * 0.2; // 20% de gastos hormiga como objetivo

    if (!mounted) return;
    setState(() {
      _currentBalance = balance;
      _totalMonthExpenses = monthExpenses;
      _totalHormiga = monthHormiga;
      _potentialMonthlySaving = potential;
      _goals = goals;
      if (_goals.isNotEmpty && _selectedGoalId == null) {
        _selectedGoalId = _goals.first['id'] as String;
      }
      _loading = false;
    });
  }

  bool _isHormiga(Map<String, dynamic> tx) {
    final cat = tx['category'] as String?;
    final isH = tx['isHormiga'] as bool?;
    if (isH == true) return true;
    if (cat == null) return false;
    return cat.startsWith('gasto_hormiga_');
  }

  Future<bool> _confirmWithPin() async {
    final storedPin = await LocalStorage.getPin();
    if (storedPin == null) {
      // Si no hay PIN configurado, dejamos pasar (no debería pasar, pero no rompemos flujo)
      return true;
    }

    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirma con tu PIN comfy'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
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

  Future<void> _quickSavePotentialToGoal() async {
    if (_potentialMonthlySaving <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Aún no hay un ahorro potencial calculado para este mes.'),
        ),
      );
      return;
    }

    if (_goals.isEmpty || _selectedGoalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea una meta en la sección "Metas".'),
        ),
      );
      return;
    }

    if (_currentBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No tienes saldo disponible para apartar a una meta ahora.'),
        ),
      );
      return;
    }

    final okPin = await _confirmWithPin();
    if (!okPin) return;

    // Monto a mover: lo que se puede según saldo
    final amount = _potentialMonthlySaving <= _currentBalance
        ? _potentialMonthlySaving
        : _currentBalance;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto a apartar debe ser mayor a 0.'),
        ),
      );
      return;
    }

    final goal = _goals.firstWhere(
      (g) => g['id'] == _selectedGoalId,
      orElse: () => {},
    );
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró la meta seleccionada.')),
      );
      return;
    }

    final goalId = goal['id'];
    final goalName = goal['name'] ?? 'Meta';

    // 1) Restar del saldo principal
    final currentBalance = await LocalStorage.getBalance();
    await LocalStorage.saveBalance(currentBalance - amount);

    // 2) Sumar a la meta
    await GoalService.addToGoal(goalId, amount);

    // 3) Registrar transacción
    await TransactionService.addTransaction({
      'amount': amount,
      'type': 'goal_add',
      'date': DateTime.now().toIso8601String(),
      'goalId': goalId,
      'goalName': goalName,
      'description': 'Ahorro rápido desde sección Ganar/Ahorrar',
    });

    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Apartaste S/ ${amount.toStringAsFixed(2)} a "$goalName" 💚',
        ),
      ),
    );
  }

  Future<void> _registerExtraIncome() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
          _amountController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    final desc = _descController.text.trim();

    if (amount <= 0) return;

    // 1) Actualizar saldo principal
    final currentBalance = await LocalStorage.getBalance();
    await LocalStorage.saveBalance(currentBalance + amount);

    // 2) Registrar transacción como "earn"
    await TransactionService.addTransaction({
      'amount': amount,
      'type': 'earn',
      'date': DateTime.now().toIso8601String(),
      'description': desc.isEmpty ? 'Ingreso extra' : desc,
    });

    // 3) Limpiar y recargar datos
    _amountController.clear();
    _descController.clear();
    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ingreso registrado correctamente.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganar y ahorrar más'),
      ),
      bottomNavigationBar: const ComfyBottomNav(currentIndex: 2),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildPotentialCard(theme),
                  const SizedBox(height: 16),
                  _buildChallengesCard(theme),
                  const SizedBox(height: 16),
                  _buildExtraIncomeCard(theme),
                ],
              ),
            ),
    );
  }

  // -------------------- CARD 1: POTENCIAL DE AHORRO --------------------

  Widget _buildPotentialCard(ThemeData theme) {
    final double percentHormiga = _totalMonthExpenses > 0
        ? (_totalHormiga / _totalMonthExpenses * 100).clamp(0, 100)
        : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu potencial de ahorro este mes',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Gastos del mes: S/ ${_totalMonthExpenses.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Estimado en gastos hormiga: S/ ${_totalHormiga.toStringAsFixed(2)} '
              '(${percentHormiga.toStringAsFixed(0)}% de tus gastos)',
              style: const TextStyle(fontSize: 13, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_graph,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _potentialMonthlySaving > 0
                          ? 'Si rediriges solo el 20% de tus gastos hormiga, podrías mover '
                              'aprox. S/ ${_potentialMonthlySaving.toStringAsFixed(2)} a tus metas este mes.'
                          : 'Aún no se identifican gastos hormiga suficientes para estimar un potencial de ahorro.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_potentialMonthlySaving > 0 && _goals.isNotEmpty) ...[
              Text(
                'Apartar rápido a una meta',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGoalId,
                decoration: const InputDecoration(
                  labelText: 'Selecciona una meta',
                ),
                items: _goals.map((g) {
                  final id = g['id'] as String;
                  final name = g['name']?.toString() ?? 'Meta';
                  return DropdownMenuItem(
                    value: id,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGoalId = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _quickSavePotentialToGoal,
                  icon: const Icon(Icons.savings_outlined),
                  label: Text(
                    'Apartar ahora S/ ${_potentialMonthlySaving.toStringAsFixed(2)}',
                  ),
                ),
              ),
            ] else if (_potentialMonthlySaving > 0 && _goals.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Tip: Crea una meta en la sección "Metas" para poder mover este ahorro potencial automáticamente.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------- CARD 2: RETOS / CHALLENGES --------------------

  Widget _buildChallengesCard(ThemeData theme) {
    final List<_ComfyChallenge> challenges = [
      _ComfyChallenge(
        title: 'Reto 7 días sin delivery',
        description:
            'Evita apps de comida por una semana y destina lo que habrías gastado a una de tus metas.',
        suggestedPercent: 0.25,
      ),
      _ComfyChallenge(
        title: 'Reto “cafecito consciente”',
        description:
            'Reduce a la mitad tus compras de café fuera de casa durante este mes.',
        suggestedPercent: 0.15,
      ),
      _ComfyChallenge(
        title: 'Reto “transferencias con propósito”',
        description:
            'Antes de cada envío, decide si puedes reservar S/ 5–10 adicionales para tu meta principal.',
        suggestedPercent: 0.10,
      ),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retos para ganar más control',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Elige un reto concreto para este mes. La idea es mover pequeñas decisiones a favor de tus metas.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...challenges.map((c) {
              final potentialFromChallenge =
                  (_totalHormiga * c.suggestedPercent).toStringAsFixed(2);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (_totalHormiga > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Si lo cumples, podrías redirigir aprox. S/ $potentialFromChallenge este mes.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // -------------------- CARD 3: REGISTRAR INGRESO EXTRA --------------------

  Widget _buildExtraIncomeCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registrar ingreso extra',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Salario freelance, venta de algo que ya no usas, apoyo familiar, etc.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto (S/)',
                  hintText: 'Ej: 150.00',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  final amount =
                      double.tryParse(text.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) {
                    return 'Ingresa un monto válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej: freelance de diseño, venta de ropa, etc.',
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _registerExtraIncome,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar ingreso'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Saldo actual de tu billetera: S/ ${_currentBalance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComfyChallenge {
  final String title;
  final String description;
  final double suggestedPercent;

  const _ComfyChallenge({
    required this.title,
    required this.description,
    required this.suggestedPercent,
  });
}
