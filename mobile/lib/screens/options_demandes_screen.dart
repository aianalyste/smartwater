import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/options_service.dart';

class OptionsDemandesScreen extends StatefulWidget {
  const OptionsDemandesScreen({super.key});

  @override
  State<OptionsDemandesScreen> createState() => _OptionsDemandesScreenState();
}

class _OptionsDemandesScreenState extends State<OptionsDemandesScreen> {
  late Future<List<dynamic>> _demandes;
  late Future<List<dynamic>> _parcelles;

  @override
  void initState() {
    super.initState();
    _rafraichir();
    _parcelles = OptionsService.getParcelles();
  }

  void _rafraichir() => setState(() => _demandes = OptionsService.getDemandesEnAttente());

  void _validerAvecChoix(Map<String, dynamic> demande) async {
    final parcelles = await _parcelles;
    if (!mounted) return;
    final parcelleId = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Choisir la parcelle'),
        children: parcelles.map<Widget>((p) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p['id']),
              child: Text('${p['nom']} — ${p['localisation']}'),
            )).toList(),
      ),
    );
    if (parcelleId != null) {
      await OptionsService.validerDemande(demande['id'], parcelleId);
      _rafraichir();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes de rattachement')),
      body: FutureBuilder<List<dynamic>>(
        future: _demandes,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final demandes = snapshot.data!;
          if (demandes.isEmpty) return const Center(child: Text('Aucune demande en attente.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: demandes.length,
            itemBuilder: (context, i) {
              final d = demandes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['nom_parcelle_indique'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(d['localisation_indiquee'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await OptionsService.refuserDemande(d['id']);
                                _rafraichir();
                              },
                              child: const Text('Refuser'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _validerAvecChoix(d),
                              child: const Text('Valider'),
                            ),
                          ),
                        ],
                      ),
                    ],
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