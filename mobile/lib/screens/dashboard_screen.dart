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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${zone['nom']} — ${zone['culture']?['nom'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          Text('Phase : $phase', style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
          const SizedBox(height: 14),

          const Text('Etat des capteurs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (capteurs.isEmpty)
            _cartePasDeDonnees()
          else
            ...capteurs.map((c) {
              final etat = c['etat'] ?? 'aucune_donnee';
              final couleur = _couleurEtat(etat);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      c['type_capteur'] == 'humidite_temperature' ? Icons.water_drop_outlined : Icons.sensors,
                      size: 16, color: couleur,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c['type_capteur'] == 'humidite_temperature' ? 'Humidite / Temperature' : 'Capteur spectral',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(20)),
                      child: Text(_libelleEtat(etat), style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 16),
          const Text('Conditions actuelles', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (capteurs.isEmpty)
            _cartePasDeDonnees()
          else
            Row(
              children: [
                Expanded(
                  child: _carteValeur(
                    icone: Icons.water_drop,
                    couleur: AppColors.bleuEau,
                    label: 'Humidite',
                    valeur: capteurs[0]['derniere_humidite_pct'] != null
                        ? '${capteurs[0]['derniere_humidite_pct'].toStringAsFixed(0)}%'
                        : '—',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _carteValeur(
                    icone: Icons.thermostat,
                    couleur: AppColors.alerte,
                    label: 'Temperature',
                    valeur: capteurs[0]['derniere_temperature_c'] != null
                        ? '${capteurs[0]['derniere_temperature_c'].toStringAsFixed(0)}°C'
                        : '—',
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),
          _BlocDecision(zoneId: zone['id']),
        ],
      ),
    );
  }

  Widget _carteValeur({required IconData icone, required Color couleur, required String label, required String valeur}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icone, color: couleur, size: 22),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.texteSecondaire)),
          const SizedBox(height: 2),
          Text(valeur, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: couleur)),
        ],
      ),
    );
  }

  Widget _cartePasDeDonnees() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: const Text('Pas de donnees capteurs', style: TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
    );
  }
}

class _BlocDecision extends StatefulWidget {
  final int zoneId;
  const _BlocDecision({required this.zoneId});

  @override
  State<_BlocDecision> createState() => _BlocDecisionState();
}

class _BlocDecisionState extends State<_BlocDecision> {
  late Future<Map<String, dynamic>> _decisionFuture;

  @override
  void initState() {
    super.initState();
    _decisionFuture = ApiService.getDecision(widget.zoneId);
  }

  Color _couleurDecision(String decision) {
    switch (decision) {
      case 'oui': return AppColors.bleuEau;
      case 'non': return AppColors.vertPrincipal;
      default: return AppColors.texteSecondaire;
    }
  }

  String _libelleDecision(String decision) {
    switch (decision) {
      case 'oui': return 'ARROSER';
      case 'non': return 'PAS BESOIN';
      default: return 'INDISPONIBLE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _decisionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final data = snapshot.data!;
        final decision = data['decision'] ?? 'indisponible';
        final couleur = _couleurDecision(decision);
        final meteo14j = data['meteo_14j'] as List<dynamic>? ?? [];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: couleur.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: couleur.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Decision', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(20)),
                    child: Text(_libelleDecision(decision),
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data['phase'] != null)
                Text(
                  'Phase : ${data['phase']} — besoin en eau : ${data['etc_mm']?.toStringAsFixed(1) ?? '—'}mm/jour',
                  style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire),
                ),
              const SizedBox(height: 4),
              Text(data['explication'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
              const SizedBox(height: 12),
              const Text('Meteo (14 prochains jours)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: meteo14j.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final jour = meteo14j[i];
                    final pluie = (jour['pluie_mm'] as num?)?.toDouble() ?? 0;
                    final date = DateTime.tryParse(jour['date'] ?? '');
                    return Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(date != null ? '${date.day}/${date.month}' : '', style: const TextStyle(fontSize: 9, color: AppColors.texteSecondaire)),
                          const SizedBox(height: 2),
                          Icon(pluie > 1 ? Icons.cloud : Icons.wb_sunny_outlined, size: 16, color: pluie > 1 ? AppColors.bleuEau : AppColors.alerte),
                          const SizedBox(height: 2),
                          Text('${pluie.toStringAsFixed(0)}mm', style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}