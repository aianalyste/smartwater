import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'capteurs_screen.dart';
import 'controle_screen.dart';
import 'cultures_screen.dart';

/// Navigation principale a 4 onglets, reprenant la structure de
/// l'app existante (Tableau de bord / Capteurs / Controle / Cultures)
/// mais avec toutes les ameliorations qu'on a definies.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indexActuel = 0;

  final _ecrans = const [
    DashboardScreen(),
    CapteursScreen(),
    ControleScreen(),
    CulturesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _ecrans[_indexActuel],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indexActuel,
        onTap: (i) => setState(() => _indexActuel = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Tableau de b...'),
          BottomNavigationBarItem(icon: Icon(Icons.sensors_outlined), label: 'Capteurs'),
          BottomNavigationBarItem(icon: Icon(Icons.tune_outlined), label: 'Controle'),
          BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: 'Cultures'),
        ],
      ),
    );
  }
}
