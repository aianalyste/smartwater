import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

class CulturesScreen extends StatefulWidget {
  const CulturesScreen({super.key});

  @override
  State<CulturesScreen> createState() => _CulturesScreenState();
}

class _CulturesScreenState extends State<CulturesScreen> {
  late Future<List<dynamic>> _parcellesFuture;

  @override
  void initState() {
    super.initState();
    _parcellesFuture = ApiService.getMesParcelles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cultures')),
      body: FutureBuilder<List<dynamic>>(
        future: _parcellesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final parcelles = snapshot.data!;
          if (parcelles.isEmpty) return const Center(child: Text('Aucune parcelle.'));

          final zones = parcelles[0]['zones'] as List<dynamic>;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: zones.length,
            itemBuilder: (context, i) => _CultureCard(zone: zones[i]),
          );
        },
      ),
    );
  }
}

class _CultureCard extends StatelessWidget {
  final dynamic zone;
  const _CultureCard({required this.zone});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.vertPrincipal.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.eco, color: AppColors.vertPrincipal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(zone['culture']?['nom'] ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.vertClair, borderRadius: BorderRadius.circular(20)),
                child: Text(phase, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bleuClairFond,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.vertFonce),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "L'IA ajuste l'arrosage automatiquement selon la meteo et le stade de la culture.",
                    style: TextStyle(fontSize: 12, color: AppColors.vertFonce, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _RapportEauWidget(zoneId: zone['id']),
          const SizedBox(height: 8),
          _MeteoWidget(zoneId: zone['id']),
        ],
      ),
    );
  }
}

class _RapportEauWidget extends StatefulWidget {
  final int zoneId;
  const _RapportEauWidget({required this.zoneId});

  @override
  State<_RapportEauWidget> createState() => _RapportEauWidgetState();
}

class _RapportEauWidgetState extends State<_RapportEauWidget> {
  late Future<Map<String, dynamic>> _rapportFuture;

  @override
  void initState() {
    super.initState();
    _rapportFuture = ApiService.getRapportEconomieEau(widget.zoneId, jours: 30);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _rapportFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final pct = snapshot.data!['pourcentage_economise'];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.vertPrincipal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppColors.vertPrincipal, shape: BoxShape.circle),
                child: const Icon(Icons.eco, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${pct?.toStringAsFixed(0) ?? '—'}% d\'eau economisee ce mois-ci',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.vertFonce),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MeteoWidget extends StatefulWidget {
  final int zoneId;
  const _MeteoWidget({required this.zoneId});

  @override
  State<_MeteoWidget> createState() => _MeteoWidgetState();
}

class _MeteoWidgetState extends State<_MeteoWidget> {
  late Future<Map<String, dynamic>> _meteoFuture;

  @override
  void initState() {
    super.initState();
    _meteoFuture = ApiService.getMeteo(widget.zoneId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _meteoFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final pluiePrevue = snapshot.data!['pluie_prevue'] == true;
        final volume = snapshot.data!['volume_mm'];
        final couleur = pluiePrevue ? AppColors.bleuEau : AppColors.alerte;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: couleur.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
                child: Icon(pluiePrevue ? Icons.cloud : Icons.wb_sunny_outlined, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pluiePrevue
                      ? 'Pluie prevue (${volume?.toStringAsFixed(0) ?? '?'}mm) - irrigation ajustee'
                      : 'Pas de pluie prevue prochainement',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: couleur),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}