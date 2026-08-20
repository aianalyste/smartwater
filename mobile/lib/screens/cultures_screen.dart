import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Ecran Cultures : type de culture + phase phenologique (comme dans
/// l'app de reference), avec en plus le rapport d'economie d'eau
/// chiffre qu'on a ajoute.
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
            padding: const EdgeInsets.all(20),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zone['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Culture : ${zone['culture']?['nom'] ?? '-'}'),
            Text('Stade phenologique : $phase'),
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bleuClairFond,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.water_drop_outlined, size: 16, color: AppColors.vertFonce),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "L'IA ajuste l'arrosage automatiquement selon la meteo et le stade de la culture.",
                      style: TextStyle(fontSize: 12, color: AppColors.vertFonce),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RapportEauWidget(zoneId: zone['id']),
          ],
        ),
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
        return Row(
          children: [
            const Icon(Icons.eco, size: 18, color: AppColors.vertPrincipal),
            const SizedBox(width: 6),
            Text(
              '${pct?.toStringAsFixed(0) ?? '—'}% d\'eau economisee ce mois-ci',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ],
        );
      },
    );
  }
}
