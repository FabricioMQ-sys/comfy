import 'package:flutter/material.dart';
import '../screens/coach/coach_chat_screen.dart';

class CoachChatBubble extends StatelessWidget {
  /// Puedes cambiar la posición con este alignment si quieres
  final Alignment alignment;

  const CoachChatBubble({
    super.key,
    this.alignment = Alignment.centerRight, // lateral derecho
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Align(
          alignment: alignment,
          child: Padding(
            // separarlo un poco del borde y de la bottom nav
            padding: const EdgeInsets.only(right: 16, bottom: 80),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CoachChatScreen(),
                  ),
                );
              },
              child: Material(
                elevation: 6,
                shape: const CircleBorder(),
                color: theme.colorScheme.primary,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.psychology_alt_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      // pequeño “puntito” para que se sienta vivo
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.lightGreenAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.lightGreenAccent.withOpacity(0.7),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
