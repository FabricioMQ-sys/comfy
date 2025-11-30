import 'package:flutter/material.dart';
import '../../storage/local_storage.dart';
import '../../services/transaction_service.dart';

class CoachChatScreen extends StatefulWidget {
  const CoachChatScreen({super.key});

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _loadingContext = true;
  bool _sending = false;

  // Contexto financiero simple para las respuestas
  double _monthIncome = 0.0;
  double _monthExpenses = 0.0;
  double _monthHormiga = 0.0;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _initContext();
  }

  Future<void> _initContext() async {
    final now = DateTime.now();

    final txs = await TransactionService.getTransactionsSorted();
    final balance = await LocalStorage.getBalance();

    double income = 0.0;
    double expenses = 0.0;
    double hormiga = 0.0;

    for (final tx in txs) {
      final rawDate = tx['date'];
      DateTime? d;
      if (rawDate is String) d = DateTime.tryParse(rawDate);
      if (rawDate is DateTime) d = rawDate;
      if (d == null) continue;
      if (d.year != now.year || d.month != now.month) continue;

      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) continue;

      final type = tx['type'] as String? ?? '';
      final cat = tx['category'] as String? ?? '';

      final isIncome =
          type == 'receive' || type == 'earn' || type == 'goal_refund';

      if (isIncome) {
        income += amount;
      } else {
        expenses += amount;
        if (cat.startsWith('gasto_hormiga_')) {
          hormiga += amount;
        }
      }
    }

    setState(() {
      _monthIncome = income;
      _monthExpenses = expenses;
      _monthHormiga = hormiga;
      _currentBalance = balance;
      _loadingContext = false;

      _messages.add(
        _ChatMessage(
          fromUser: false,
          text:
              'Hola, soy tu coach comfy 🤖💚\n\n'
              'Puedes preguntarme cosas como:\n'
              '• Cómo distribuir tus ingresos\n'
              '• Cómo bajar tus gastos hormiga\n'
              '• Cómo llegar a una meta de ahorro\n'
              '• O simplemente: "¿Cómo manejar mejor mi plata?"',
        ),
      );
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending || _loadingContext) return;

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(fromUser: true, text: text));
      _inputController.clear();
    });

    // Generar respuesta "inteligente" en base a reglas + contexto
    final reply = await _generateReply(text);

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(fromUser: false, text: reply));
      _sending = false;
    });
  }

  Future<String> _generateReply(String userText) async {
    final q = userText.toLowerCase();

    // Por si el contexto aún no está listo
    if (_loadingContext) {
      return 'Dame un toque que estoy cargando tus movimientos... inténtalo otra vez en unos segundos 😉';
    }

    // Algunos datos base
    final totalMes = _monthExpenses + _monthIncome;
    final hormigaPct =
        _monthExpenses > 0 ? (_monthHormiga / _monthExpenses) * 100 : 0.0;

    // 1) Preguntas sobre ingresos / "cómo manejar mi ingreso"
    if (q.contains('ingreso') ||
        q.contains('sueld') ||
        q.contains('pago') ||
        q.contains('manejar') && q.contains('plata')) {
      if (_monthIncome <= 0) {
        return
            'Aún no veo ingresos registrados este mes en Comfy.\n\n'
            'Como regla simple, cuando tengas tu ingreso puedes probar:\n'
            '• 50% para gastos fijos (alquiler, comida, movilidad)\n'
            '• 30% para metas y ahorro\n'
            '• 20% para gustitos y gastos libres\n\n'
            'La idea es que primero te pagas a ti (ahorro) y luego gastas 💚.';
      } else {
        final ahorroSugerido = (_monthIncome * 0.3);
        final gustitos = (_monthIncome * 0.2);
        return
            'Este mes has recibido aprox. S/ ${_monthIncome.toStringAsFixed(2)}.\n\n'
            'Una forma simple de manejarlo sería:\n'
            '• ~50% (S/ ${(0.5 * _monthIncome).toStringAsFixed(2)}) para gastos fijos\n'
            '• ~30% (S/ ${ahorroSugerido.toStringAsFixed(2)}) para metas y ahorro\n'
            '• ~20% (S/ ${gustitos.toStringAsFixed(2)}) para gustitos\n\n'
            'Si quieres, puedes empezar moviendo un % fijo (por ej. 10–15%) a tus metas cada vez que recibes dinero.';
      }
    }

    // 2) Preguntas sobre gastos hormiga
    if (q.contains('hormiga') ||
        q.contains('antojo') ||
        q.contains('snack') ||
        q.contains('delivery')) {
      if (_monthHormiga <= 0) {
        return
            'Por ahora no detecto gastos hormiga claros este mes 🧠\n\n'
            'Un truco: cada vez que registres un gasto pequeño, marca en la descripción si fue snack, café, bodeguita o delivery. Así te puedo decir con más precisión en qué se te va la plata.';
      } else {
        return
            'Este mes tienes aprox. S/ ${_monthHormiga.toStringAsFixed(2)} en gastos hormiga.\n'
            'Eso representa alrededor de ${hormigaPct.toStringAsFixed(1)}% de tus gastos.\n\n'
            'Idea para manejar mejor tus ingresos:\n'
            '• Pon un tope semanal para snacks/delivery.\n'
            '• Cada vez que te provoque un antojo, pregúntate: "¿Prefiero esto o avanzar mi meta?"\n'
            '• Lo que recortes de hormiga, muévelo directo a tus metas (aunque sea S/ 5–10).';
      }
    }

    // 3) Preguntas sobre metas / ahorro
    if (q.contains('meta') ||
        q.contains('ahorrar') ||
        q.contains('ahorro') ||
        q.contains('llegar a') && q.contains('meta')) {
      if (_monthIncome <= 0) {
        return
            'Para armar un plan de metas, primero necesito ver algo de movimiento en tu ingreso.\n\n'
            'Como guía, cuando empieces a registrar ingresos intenta:\n'
            '1) Definir 1–2 metas máximas (no 10 a la vez).\n'
            '2) Fijar un monto pequeño automático (ej. S/ 3–5 diarios).\n'
            '3) Cada vez que recibes plata, manda algo a tus metas antes de gastar.';
      } else {
        final ahorro30 = (_monthIncome * 0.3);
        return
            'Si quieres manejar mejor tus ingresos para llegar a tus metas, te propongo algo simple:\n\n'
            '• Apunta a ahorrar entre 20% y 30% de tus ingresos.\n'
            '  En tu caso sería aprox. S/ ${ahorro30.toStringAsFixed(2)} si apuntas al 30%.\n'
            '• Divide ese monto entre tus metas más importantes (máx. 2–3).\n'
            '• Cada vez que recibes dinero, manda primero el aporte a metas y recién luego gastas.\n\n'
            'Si me dices cuánto quieres ahorrar y en cuánto tiempo, te puedo sugerir un monto mensual aproximado 😉.';
      }
    }

    // 4) Preguntas generales tipo “cómo manejar mejor mi dinero”
    if (q.contains('manejar mejor') ||
        q.contains('organizar') && q.contains('dinero') ||
        q.contains('ordenar') && q.contains('finanzas') ||
        q.contains('consejo') && (q.contains('plata') || q.contains('ingreso'))) {
      return
          'Para manejar mejor tus ingresos te recomiendo 3 pasos comfy:\n\n'
          '1️⃣ Claridad\n'
          '   • Registra lo que entra y sale (ya lo haces con Comfy 👌).\n\n'
          '2️⃣ Prioridad\n'
          '   • Separa primero tus metas y ahorro (aunque sea poco) y luego tus gastos libres.\n\n'
          '3️⃣ Limites sanos\n'
          '   • Pon tope a categorías donde más se te va la plata (delivery, taxis, snacks).\n\n'
          'Con el tiempo, la idea es que tu yo-del-futuro reciba más (ahorro) que los antojos de hoy 🧠💚.';
    }

    // 5) Si preguntan por saldo o cómo usar lo que tienen ahorita
    if (q.contains('saldo') || q.contains('tengo') && q.contains('ahora')) {
      return
          'Tu saldo actual en Comfy está alrededor de S/ ${_currentBalance.toStringAsFixed(2)}.\n\n'
          'Una forma simple de usarlo mejor:\n'
          '• Guarda una parte en metas (ej. 20–30%).\n'
          '• Deja otra parte para gastos necesarios.\n'
          '• Y un pequeño porcentaje para gustitos sin culpa.\n\n'
          'Lo clave es que tus metas siempre reciban algo, aunque sea poquito 😉.';
    }

    // 6) Respuesta por defecto (fallback MVP)
    return
        'Buenísima tu pregunta 👌\n\n'
        'Soy un coach comfy MVP, así que de momento respondo mejor sobre:\n'
        '• Cómo distribuir tus ingresos\n'
        '• Cómo bajar gastos hormiga\n'
        '• Cómo armar y priorizar metas de ahorro\n\n'
        'Prueba preguntarme algo como:\n'
        '“¿Cómo distribuyo mis ingresos este mes?” o\n'
        '“¿Qué hago con mis gastos hormiga?”';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat con tu coach comfy'),
      ),
      body: Column(
        children: [
          if (_loadingContext)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              reverse: false,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.fromUser;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: theme.scaffoldBackgroundColor,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: const InputDecoration(
                        hintText: 'Pregúntame cómo manejar tu ingreso...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _handleSend,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool fromUser;
  final String text;

  _ChatMessage({
    required this.fromUser,
    required this.text,
  });
}
