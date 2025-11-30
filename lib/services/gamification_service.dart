import 'transaction_service.dart';

class GamificationService {
  // Retorna stats básicos de gamificación
  static Future<Map<String, dynamic>> getSavingStats() async {
    final txs = await TransactionService.getTransactions();

    double totalSavedToGoals = 0;
    int goalActions = 0;

    for (final tx in txs) {
      final type = tx['type'] as String? ?? '';
      if (type == 'goal_add') {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        totalSavedToGoals += amount;
        goalActions++;
      }
    }

    // Nivel simple según ahorro total
    int level;
    double nextLevelAt;
    if (totalSavedToGoals < 100) {
      level = 1;
      nextLevelAt = 100;
    } else if (totalSavedToGoals < 250) {
      level = 2;
      nextLevelAt = 250;
    } else if (totalSavedToGoals < 500) {
      level = 3;
      nextLevelAt = 500;
    } else {
      level = 4;
      nextLevelAt = totalSavedToGoals; // ya está en máximo
    }

    final points = (totalSavedToGoals * 10).round(); // 1 sol ahorrado = 10 puntos
    final remaining = (nextLevelAt - totalSavedToGoals).clamp(0, double.infinity);

    return {
      'totalSavedToGoals': totalSavedToGoals,
      'goalActions': goalActions,
      'level': level,
      'points': points,
      'remainingToNext': remaining,
      'nextLevelAt': nextLevelAt,
    };
  }
}
