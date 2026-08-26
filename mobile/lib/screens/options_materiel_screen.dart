import 'package:flutter/material.dart';

import '../services/options_service.dart';

class OptionsMaterielScreen extends StatelessWidget {
  const OptionsMaterielScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Materiel'),
          bottom: const TabBar(tabs: [Tab(text: 'Devices'), Tab(text: 'Capteurs'), Tab(text: 'Vannes')]),
        ),
        body: TabBarView(
          children: [
            _ListeGenerique(future: OptionsService.getDevices(), champTitre: 'identifiant', champSous: 'mode_connexion'),
            _ListeGenerique(future: OptionsService.getCapteurs(), champTitre: 'type_capteur', champSous: 'derniere_humidite_pct'),
            _ListeGenerique(future: OptionsService.getVannes(), champTitre: 'etat', champSous: 'debit_theorique_l_min'),
          ],
        ),
      ),
    );
  }
}

class _ListeGenerique extends StatelessWidget {
  final Future<List<dynamic>> future;
  final String champTitre;
  final String champSous;
  const _ListeGenerique({required this.future, required this.champTitre, required this.champSous});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('Aucun element.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${item[champTitre]}'),
                subtitle: Text('${item[champSous]}'),
              ),
            );
          },
        );
      },
    );
  }
}