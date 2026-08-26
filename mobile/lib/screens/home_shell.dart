import 'package:flutter/material.dart';

import '../services/session_service.dart';
import 'dashboard_screen.dart';
import 'capteurs_screen.dart';
import 'controle_screen.dart';
import 'cultures_screen.dart';
import 'options_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indexActuel = 0;
  bool _peutGererOptions = false;

  @override
  void initState() {
    super.initState();
    SessionService.peutGererOptions().then((valeur) {
      if (mounted) setState(() => _peutGererOptions = valeur);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ecrans = [
      const DashboardScreen(),
      const CapteursScreen(),
      const ControleScreen(),
      const CulturesScreen(),
      if (_peutGererOptions) const OptionsScreen(),
    ];

    final items = [
      const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Tableau de b...'),
      const BottomNavigationBarItem(icon: Icon(Icons.sensors_outlined), label: 'Capteurs'),
      const BottomNavigationBarItem(icon: Icon(Icons.tune_outlined), label: 'Controle'),
      const BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: 'Cultures'),
      if (_peutGererOptions) const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Options'),
    ];

    if (_indexActuel >= ecrans.length) _indexActuel = 0;

    return Scaffold(
      body: ecrans[_indexActuel],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indexActuel,
        onTap: (i) => setState(() => _indexActuel = i),
        type: BottomNavigationBarType.fixed,
        items: items,
      ),
    );
  }
}