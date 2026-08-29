import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/options_service.dart';
import '../widgets/conteneur_formulaire.dart';

class OptionsParcellesScreen extends StatefulWidget {
  const OptionsParcellesScreen({super.key});

  @override
  State<OptionsParcellesScreen> createState() => _OptionsParcellesScreenState();
}

class _OptionsParcellesScreenState extends State<OptionsParcellesScreen> {
  late Future<List<dynamic>> _future;
  late Future<List<dynamic>> _utilisateurs;

  @override
  void initState() {
    super.initState();
    _rafraichir();
    _utilisateurs = OptionsService.getUtilisateurs();
  }

  void _rafraichir() => setState(() => _future = OptionsService.getParcelles());

  void _ouvrirFormulaire({Map<String, dynamic>? parcelle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaireParcelle(parcelle: parcelle, utilisateurs: _utilisateurs, onSauvegarde: _rafraichir),
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
          if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
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
  final Future<List<dynamic>> utilisateurs;
  final VoidCallback onSauvegarde;
  const _FormulaireParcelle({this.parcelle, required this.utilisateurs, required this.onSauvegarde});

  @override
  State<_FormulaireParcelle> createState() => _FormulaireParcelleState();
}

class _FormulaireParcelleState extends State<_FormulaireParcelle> {
  late final TextEditingController _nom;
  late final TextEditingController _localisation;
  int? _proprietaireId;

  @override
  void initState() {
    super.initState();
    final p = widget.parcelle;
    _nom = TextEditingController(text: p?['nom'] ?? '');
    _localisation = TextEditingController(text: p?['localisation'] ?? '');
    _proprietaireId = p?['proprietaire'];
  }

  Future<void> _sauvegarder() async {
    if (_proprietaireId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis un proprietaire.')));
      return;
    }
    try {
      final donnees = {
        'nom': _nom.text,
        'localisation': _localisation.text,
        'proprietaire': _proprietaireId,
      };
      if (widget.parcelle != null) {
        await OptionsService.modifierParcelle(widget.parcelle!['id'], donnees);
      } else {
        await OptionsService.creerParcelle(donnees);
      }
      widget.onSauvegarde();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcelle enregistree.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: ConteneurFormulaire(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.parcelle != null ? 'Modifier la parcelle' : 'Nouvelle parcelle', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Les coordonnees GPS sont trouvees automatiquement a partir de la localite.',
              style: TextStyle(fontSize: 12, color: AppColors.texteSecondaire),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 8),
            TextField(controller: _localisation, decoration: const InputDecoration(labelText: 'Localisation (ex: Notse, Aneho...)')),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: widget.utilisateurs,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final utilisateurs = snapshot.data!;
                return DropdownButtonFormField<int>(
                  value: _proprietaireId,
                  decoration: const InputDecoration(labelText: 'Proprietaire'),
                  items: utilisateurs.map<DropdownMenuItem<int>>((u) {
                    return DropdownMenuItem<int>(
                      value: u['id'],
                      child: Text('${u['nom']} (${u['telephone']})'),
                    );
                  }).toList(),
                  onChanged: (valeur) => setState(() => _proprietaireId = valeur),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _sauvegarder, child: const Text('Enregistrer'))),
            const SizedBox(height: 20),
          ],
        ),
      ),
      )
    );
  }
}