import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'demande_rattachement_screen.dart';

/// Ecran Tableau de bord : humidite, temperature, statut de chaque
/// zone, comme dans l'app de reference mais avec le statut par zone
/// (multi-zones) et un indicateur de la decision du jour.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<dynamic>> _parcellesFuture;

  @override
  void initState() {
    super.initState();
    _parcellesFuture = ApiService.getMesParcelles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: FutureBuilder<List<dynamic>>(
        future: _parcellesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final parcelles = snapshot.data ?? [];
          if (parcelles.isEmpty) {
            // Cas important : l'utilisateur n'a aucune parcelle liee
            // (voir logique validee ensemble : il peut demander lui-meme
            // un rattachement).
            return const _AucuneParcelleVue();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: parcelles.length,
            itemBuilder: (context, i) => _ParcelleCard(parcelle: parcelles[i]),
          );
        },
      ),
    );
  }
}

class _AucuneParcelleVue extends StatelessWidget {
  const _AucuneParcelleVue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 56, color: AppColors.texteSecondaire),
            const SizedBox(height: 16),
            const Text(
              'Aucune parcelle associee a votre compte',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DemandeRattachementScreen()),
              ),
              child: const Text('Demander l\'acces a une parcelle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcelleCard extends StatelessWidget {
  final dynamic parcelle;
  const _ParcelleCard({required this.parcelle});

  @override
  Widget build(BuildContext context) {
    final zones = parcelle['zones'] as List<dynamic>? ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${parcelle['nom']} — ${parcelle['localisation']}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...zones.map((z) => _ZoneTuile(zone: z)),
          ],
        ),
      ),
    );
  }
}

class _ZoneTuile extends StatelessWidget {
  final dynamic zone;
  const _ZoneTuile({required this.zone});

  String _libelleEtat(String etat) {
    switch (etat) {
      case 'normal': return 'Normal';
      case 'maintenance': return 'Maintenance';
      case 'defaillant': return 'Defaillant';
      default: return 'Pas de donnees';
    }
  }

  Color _couleurEtat(String etat) {
    switch (etat) {
      case 'normal': return AppColors.vertPrincipal;
      case 'maintenance': return AppColors.alerte;
      case 'defaillant': return AppColors.danger;
      default: return AppColors.texteSecondaire;
    }
  }

  @override
  Widget build(BuildContext context) {
    final capteurs = zone['capteurs'] as List<dynamic>? ?? [];
    final phase = zone['phase_actuelle']?['phase'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bleuClairFond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${zone['nom']} — ${zone['culture']?['nom'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Text('Phase : $phase', style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
          const SizedBox(height: 10),

          const Text('Etat des capteurs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (capteurs.isEmpty)
            const Text('Pas de donnees capteurs', style: TextStyle(fontSize: 12, color: AppColors.texteSecondaire))
          else
            ...capteurs.map((c) {
              final etat = c['etat'] ?? 'aucune_donnee';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _couleurEtat(etat), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(c['type_capteur'] == 'humidite_temperature' ? 'Capteur humidite/temperature' : 'Capteur spectral',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text(_libelleEtat(etat), style: TextStyle(fontSize: 12, color: _couleurEtat(etat), fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }),

          const SizedBox(height: 10),
          const Text('Condition actuelle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (capteurs.isEmpty)
            const Text('Pas de donnees capteurs', style: TextStyle(fontSize: 12, color: AppColors.texteSecondaire))
          else
            Row(
              children: [
                Text(
                  capteurs[0]['derniere_humidite_pct'] != null
                      ? 'Humidite : ${capteurs[0]['derniere_humidite_pct'].toStringAsFixed(0)}%'
                      : 'Humidite : —',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Text(
                  capteurs[0]['derniere_temperature_c'] != null
                      ? 'Temperature : ${capteurs[0]['derniere_temperature_c'].toStringAsFixed(0)}°C'
                      : 'Temperature : —',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
        ],
      ),
    );
  }
}