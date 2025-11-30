import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../storage/local_storage.dart';

class GoalHistoryScreen extends StatelessWidget {
  final String goalId;
  final String goalName;

  const GoalHistoryScreen({
    super.key,
    required this.goalId,
    required this.goalName,
  });

  Future<List<Map<String, dynamic>>> _loadGoalTransactions() async {
    final phone = await LocalStorage.getPhone();
    if (phone == null || phone.trim().isEmpty) return [];

    final cleanPhone = phone.trim();

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(cleanPhone)
        .collection('transactions')
        .where('goalId', isEqualTo: goalId)
        .get();

    final list = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        ...data,
        'id': data['id'] ?? doc.id,
      };
    }).toList();

    // Ordenamos por fecha (más recientes primero)
    list.sort((a, b) {
      final da = DateTime.tryParse((a['date'] ?? '').toString());
      final db = DateTime.tryParse((b['date'] ?? '').toString());
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Movimientos de "$goalName"'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadGoalTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar movimientos: ${snapshot.error}'),
            );
          }

          final goalTx = snapshot.data ?? [];

          if (goalTx.isEmpty) {
            return const Center(
              child: Text('Aún no hay movimientos para esta meta.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goalTx.length,
            itemBuilder: (context, index) {
              final tx = goalTx[index];
              final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
              final type = tx['type'] as String? ?? '';

              final isAdd = type == 'goal_add';
              final isWithdraw = type == 'goal_withdraw';

              final dateRaw = tx['date']?.toString();
              final date =
                  dateRaw != null ? DateTime.tryParse(dateRaw) : null;

              final dateStr = date == null
                  ? ''
                  : '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/'
                      '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
                      '${date.minute.toString().padLeft(2, '0')}';

              String typeLabel = type;
              if (isAdd) typeLabel = 'Aporte a meta';
              if (isWithdraw) typeLabel = 'Retiro de meta';

              final reason = tx['reason']?.toString();

              return Card(
                child: ListTile(
                  title: Text(typeLabel),
                  subtitle: Text(
                    '${reason != null && reason.isNotEmpty ? '$reason · ' : ''}$dateStr',
                  ),
                  trailing: Text(
                    (isAdd ? '+ ' : '- ') +
                        'S/ ${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isAdd ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
