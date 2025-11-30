import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';
import '../../storage/local_storage.dart';
import '../coach/coach_screen.dart';
import '../../widgets/comfy_bottom_nav.dart';
import '../../widgets/coach_chat_bubble.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _allTx = [];
  double _currentBalance = 0.0;

  /// Filtros posibles: all, today, yesterday, week, month, hormiga
  String _currentFilter = 'month';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final txs = await TransactionService.getTransactions();
    final balance = await LocalStorage.getBalance();

    // Ordenar por fecha descendente
    txs.sort((a, b) {
      final da = _parseDate(a);
      final db = _parseDate(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    if (!mounted) return;
    setState(() {
      _allTx = txs;
      _currentBalance = balance;
      _loading = false;
    });
  }

  DateTime? _parseDate(Map<String, dynamic> tx) {
    final raw = tx['date'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool _isHormiga(Map<String, dynamic> tx) {
    final cat = tx['category'] as String?;
    final isH = tx['isHormiga'] as bool?;
    if (isH == true) return true;
    if (cat == null) return false;
    return cat.startsWith('gasto_hormiga_');
  }

  bool _isIncome(Map<String, dynamic> tx) {
    final type = tx['type'] as String? ?? '';
    return type == 'receive' || type == 'earn' || type == 'goal_refund';
  }

  /// Aplica el filtro seleccionado al listado
  List<Map<String, dynamic>> _applyCurrentFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<Map<String, dynamic>> filtered = [];

    for (final tx in _allTx) {
      final date = _parseDate(tx);
      if (date == null) continue;
      final justDate = DateTime(date.year, date.month, date.day);

      switch (_currentFilter) {
        case 'today':
          if (justDate == today) filtered.add(tx);
          break;
        case 'yesterday':
          final yesterday = today.subtract(const Duration(days: 1));
          if (justDate == yesterday) filtered.add(tx);
          break;
        case 'week':
          final from = today.subtract(const Duration(days: 6));
          if (justDate.isAfter(from.subtract(const Duration(days: 1))) &&
              justDate.isBefore(today.add(const Duration(days: 1)))) {
            filtered.add(tx);
          }
          break;
        case 'month':
          if (date.year == now.year && date.month == now.month) {
            filtered.add(tx);
          }
          break;
        case 'hormiga':
          if (_isHormiga(tx)) {
            filtered.add(tx);
          }
          break;
        case 'all':
        default:
          filtered.add(tx);
      }
    }

    return filtered;
  }

  /// Para el resumen, usamos SIEMPRE el mes actual
  Map<String, double> _calculateMonthSummary() {
    final now = DateTime.now();
    double totalExpenses = 0.0;
    double totalIncome = 0.0;
    double totalHormiga = 0.0;

    for (final tx in _allTx) {
      final date = _parseDate(tx);
      if (date == null) continue;
      if (date.year != now.year || date.month != now.month) continue;

      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) continue;

      if (_isIncome(tx)) {
        totalIncome += amount;
      } else {
        totalExpenses += amount;
        if (_isHormiga(tx)) {
          totalHormiga += amount;
        }
      }
    }

    return {
      'expenses': totalExpenses,
      'income': totalIncome,
      'hormiga': totalHormiga,
    };
  }

  String _formatSectionLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final just = DateTime(date.year, date.month, date.day);

    if (just == today) return 'Hoy';
    if (just == yesterday) return 'Ayer';

    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _formatTime(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _prettyCategory(Map<String, dynamic> tx) {
    final cat = (tx['category'] as String?) ?? '';
    switch (cat) {
      case 'gasto_hormiga_comida':
        return 'Antojitos / comida rápida';
      case 'gasto_hormiga_cafe':
        return 'Cafés y bebidas';
      case 'gasto_hormiga_delivery':
        return 'Delivery';
      case 'gasto_hormiga_taxi':
        return 'Taxi / movilidad';
      case 'gasto_hormiga_snacks':
        return 'Snacks y dulces';
      case 'gasto_hormiga_suscripciones':
        return 'Suscripciones pequeñas';
      case 'gasto_hormiga_tiendas':
        return 'Tiendas de conveniencia';
      case 'gasto_hormiga_digital':
        return 'Compras digitales';
      case 'ingreso':
        return 'Ingreso';
      case 'ingreso_extra':
        return 'Ingreso extra';
      case 'meta_aporte':
        return 'Aporte a meta';
      case 'meta_retiro':
        return 'Retiro de meta';
      case 'meta_devolucion':
        return 'Devolución de meta';
      case 'gasto_general':
        return 'Gasto';
      default:
        if (_isHormiga(tx)) return 'Gasto hormiga';
        return 'Otro';
    }
  }

  IconData _iconForTx(Map<String, dynamic> tx) {
    final type = tx['type'] as String? ?? '';
    final cat = tx['category'] as String? ?? '';

    if (type == 'send') return Icons.arrow_upward;
    if (type == 'receive') return Icons.arrow_downward;
    if (type == 'earn') return Icons.emoji_events;
    if (type == 'goal_add') return Icons.savings;
    if (type == 'goal_withdraw') return Icons.savings_outlined;
    if (type == 'goal_refund') return Icons.account_balance_wallet;

    if (cat.startsWith('gasto_hormiga_')) return Icons.local_cafe;

    return Icons.account_balance_wallet;
  }

  Color _amountColor(Map<String, dynamic> tx) {
    final isIncome = _isIncome(tx);
    return isIncome ? Colors.green : Colors.red;
  }

  String _amountPrefix(Map<String, dynamic> tx) {
    final isIncome = _isIncome(tx);
    return isIncome ? '+ ' : '- ';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de movimientos'),
      ),
      bottomNavigationBar: const ComfyBottomNav(currentIndex: 3),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(      
            children: [
              RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        _buildSummaryCard(theme),
                        const SizedBox(height: 12),
                        _buildFilterChips(theme),
                        const SizedBox(height: 16),
                        _buildGroupedList(theme),
                      ],
                    ),
                  ),
                  const CoachChatBubble(),
            ],
          ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final sum = _calculateMonthSummary();
    final expenses = sum['expenses']!;
    final income = sum['income']!;
    final hormiga = sum['hormiga']!;
    final percentHormiga =
        expenses > 0 ? (hormiga / expenses * 100).clamp(0, 100) : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icono / avatar del historial
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.analytics_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen del mes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saldo actual: S/ ${_currentBalance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gastos totales',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              'S/ ${expenses.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ingresos',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              'S/ ${income.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gastos hormiga: S/ ${hormiga.toStringAsFixed(2)} '
                    '(${percentHormiga.toStringAsFixed(0)}% de tus gastos)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (hormiga > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Si reduces tus gastos hormiga un 20%, podrías mover aprox. '
                      'S/ ${(hormiga * 0.2).toStringAsFixed(2)} a tus metas.',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CoachScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.psychology_outlined, size: 18),
                      label: const Text('Ver coach financiero'),
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

  Widget _buildFilterChips(ThemeData theme) {
    final List<Map<String, String>> filters = <Map<String, String>>[
      {'key': 'all', 'label': 'Todo'},
      {'key': 'today', 'label': 'Hoy'},
      {'key': 'yesterday', 'label': 'Ayer'},
      {'key': 'week', 'label': 'Esta semana'},
      {'key': 'month', 'label': 'Este mes'},
      {'key': 'hormiga', 'label': 'Gasto hormiga'},
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final key = f['key'] as String;
              final label = f['label'] as String;
              final selected = _currentFilter == key;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  selected: selected,
                  selectedColor:
                      theme.colorScheme.primary.withOpacity(0.12),
                  onSelected: (value) {
                    if (!value) return;
                    setState(() {
                      _currentFilter = key;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList(ThemeData theme) {
    final filtered = _applyCurrentFilter();

    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 32.0),
          child: Text('No hay movimientos para este filtro todavía.'),
        ),
      );
    }

    // Agrupar por día
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, DateTime> keyToDate = {};

    for (final tx in filtered) {
      final date = _parseDate(tx);
      if (date == null) continue;
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
      keyToDate[key] = DateTime(date.year, date.month, date.day);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) => keyToDate[b]!.compareTo(keyToDate[a]!));

    final List<Widget> children = [];

    for (final key in keys) {
      final date = keyToDate[key]!;
      final label = _formatSectionLabel(date);

      final txs = grouped[key]!;

      // Resumen por día (ingresos vs gastos)
      double dayIncome = 0.0;
      double dayExpenses = 0.0;
      for (final tx in txs) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount <= 0) continue;
        if (_isIncome(tx)) {
          dayIncome += amount;
        } else {
          dayExpenses += amount;
        }
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                '+ S/ ${dayIncome.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '- S/ ${dayExpenses.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

      for (final tx in txs) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final dateTime = _parseDate(tx);
        final timeStr = dateTime != null ? _formatTime(dateTime) : '';
        final desc = (tx['description'] as String?) ?? 'Movimiento';
        final catPretty = _prettyCategory(tx);
        final icon = _iconForTx(tx);
        final color = _amountColor(tx);
        final prefix = _amountPrefix(tx);
        final isHormiga = _isHormiga(tx);

        children.add(
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            elevation: 1,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.08),
                child: Icon(icon, size: 18, color: color),
              ),
              title: Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${isHormiga ? 'Gasto hormiga · ' : ''}$catPretty · $timeStr',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '${prefix} S/ ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
