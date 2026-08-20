import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Ecran Controle : vannes par zone + arrosage manuel, comme dans
/// l'app de reference, avec en plus le "pourquoi" de la derniere
/// decision automatique (transparence de l'IA).
class ControleScreen extends StatefulWidget {
  const ControleScreen({super.key});

  @override
  State<ControleScreen> createState() => _ControleScreenState();
}

class _ControleScreenState extends State<ControleScreen> {
  late Future<List<dynamic>> _parcellesFuture;
  double _volumePct = 50;
  double _dureeMinutes = 20;

  @override
  void initState() {
    super.initState();
    _parcellesFuture = ApiService.getMesParcelles();
  }

  Future<void> _demarrer(int zoneId) async {
    try {
      await ApiService.demarrerIrrigationManuelle(zoneId, _dureeMinutes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Irrigation demarree.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du demarrage.')),
        );
      }
    }
  }

  Future<void> _arreter(int zoneId) async {
    try {
      await ApiService.arreterIrrigation(zoneId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Irrigation arretee.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'arret.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Controle d'irrigation")),
      body: FutureBuilder<List<dynamic>>(
        future: _parcellesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final parcelles = snapshot.data!;
          if (parcelles.isEmpty) return const Center(child: Text('Aucune parcelle.'));

          final zones = parcelles[0]['zones'] as List<dynamic>;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Vannes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              ...zones.map((zone) => _VanneTuile(
                    zone: zone,
                    onOuvrir: () => _demarrer(zone['id']),
                    onFermer: () => _arreter(zone['id']),
                  )),
              const SizedBox(height: 24),
              const Text('Arrosage manuel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              Text('Volume : ${_volumePct.toStringAsFixed(0)}%'),
              Slider(
                value: _volumePct,
                min: 10,
                max: 100,
                activeColor: AppColors.vertPrincipal,
                onChanged: (v) => setState(() => _volumePct = v),
              ),
              Text('Duree : ${_dureeMinutes.toStringAsFixed(0)} min'),
              Slider(
                value: _dureeMinutes,
                min: 5,
                max: 60,
                activeColor: AppColors.vertPrincipal,
                onChanged: (v) => setState(() => _dureeMinutes = v),
              ),
              const SizedBox(height: 12),
              if (zones.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _demarrer(zones[0]['id']),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Demarrer'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VanneTuile extends StatelessWidget {
  final dynamic zone;
  final VoidCallback onOuvrir;
  final VoidCallback onFermer;

  const _VanneTuile({required this.zone, required this.onOuvrir, required this.onFermer});

  @override
  Widget build(BuildContext context) {
    final ouverte = zone['vanne']?['etat'] == 'ouverte';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.water_drop_outlined),
        title: Text(zone['nom'] ?? ''),
        subtitle: Text(zone['culture']?['nom'] ?? ''),
        trailing: Switch(
          value: ouverte,
          activeColor: AppColors.vertPrincipal,
          onChanged: (v) => v ? onOuvrir() : onFermer(),
        ),
      ),
    );
  }
}
