import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final String entityType; // 'frota' ou 'veiculo' para guiar as tabs

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    this.entityType = 'frota',
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == currentIndex) return;
        switch (index) {
          case 0:
            Navigator.pushNamed(context, entityType == 'veiculo' ? '/dashboard-veiculo' : '/dashboard-adm-frota');
            break;
          case 1:
            Navigator.pushNamed(context, entityType == 'veiculo' ? '/alertas-veiculo' : '/alertas-frota');
            break;
          case 2:
            Navigator.pushNamed(context, entityType == 'veiculo' ? '/relatorios-veiculo' : '/relatorios-frota');
            break;
          case 3:
            Navigator.pushNamed(context, entityType == 'veiculo' ? '/historico-veiculo' : '/historico-frota');
            break;
          case 4:
            Navigator.pushNamed(context, '/gps');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alertas'),
        BottomNavigationBarItem(icon: Icon(Icons.insert_chart), label: 'Relatórios'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'GPS'),
      ],
    );
  }
}
