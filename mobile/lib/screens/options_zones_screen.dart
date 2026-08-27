import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/options_service.dart';

class OptionsZonesScreen extends StatefulWidget {
  const OptionsZonesScreen({super.key});

  @override
  State<OptionsZonesScreen> createState() => _OptionsZonesScreenState();
}

class _OptionsZonesScreenState extends State<OptionsZonesScreen> {
  late Future<List<dynamic>> _future;
  late Future<List<dynamic>> _cultures;
  late Future<List<dynamic>> _parcelles;

  @override
  void initState() {
    super.initState();
    _rafraichir();
    _cultures = OptionsService.getCultures();
    _parcelles = OptionsService.getParcelles();
  }

  void _rafraichir() => setState(() => _future = OptionsService.getZones());

  void _ouvrirFormulaire({Map<String, dynamic>? zone}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaireZone(zone: zone, cultures: _cultures, parcelles: _parcelles, onSauvegarde: _rafraichir),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zones')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.vertPrincipal,
        onPressed: () => _ouvrirFormulaire(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final zones = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: zones.length,
            itemBuilder: (context, i) {
              final z = zones[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${z['nom']} (${z['code_terrain']})'),
                  subtitle: Text('Semis : ${z['date_semis']}'),
                  trailing: IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _ouvrirFormulaire(zone: z)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FormulaireZone extends StatefulWidget {
  final Map<String, dynamic>? zone;
  final Future<List<dynamic>> cultures;
  final Future<List<dynamic>> parcelles;
  final VoidCallback onSauvegarde;
  const _FormulaireZone({this.zone, required this.cultures, required this.parcelles, required this.onSauvegarde});

  @override
  State<_FormulaireZone> createState() => _FormulaireZoneState();
}

class _FormulaireZoneState extends State<_FormulaireZone> {
  late final TextEditingController _nom;
  late final TextEditingController _codeTerrain;
  late final TextEditingController _dateSemis;
  late final TextEditingController _superficie;
  int? _cultureId;
  int? _parcelleId;

  @override
  void initState() {
    super.initState();
    final z = widget.zone;
    _nom = TextEditingController(text: z?['nom'] ?? '');
    _codeTerrain = TextEditingController(text: z?['code_terrain'] ?? '');
    _dateSemis = TextEditingController(text: z?['date_semis'] ?? '');
    _superficie = TextEditingController(text: z?['superficie_m2']?.toString() ?? '');
    _cultureId = z?['culture'];
    _parcelleId = z?['parcelle'];
  }

  Future<void> _sauvegarder() async {
    if (_cultureId == null || _parcelleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis une culture et une parcelle.')));
      return;
    }
    try {
      final donnees = {
        'nom': _nom.text,
        'code_terrain': _codeTerrain.text,
        'culture': _cultureId,
        'parcelle': _parcelleId,
        'date_semis': _dateSemis.text,
        if (_superficie.text.isNotEmpty) 'superficie_m2': double.tryParse(_superficie.text),
      };
      if (widget.zone != null) {
        await OptionsService.modifierZone(widget.zone!['id'], donnees);
      } else {
        await OptionsService.creerZone(donnees);
      }
      widget.onSauvegarde();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zone enregistree.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      _dateSemis.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.zone != null ? 'Modifier la zone' : 'Nouvelle zone', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom (ex: Zone 1)')),
            const SizedBox(height: 8),
            TextField(controller: _codeTerrain, decoration: const InputDecoration(labelText: 'Code terrain (ex: Z1)')),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: widget.parcelles,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<int>(
                  value: _parcelleId,
                  decoration: const InputDecoration(labelText: 'Parcelle'),
                  items: snapshot.data!.map<DropdownMenuItem<int>>((p) {
                    return DropdownMenuItem<int>(value: p['id'], child: Text(p['nom']));
                  }).toList(),
                  onChanged: (v) => setState(() => _parcelleId = v),
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: widget.cultures,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<int>(
                  value: _cultureId,
                  decoration: const InputDecoration(labelText: 'Culture'),
                  items: snapshot.data!.map<DropdownMenuItem<int>>((c) {
                    return DropdownMenuItem<int>(value: c['id'], child: Text(c['nom']));
                  }).toList(),
                  onChanged: (v) => setState(() => _cultureId = v),
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dateSemis,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Date de semis', suffixIcon: Icon(Icons.calendar_today, size: 18)),
              onTap: _choisirDate,
            ),
            const SizedBox(height: 8),
            TextField(controller: _superficie, decoration: const InputDecoration(labelText: 'Superficie m2 (optionnel)'), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _sauvegarder, child: const Text('Enregistrer'))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}