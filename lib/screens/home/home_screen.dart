import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/comfy_bottom_nav.dart';
import '../../storage/local_storage.dart';
import '../../services/goal_service.dart';
import '../../services/transaction_service.dart';
import '../profile/profile_screen.dart';
import '../../widgets/coach_chat_bubble.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _name = 'Usuario';
  double _balance = 0;

  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _recentTransactions = [];

  // Resumen del mes
  double _monthExpenses = 0;
  double _monthSavings = 0;
  double _monthIncome = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Datos locales (caché)
    final localName = await LocalStorage.getUserName();
    final localBalance = await LocalStorage.getBalance();
    final phone = await LocalStorage.getPhone();

    // Metas y transacciones (ya vienen de Firestore)
    final goals = await GoalService.getGoals();
    final txs = await TransactionService.getTransactionsSorted();

    double finalBalance = localBalance;
    String finalName =
        (localName == null || localName.trim().isEmpty) ? 'Usuario' : localName.trim();

    // ------------------ LEER PERFIL DESDE FIRESTORE ------------------
    if (phone != null && phone.trim().isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(phone.trim())
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final remoteName = data['name'] as String?;
            final remoteBalance = (data['balance'] as num?)?.toDouble();

            if (remoteName != null && remoteName.trim().isNotEmpty) {
              finalName = remoteName.trim();
              await LocalStorage.saveUserName(finalName);
            }

            if (remoteBalance != null) {
              finalBalance = remoteBalance;
              await LocalStorage.saveBalance(finalBalance);
            }
          }
        }
      } catch (_) {
        // Si falla Firestore, nos quedamos con los datos locales sin romper la app
      }
    }

    // ------------------ CÁLCULO DE RESUMEN MENSUAL ------------------
    final now = DateTime.now();
    double monthExpenses = 0;
    double monthSavings = 0;
    double monthIncome = 0;

    for (final tx in txs) {
      final rawDate = tx['date'] ?? tx['createdAt'];

      DateTime? d;
      if (rawDate is Timestamp) {
        d = rawDate.toDate();
      } else if (rawDate is DateTime) {
        d = rawDate;
      } else if (rawDate is String) {
        d = DateTime.tryParse(rawDate);
      }

      if (d == null || d.year != now.year || d.month != now.month) continue;

      final type = tx['type']?.toString() ?? '';
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

      // Gasto (sale de la billetera)
      if (type == 'send' || type == 'goal_withdraw') {
        monthExpenses += amount;
      }
      // Ahorro a metas
      else if (type == 'goal_add') {
        monthSavings += amount;
      }
      // Ingresos (entra a la billetera)
      else if (type == 'receive' || type == 'earn' || type == 'goal_refund') {
        monthIncome += amount;
      }
    }

    if (!mounted) return;

    setState(() {
      _name = finalName;
      _balance = finalBalance;
      _goals = goals;
      _recentTransactions = txs.take(3).toList();
      _monthExpenses = monthExpenses;
      _monthSavings = monthSavings;
      _monthIncome = monthIncome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Map<String, dynamic>? mainGoal;
    if (_goals.isNotEmpty) {
      mainGoal = _goals.first;
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, $_name',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Resumen general de tu billetera',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Perfil y configuración',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
              _loadUserData();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadUserData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(theme),
                  const SizedBox(height: 16),
                  _buildMonthOverviewRow(theme),
                  const SizedBox(height: 20),
                  _buildQuickActionsRow(theme),
                  const SizedBox(height: 24),
                  Text(
                    'Metas de ahorro',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.pushNamed(context, '/goals');
                      _loadUserData();
                    },
                    child: _buildGoalsSummaryCard(mainGoal),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Text(
                        'Últimos movimientos',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/history');
                          _loadUserData();
                        },
                        child: const Text('Ver todo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLastTransactionsSection(),
                ],
              ),
            ),
          ),
          const CoachChatBubble(),
        ],
      ),
      bottomNavigationBar: const ComfyBottomNav(currentIndex: 0),
    );
  }

  // ---------------- BALANCE CARD ----------------

  Widget _buildBalanceCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo disponible',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _balance),
            duration: const Duration(milliseconds: 450),
            builder: (context, value, child) {
              return Text(
                'S/ ${value.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Administra tu dinero, tus metas y oportunidades de ingreso desde un solo lugar.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  await Navigator.pushNamed(context, '/send');
                  _loadUserData();
                },
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text('Enviar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  await Navigator.pushNamed(context, '/receive');
                  _loadUserData();
                },
                icon: const Icon(Icons.arrow_downward, size: 18),
                label: const Text('Recibir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- MONTH OVERVIEW ----------------

  Widget _buildMonthOverviewRow(ThemeData theme) {
    final textStyleLabel = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
      fontSize: 11,
    );

    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Gasto del mes',
            amount: _monthExpenses,
            icon: Icons.trending_down,
            color: Colors.red.shade400,
            labelStyle: textStyleLabel,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            label: 'Ahorro a metas',
            amount: _monthSavings,
            icon: Icons.savings_outlined,
            color: Colors.indigo.shade400,
            labelStyle: textStyleLabel,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            label: 'Ingresos',
            amount: _monthIncome,
            icon: Icons.trending_up,
            color: Colors.teal.shade400,
            labelStyle: textStyleLabel,
          ),
        ),
      ],
    );
  }

  // ---------------- QUICK ACTIONS ----------------

  Widget _buildQuickActionsRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionButton(
          icon: Icons.savings_outlined,
          label: 'Metas',
          color: theme.colorScheme.primary,
          onTap: () async {
            await Navigator.pushNamed(context, '/goals');
            _loadUserData();
          },
        ),
        _ActionButton(
          icon: Icons.receipt_long_outlined,
          label: 'Historial',
          color: Colors.teal,
          onTap: () async {
            await Navigator.pushNamed(context, '/history');
            _loadUserData();
          },
        ),
        _ActionButton(
          icon: Icons.add_chart_outlined,
          label: 'Ganar',
          color: Colors.orange,
          onTap: () async {
            await Navigator.pushNamed(context, '/earn');
            _loadUserData();
          },
        ),
      ],
    );
  }

  // ---------------- GOALS SUMMARY ----------------

  Widget _buildGoalsSummaryCard(Map<String, dynamic>? mainGoal) {
    if (mainGoal == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.grey.shade100,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aún no tienes metas registradas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Crea tu primera meta de ahorro para organizar mejor tus objetivos.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Toca aquí para configurar tus metas de ahorro.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    final name = mainGoal['name']?.toString() ?? '';
    final target = (mainGoal['target'] as num?)?.toDouble() ?? 0.0;
    final saved = (mainGoal['saved'] as num?)?.toDouble() ?? 0.0;
    final progress = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            'Acumulado: S/ ${saved.toStringAsFixed(2)} de S/ ${target.toStringAsFixed(2)} ($percent%)',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca para ver y gestionar todas tus metas.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ---------------- LAST TRANSACTIONS ----------------

  Widget _buildLastTransactionsSection() {
    if (_recentTransactions.isEmpty) {
      return const Text(
        'Cuando empieces a usar la billetera verás aquí un resumen rápido de tus últimos movimientos.',
        style: TextStyle(fontSize: 13),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTransactions.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (_, index) {
        final tx = _recentTransactions[index];
        return _buildTransactionTile(tx);
      },
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final String type = tx['type']?.toString() ?? 'other';
    final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final String? rawDate = tx['date']?.toString();
    final String description = (tx['description'] as String?) ?? '';
    final String goalName = (tx['goalName'] as String?) ?? '';

    DateTime? date;
    if (rawDate != null) {
      date = DateTime.tryParse(rawDate);
    }

    final displayDate = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';

    String title;
    Color color;
    IconData icon;
    bool isOut;

    switch (type) {
      case 'send':
        title = 'Transferencia enviada';
        color = Colors.red;
        icon = Icons.arrow_upward;
        isOut = true;
        break;
      case 'receive':
        title = 'Transferencia recibida';
        color = Colors.green;
        icon = Icons.arrow_downward;
        isOut = false;
        break;
      case 'goal_add':
        title = 'Aporte a meta';
        color = Colors.indigo;
        icon = Icons.savings;
        isOut = true;
        break;
      case 'goal_withdraw':
        title = 'Retiro desde meta';
        color = Colors.orange;
        icon = Icons.savings_outlined;
        isOut = false;
        break;
      case 'goal_refund':
        title = 'Devolución de meta';
        color = Colors.blueGrey;
        icon = Icons.savings_outlined;
        isOut = false;
        break;
      case 'earn':
        title = 'Ingreso extra';
        color = Colors.teal;
        icon = Icons.add_chart;
        isOut = false;
        break;
      default:
        title = 'Movimiento';
        color = Colors.blueGrey;
        icon = Icons.swap_horiz;
        isOut = false;
    }

    if (goalName.isNotEmpty &&
        (type == 'goal_add' || type == 'goal_withdraw' || type == 'goal_refund')) {
      title = '$title · $goalName';
    }

    final List<String> subtitleParts = [];
    if (description.isNotEmpty) {
      subtitleParts.add(description);
    }
    if (displayDate.isNotEmpty) {
      subtitleParts.add(displayDate);
    }

    final subtitleText = subtitleParts.join(' · ');
    final String signPrefix = isOut ? '- S/ ' : '+ S/ ';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitleText.isEmpty
          ? null
          : Text(
              subtitleText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Text(
        '$signPrefix${amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: isOut ? Colors.red : Colors.green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------- WIDGETS AUXILIARES ----------

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: color.withOpacity(0.08),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final TextStyle? labelStyle;

  const _MiniStatCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 2),
                Text(
                  'S/ ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
