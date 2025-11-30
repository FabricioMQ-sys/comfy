import 'package:flutter/material.dart';

class ComfyBottomNav extends StatelessWidget {
  final int currentIndex;

  const ComfyBottomNav({
    super.key,
    required this.currentIndex,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/goals');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/earn');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/history');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? colorScheme.surface.withOpacity(0.98)
        : Colors.white;

    final boxShadow = isDark
        ? <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ];

    final selectedColor = colorScheme.primary;
    final unselectedColor = isDark ? Colors.grey[400] : Colors.grey[500];

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: boxShadow,
        border: isDark
            ? Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.06),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Theme(
            // Forzamos fondo transparente dentro del BottomNavigationBar
            data: theme.copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (i) => _onTap(context, i),
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: selectedColor,
              unselectedItemColor: unselectedColor,
              selectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(
                    currentIndex == 0
                        ? Icons.home_rounded
                        : Icons.home_outlined,
                  ),
                  label: 'Inicio',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    currentIndex == 1
                        ? Icons.flag_rounded
                        : Icons.flag_outlined,
                  ),
                  label: 'Metas',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentIndex == 2
                          ? selectedColor.withOpacity(0.16)
                          : Colors.transparent,
                    ),
                    child: Icon(
                      currentIndex == 2
                          ? Icons.add_chart_rounded
                          : Icons.add_chart_outlined,
                    ),
                  ),
                  label: 'Ganar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    currentIndex == 3
                        ? Icons.receipt_long_rounded
                        : Icons.receipt_long_outlined,
                  ),
                  label: 'Historial',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    currentIndex == 4
                        ? Icons.person_rounded
                        : Icons.person_outline,
                  ),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
