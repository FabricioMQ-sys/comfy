import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';
import '../../widgets/comfy_bottom_nav.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  bool _isExpense(Map<String, dynamic> tx) {
    final type = tx['type'] as String? ?? '';
    // Gastos (dinero que sale de la billetera principal)
    return type == 'send' || type == 'goal_withdraw';
  }

  String _inferCategory(Map<String, dynamic> tx) {
    final type = tx['type'] as String? ?? '';
    final rawDesc = (tx['description'] ?? '') as String;
    final desc = rawDesc.toLowerCase();

    // Primero por tipo
    if (type == 'goal_withdraw') {
      return 'Retiros de metas';
    }
    if (type == 'goal_add') {
      return 'Aportes a metas (ahorro)';
    }
    if (type == 'earn') {
      return 'Ingresos extra';
    }

    // Si es envío (gasto), miramos la descripción
    if (type == 'send') {
      if (desc.contains('yape') || desc.contains('plin')) {
        return 'Transferencias a amigos (Yape/Plin)';
      }
      if (desc.contains('delivery') ||
          desc.contains('pedidos ya') ||
          desc.contains('rappi') ||
          desc.contains('uber eats')) {
        return 'Delivery / apps de comida';
      }
      if (desc.contains('uber') ||
          desc.contains('cabify') ||
          desc.contains('indriver') ||
          desc.contains('taxi')) {
        return 'Movilidad (taxis / apps)';
      }
      if (desc.contains('cine') ||
          desc.contains('netflix') ||
          desc.contains('spotify') ||
          desc.contains('hbo') ||
          desc.contains('disney') ||
          desc.contains('prime')) {
        return 'Streaming / entretenimiento';
      }
      if (desc.contains('bodega') ||
          desc.contains('tienda') ||
          desc.contains('snack') ||
          desc.contains('dulce') ||
          desc.contains('gaseosa') ||
          desc.contains('chela') ||
          desc.contains('cerveza')) {
        return 'Gastos hormiga: snacks / bodeguita';
      }
      if (desc.contains('menu') ||
          desc.contains('almuerzo') ||
          desc.contains('polleria') ||
          desc.contains('chifa') ||
          desc.contains('sangucheria')) {
        return 'Comida fuera de casa';
      }
    }

    // Por defecto
    if (type == 'send') {
      return 'Otros gastos';
    }
    return 'Otros movimientos';
  }

  bool _isGastoHormigaCategory(String category) {
    final lower = category.toLowerCase();
    return lower.contains('gastos hormiga') ||
        lower.contains('snack') ||
        lower.contains('bodeguita');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach financiero'),
      ),
      bottomNavigationBar: const ComfyBottomNav(currentIndex: 4),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: TransactionService.getTransactionsSorted(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Todavía no hay movimientos.\n'
                  'Usa Comfy unos días y aquí verás un análisis de tus gastos y recomendaciones personalizadas.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allTx = snapshot.data!;
          final now = DateTime.now();

          // 👉 Filtramos SOLO gastos del mes actual
          final monthExpenses = allTx.where((tx) {
            if (!_isExpense(tx)) return false;
            final rawDate = tx['date'];
            DateTime? d;
            if (rawDate is String) d = DateTime.tryParse(rawDate);
            if (rawDate is DateTime) d = rawDate;
            if (d == null) return false;
            return d.year == now.year && d.month == now.month;
          }).toList();

          if (monthExpenses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Este mes casi no has tenido gastos.\n'
                  'Buen inicio, a medida que registres más movimientos te daré un diagnóstico más completo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          double totalMonth = 0;
          final Map<String, double> categoryTotals = {};

          for (final tx in monthExpenses) {
            final amount = (tx['amount'] as num).toDouble();
            totalMonth += amount;
            final cat = _inferCategory(tx);
            categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
          }

          // Ordenar categorías de mayor a menor gasto
          final sortedEntries = categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // Calcular total de gastos hormiga
          double totalHormiga = 0;
          for (final entry in sortedEntries) {
            if (_isGastoHormigaCategory(entry.key)) {
              totalHormiga += entry.value;
            }
          }

          // Categoría principal (dónde más se va el dinero)
          String? topCategory;
          double topCategoryPercent = 0;
          if (sortedEntries.isNotEmpty && totalMonth > 0) {
            topCategory = sortedEntries.first.key;
            topCategoryPercent = sortedEntries.first.value / totalMonth;
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildHeaderCoach(
                totalMonth: totalMonth,
                totalHormiga: totalHormiga,
                topCategory: topCategory,
                topCategoryPercent: topCategoryPercent,
              ),
              const SizedBox(height: 16),
              _buildCategoriasCard(sortedEntries, totalMonth),
              const SizedBox(height: 16),
              _buildTipsCard(totalMonth, totalHormiga),
            ],
          );
        },
      ),
    );
  }

  /// HEADER EJECUTIVO DEL COACH
  Widget _buildHeaderCoach({
    required double totalMonth,
    required double totalHormiga,
    required String? topCategory,
    required double topCategoryPercent,
  }) {
    final double hormigaPercent =
        totalMonth == 0 ? 0.0 : (totalHormiga / totalMonth).clamp(0.0, 1.0);

    final String hormigaLabel = totalMonth == 0
        ? '0%'
        : '${(hormigaPercent * 100).toStringAsFixed(0)}%';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Indicador circular de gastos hormiga
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: hormigaPercent,
                    strokeWidth: 7,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.orange,
                    ),
                  ),
                  Center(
                    child: Text(
                      hormigaLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Texto resumen
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen de tus gastos del mes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gasto total: S/ ${totalMonth.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gastos hormiga estimados: S/ ${totalHormiga.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (topCategory != null && totalMonth > 0)
                    Text(
                      'Principal categoría: $topCategory '
                      '(${(topCategoryPercent * 100).toStringAsFixed(1)}% de tu gasto)',
                      style: const TextStyle(fontSize: 12),
                    )
                  else
                    const Text(
                      'Aún no se identifica una categoría dominante.',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriasCard(
    List<MapEntry<String, double>> sortedEntries,
    double totalMonth,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿En qué se va tu dinero?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...sortedEntries.map((entry) {
              final category = entry.key;
              final amount = entry.value;
              final percent = totalMonth == 0 ? 0 : amount / totalMonth;
              final isHormiga = _isGastoHormigaCategory(category);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isHormiga)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Gasto hormiga',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'S/ ${amount.toStringAsFixed(2)} '
                      '(${(percent * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard(double totalMonth, double totalHormiga) {
    final List<String> tips = [];

    if (totalHormiga > 0 && totalMonth > 0) {
      final pct = (totalHormiga / totalMonth) * 100;
      if (pct >= 30) {
        tips.add(
          'Tus gastos hormiga concentran más del 30% de tu gasto mensual.\n'
          'Te puede ayudar definir un monto máximo semanal para snacks, delivery y compras impulsivas.',
        );
      } else if (pct >= 15) {
        tips.add(
          'Los gastos hormiga tienen un peso importante en tu mes.\n'
          'Prueba establecer algunos días a la semana sin compras espontáneas.',
        );
      } else {
        tips.add(
          'Tus gastos hormiga están relativamente controlados.\n'
          'Mantén este nivel y evalúa si puedes redirigir una parte adicional hacia tus metas de ahorro.',
        );
      }
    }

    if (totalMonth > 0 && totalMonth < 200) {
      tips.add(
        'Tu gasto total del mes es bajo.\n'
        'Podrías aprovechar para incrementar ligeramente el porcentaje que destinas a ahorro.',
      );
    } else if (totalMonth >= 200 && totalMonth < 800) {
      tips.add(
        'Tu nivel de gasto mensual es moderado.\n'
        'Como referencia, podrías intentar mover entre el 10% y 20% de ese monto a tus metas.',
      );
    } else if (totalMonth >= 800) {
      tips.add(
        'Este mes estás moviendo un monto significativo.\n'
        'Revisa si los gastos más grandes están alineados con lo que realmente priorizas (estudios, proyectos, deudas, etc.).',
      );
    }

    if (tips.isEmpty) {
      tips.add(
        'A medida que registres más movimientos, podré darte recomendaciones más específicas sobre tus hábitos de gasto.',
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recomendaciones para este mes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...tips.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '• $t',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
