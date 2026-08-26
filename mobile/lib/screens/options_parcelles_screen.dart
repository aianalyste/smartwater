import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/options_service.dart';

class OptionsParcellesScreen extends StatefulWidget {
  const OptionsParcellesScreen({super.key});

  @override
  State<OptionsParcellesScreen> createState() => _OptionsParcellesScreenState();
}

class _OptionsParcellesScreenState extends State<OptionsParcellesScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  void _rafraichir() => setState(() => _future = OptionsService.getParcelles());

  void _ouvrirFormulaire({Map<String, dynamic>? parcelle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaireParcelle(parcelle: parcelle, onSauvegarde: _rafraichir),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parcelles')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.vertPrincipal,
        onPressed: () => _ouvrirFormulaire(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final parcelles = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: parcelles.length,
            itemBuilder: (context, i) {
              final p = parcelles[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(p['nom']),
                  subtitle: Text(p['localisation'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _ouvrirFormulaire(parcelle: p)),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: AppColors.danger),
                        onPressed: () async {
                          await OptionsService.supprimerParcelle(p['id']);
                          _rafraichir();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FormulaireParcelle extends StatefulWidget {
  final Map<String, dynamic>? parcelle;
  final VoidCallback onSauvegarde;
  const _FormulaireParcelle({this.parcelle, required this.onSauvegarde});

  @override
  State<_FormulaireParcelle> createState() => _FormulaireParcelleState();
}

class _FormulaireParcelleState extends State<_FormulaireParcelle> {
  late final TextEditingController _nom;
  late final TextEditingController _localisation;
  late final TextEditingController _proprietaireId;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;

  @override
  void initState() {
    super.initState();
    final p = widget.parcelle;
    _nom = TextEditingController(text: p?['nom'] ?? '');
    _localisation = TextEditingController(text: p?['localisation'] ?? '');
    _proprietaireId = TextEditingController(text: p?['proprietaire']?.toString() ?? '');
    _latitude = TextEditingController(text: p?['latitude']?.toString() ?? '');
    _longitude = TextEditingController(text: p?['longitude']?.toString() ?? '');
  }

  Future<void> _sauvegarder() async {
    final donnees = {
      'nom': _nom.text,
      'localisation': _localisation.text,
      'proprietaire': int.tryParse(_proprietaireId.text),
      if (_latitude.text.isNotEmpty) 'latitude': double.tryParse(_latitude.text),
      if (_longitude.text.isNotEmpty) 'longitude': double.tryParse(_longitude.text),
    };
    if (widget.parcelle != null) {
      await OptionsService.modifierParcelle(widget.parcelle!['id'], donnees);
    } else {
      await OptionsService.creerParcelle(donnees);
    }
    widget.onSauvegarde();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.parcelle != null ? 'Modifier la parcelle' : 'Nouvelle parcelle', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom')),
          const SizedBox(height: 8),
          TextField(controller: _localisation, decoration: const InputDecoration(labelText: 'Localisation')),
          const SizedBox(height: 8),
          TextField(controller: _proprietaireId, decoration: const InputDecoration(labelText: 'ID Proprietaire (utilisateur)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: _latitude, decoration: const InputDecoration(labelText: 'Latitude (optionnel)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: _longitude, decoration: const InputDecoration(labelText: 'Longitude (optionnel)'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _sauvegarder, child: const Text('Enregistrer'))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}