import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'demande_rattachement_screen.dart';
import 'dart:async';
import '../services/session_service.dart';
import 'inscription_screen.dart';
import 'package:fl_chart/fl_chart.dart';

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
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        backgroundColor: AppColors.fondClair,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Deconnexion',
            onPressed: () async {
              await SessionService.deconnecter();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const InscriptionScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.vertClair.withOpacity(0.15),
                  AppColors.vertPrincipal.withOpacity(0.05),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                9,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.eco,
                    size: 12,
                    color: AppColors.vertPrincipal.withOpacity(0.35),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
            return const _AucuneParcelleVue();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _BandeauAlertes(),
              ...parcelles.map<Widget>((p) => _ParcelleCard(parcelle: p)),
            ],
          );
        },
      ),
    );
  }
}

class _BandeauAlertes extends StatefulWidget {
  const _BandeauAlertes();

  @override
  State<_BandeauAlertes> createState() => _BandeauAlertesState();
}

class _BandeauAlertesState extends State<_BandeauAlertes> {
  late Future<List<dynamic>> _alertesFuture;

  @override
  void initState() {
    super.initState();
    _alertesFuture = ApiService.getAlertes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _alertesFuture,
      builder: (context, snapshot) {
        final alertes = snapshot.data ?? [];
        if (alertes.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Text('${alertes.length} alerte(s)', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                ],
              ),
              const SizedBox(height: 8),
              ...alertes.take(3).map((a) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• ${a['message']}', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  )),
            ],
          ),
        );
      },
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
          _CourbeComparaison(zoneId: zone['id']),
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
  Timer? _timer;
  Duration? _tempsRestant;
  int? _delaiTotalSecondes;

  @override
  void initState() {
    super.initState();
    _decisionFuture = ApiService.getDecision(widget.zoneId).then((data) {
      _demarrerDecompte(data);
      return data;
    });
  }

  void _demarrerDecompte(Map<String, dynamic> data) {
    final dateDecisionStr = data['date_decision'];
    final delaiSecondes = data['delai_auto_secondes'];
    if (dateDecisionStr == null || delaiSecondes == null) return;

    _delaiTotalSecondes = delaiSecondes;
    final dateDecision = DateTime.parse(dateDecisionStr).toLocal();
    final dateLimite = dateDecision.add(Duration(seconds: delaiSecondes));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final restant = dateLimite.difference(DateTime.now());
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _tempsRestant = restant.isNegative ? Duration.zero : restant);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  String _formatDuree(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secondes = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secondes';
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: couleur.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: couleur.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DECISION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(
                _libelleDecision(decision),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: couleur, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),

              if (data['phase'] != null)
                Text(
                  'Phase : ${data['phase']} — besoin en eau : ${data['etc_mm']?.toStringAsFixed(1) ?? '—'}mm/jour',
                  style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire),
                ),
              const SizedBox(height: 4),
              Text(
                data['explication'] ?? '',
                style: const TextStyle(fontSize: 14, color: AppColors.texteSecondaire, fontWeight: FontWeight.w500, height: 1.4),
              ),
              if (_tempsRestant != null && _delaiTotalSecondes != null) ...[
                const SizedBox(height: 18),
                Center(
                  child: _CercleDecompte(
                    tempsRestant: _tempsRestant!,
                    delaiTotalSecondes: _delaiTotalSecondes!,
                    couleur: couleur,
                    formatDuree: _formatDuree,
                  ),
                ),
              ],

              const SizedBox(height: 16),
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
              if ((data['prediction_humidite'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                const Text('Prediction humidite (5 jours)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: (data['prediction_humidite'] as List).map<Widget>((p) {
                    return Expanded(
                      child: Column(
                        children: [
                          Text('J+${p['jour']}', style: const TextStyle(fontSize: 10, color: AppColors.texteSecondaire)),
                          const SizedBox(height: 4),
                          Text('${p['humidite_projetee_pct']}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CercleDecompte extends StatelessWidget {
  final Duration tempsRestant;
  final int delaiTotalSecondes;
  final Color couleur;
  final String Function(Duration) formatDuree;

  const _CercleDecompte({
    required this.tempsRestant,
    required this.delaiTotalSecondes,
    required this.couleur,
    required this.formatDuree,
  });

  @override
  Widget build(BuildContext context) {
    final termine = tempsRestant == Duration.zero;
    final progres = delaiTotalSecondes > 0
        ? (tempsRestant.inSeconds / delaiTotalSecondes).clamp(0.0, 1.0)
        : 0.0;
    final couleurAffichee = termine ? AppColors.danger : couleur;

    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progres,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(couleurAffichee),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatDuree(tempsRestant),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: couleurAffichee),
                  ),
                  Text(
                    termine ? 'declenchement...' : 'avant auto',
                    style: TextStyle(fontSize: 10, color: couleurAffichee),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourbeComparaison extends StatefulWidget {
  final int zoneId;
  const _CourbeComparaison({required this.zoneId});

  @override
  State<_CourbeComparaison> createState() => _CourbeComparaisonState();
}

class _CourbeComparaisonState extends State<_CourbeComparaison> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getComparaisonDecisions(widget.zoneId, jours: 14);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        final donnees = snapshot.data!;

        final maxSysteme = donnees.map((d) => (d['volume_systeme_l'] as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b);
        final maxClassique = donnees.map((d) => (d['volume_classique_l'] as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b);
        final maxY = (maxSysteme > maxClassique ? maxSysteme : maxClassique) * 1.2 + 1;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SmartWater vs Arrosage classique', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text('Volume d\'eau utilise par jour (litres)', style: TextStyle(fontSize: 11, color: AppColors.texteSecondaire)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _legende('Systeme intelligent', AppColors.vertPrincipal),
                  const SizedBox(width: 16),
                  _legende('Arrosage classique', Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: maxY / 4 == 0 ? 1 : maxY / 4,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 9, color: AppColors.texteSecondaire),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: (donnees.length / 4).ceilToDouble().clamp(1, double.infinity),
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= donnees.length) return const SizedBox.shrink();
                            final date = DateTime.tryParse(donnees[i]['date'] ?? '');
                            if (date == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${date.day}/${date.month}', style: const TextStyle(fontSize: 9, color: AppColors.texteSecondaire)),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (int i = 0; i < donnees.length; i++)
                            FlSpot(i.toDouble(), (donnees[i]['volume_classique_l'] as num).toDouble()),
                        ],
                        isCurved: false,
                        color: Colors.grey.shade400,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: [
                          for (int i = 0; i < donnees.length; i++)
                            FlSpot(i.toDouble(), (donnees[i]['volume_systeme_l'] as num).toDouble()),
                        ],
                        isCurved: false,
                        color: AppColors.vertPrincipal,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legende(String texte, Color couleur) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, color: couleur),
        const SizedBox(width: 4),
        Text(texte, style: const TextStyle(fontSize: 11, color: AppColors.texteSecondaire)),
      ],
    );
  }
}