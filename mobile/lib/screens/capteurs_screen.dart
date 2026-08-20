import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Ecran Capteurs : graphique d'humidite (comme l'app de reference),
/// avec moyenne/max/min, plus temperature.
///
/// NOTE : cet ecran suppose qu'une zone est deja selectionnee.
/// A AMELIORER : ajouter un selecteur de zone en haut de l'ecran si
/// l'utilisateur a plusieurs parcelles/zones (voir TODO plus bas).
class CapteursScreen extends StatefulWidget {
  const CapteursScreen({super.key});

  @override
  State<CapteursScreen> createState() => _CapteursScreenState();
}

class _CapteursScreenState extends State<CapteursScreen> {
  // TODO: remplacer par la vraie zone selectionnee par l'utilisateur
  // (ex: via un Provider partage entre les ecrans, ou un selecteur
  // en haut de cet ecran si plusieurs zones existent).
  int? _zoneId;
  Future<Map<String, dynamic>>? _historiqueFuture;

  @override
  void initState() {
    super.initState();
    _chargerPremiereZone();
  }

  Future<void> _chargerPremiereZone() async {
    final parcelles = await ApiService.getMesParcelles();
    if (parcelles.isNotEmpty) {
      final zones = parcelles[0]['zones'] as List<dynamic>;
      if (zones.isNotEmpty) {
        setState(() {
          _zoneId = zones[0]['id'];
          _historiqueFuture = ApiService.getHistoriqueCapteur(_zoneId!, jours: 7);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Humidite du sol')),
      body: _historiqueFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, dynamic>>(
              future: _historiqueFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final stats = snapshot.data!['statistiques'] as Map<String, dynamic>;
                final lectures = snapshot.data!['lectures'] as List<dynamic>;

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Text('Humidite actuelle', style: TextStyle(color: AppColors.texteSecondaire)),
                            Text(
                              lectures.isNotEmpty ? '${lectures.last['humidite_pct'].toStringAsFixed(0)}%' : '—',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.vertPrincipal),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: lectures.isEmpty
                            ? const Center(child: Text('Pas encore de donnees'))
                            : LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: false),
                                  titlesData: const FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: [
                                        for (int i = 0; i < lectures.length; i++)
                                          FlSpot(i.toDouble(), (lectures[i]['humidite_pct'] as num).toDouble())
                                      ],
                                      isCurved: true,
                                      color: AppColors.vertPrincipal,
                                      barWidth: 3,
                                      dotData: const FlDotData(show: false),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColonne(label: 'Moyenne', valeur: stats['moyenne']),
                          _StatColonne(label: 'Max', valeur: stats['max']),
                          _StatColonne(label: 'Min', valeur: stats['min']),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _StatColonne extends StatelessWidget {
  final String label;
  final dynamic valeur;
  const _StatColonne({required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 12)),
        Text(
          valeur != null ? '${(valeur as num).toStringAsFixed(0)}%' : '—',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }
}
