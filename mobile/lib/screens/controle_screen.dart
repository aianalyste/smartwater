import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ControleScreen extends StatefulWidget {
  const ControleScreen({super.key});

  @override
  State<ControleScreen> createState() => _ControleScreenState();
}

class _ControleScreenState extends State<ControleScreen> {
  late Future<List<dynamic>> _parcellesFuture;
  double _volumeL = 45;
  double _dureeMinutes = 20;
  bool _valeursChargees = false;
  String? _messageStatut;

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  void _rafraichir() {
    setState(() {
      _parcellesFuture = ApiService.getMesParcelles();
    });
  }

  Future<void> _chargerPredictionIA(int zoneId) async {
    if (_valeursChargees) return;
    try {
      final decision = await ApiService.getDecision(zoneId);
      final volume = decision['volume_estime_l'];
      final duree = decision['duree_estimee_min'];
      if (mounted && volume != null && duree != null) {
        setState(() {
          _volumeL = (volume as num).toDouble().clamp(5, 300);
          _dureeMinutes = (duree as num).toDouble().clamp(5, 90);
          _valeursChargees = true;
        });
      }
    } catch (e) {
      // Pas de prediction disponible -- on garde les valeurs par defaut
    }
  }

  Future<void> _demarrer(int zoneId, String nomZone) async {
    try {
      await ApiService.demarrerIrrigationManuelle(zoneId, _dureeMinutes);
      setState(() {
        _messageStatut = 'Irrigation demarree sur $nomZone : ${_volumeL.toStringAsFixed(0)}L pendant ${_dureeMinutes.toStringAsFixed(0)} min';
      });
      _rafraichir();
    } catch (e) {
      setState(() => _messageStatut = 'Erreur lors du demarrage.');
    }
  }

  Future<void> _arreter(int zoneId, String nomZone) async {
    try {
      await ApiService.arreterIrrigation(zoneId);
      setState(() => _messageStatut = 'Irrigation arretee sur $nomZone.');
      _rafraichir();
    } catch (e) {
      setState(() => _messageStatut = 'Erreur lors de l\'arret.');
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
          if (parcelles.isEmpty) {
            return const Center(child: Text('Aucune parcelle.'));
          }

          final zones = parcelles[0]['zones'] as List<dynamic>;
          if (zones.isNotEmpty) {
            _chargerPredictionIA(zones[0]['id']);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_messageStatut != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.vertPrincipal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.vertPrincipal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_messageStatut!, style: const TextStyle(fontSize: 13, color: AppColors.vertFonce))),
                    ],
                  ),
                ),

              const Text('Vannes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 10),
              ...zones.map((zone) => _VanneCard(
                    zone: zone,
                    onOuvrir: () => _demarrer(zone['id'], zone['nom']),
                    onFermer: () => _arreter(zone['id'], zone['nom']),
                  )),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Arrosage manuel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    if (_valeursChargees)
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 14, color: AppColors.vertPrincipal),
                          const SizedBox(width: 4),
                          Text('Valeurs predites par l\'IA', style: TextStyle(fontSize: 11, color: AppColors.vertPrincipal, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Volume', style: TextStyle(fontSize: 13, color: AppColors.texteSecondaire)),
                        Text('${_volumeL.toStringAsFixed(0)} L', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.vertPrincipal)),
                      ],
                    ),
                    Slider(
                      value: _volumeL,
                      min: 5,
                      max: 300,
                      divisions: 59,
                      activeColor: AppColors.vertPrincipal,
                      label: '${_volumeL.toStringAsFixed(0)} L',
                      onChanged: (v) => setState(() => _volumeL = v),
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Duree', style: TextStyle(fontSize: 13, color: AppColors.texteSecondaire)),
                        Text('${_dureeMinutes.toStringAsFixed(0)} min', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.vertPrincipal)),
                      ],
                    ),
                    Slider(
                      value: _dureeMinutes,
                      min: 5,
                      max: 90,
                      divisions: 17,
                      activeColor: AppColors.vertPrincipal,
                      label: '${_dureeMinutes.toStringAsFixed(0)} min',
                      onChanged: (v) => setState(() => _dureeMinutes = v),
                    ),

                    const SizedBox(height: 16),
                    if (zones.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _demarrer(zones[0]['id'], zones[0]['nom']),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Demarrer'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VanneCard extends StatelessWidget {
  final dynamic zone;
  final VoidCallback onOuvrir;
  final VoidCallback onFermer;

  const _VanneCard({required this.zone, required this.onOuvrir, required this.onFermer});

  @override
  Widget build(BuildContext context) {
    final ouverte = zone['vanne']?['etat'] == 'ouverte';
    final couleur = ouverte ? AppColors.vertPrincipal : AppColors.texteSecondaire;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: couleur.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(ouverte ? Icons.water_drop : Icons.water_drop_outlined, color: couleur, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(zone['culture']?['nom'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.texteSecondaire)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(20)),
            child: Text(ouverte ? 'Ouverte' : 'Fermee', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Switch(
            value: ouverte,
            activeColor: AppColors.vertPrincipal,
            onChanged: (v) => v ? onOuvrir() : onFermer(),
          ),
        ],
      ),
    );
  }
}