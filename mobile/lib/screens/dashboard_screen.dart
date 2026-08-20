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

  @override
  Widget build(BuildContext context) {
    final capteurs = zone['capteurs'] as List<dynamic>? ?? [];
    final humidite = capteurs.isNotEmpty ? capteurs[0]['derniere_humidite_pct'] : null;
    final temperature = capteurs.isNotEmpty ? capteurs[0]['derniere_temperature_c'] : null;
    final vanneEtat = zone['vanne']?['etat'] ?? 'inconnu';
    final phase = zone['phase_actuelle']?['phase'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bleuClairFond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${zone['nom']} — ${zone['culture']?['nom'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('Phase : $phase', style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                humidite != null ? '${humidite.toStringAsFixed(0)}%' : '—',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.vertFonce),
              ),
              Text(
                temperature != null ? '${temperature.toStringAsFixed(0)}°C' : '—',
                style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            vanneEtat == 'ouverte' ? Icons.water_drop : Icons.water_drop_outlined,
            color: vanneEtat == 'ouverte' ? AppColors.bleuEau : AppColors.texteSecondaire,
          ),
        ],
      ),
    );
  }
}
