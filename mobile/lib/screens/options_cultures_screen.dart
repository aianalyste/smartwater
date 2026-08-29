import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/options_service.dart';

class OptionsCulturesScreen extends StatefulWidget {
  const OptionsCulturesScreen({super.key});

  @override
  State<OptionsCulturesScreen> createState() => _OptionsCulturesScreenState();
}

class _OptionsCulturesScreenState extends State<OptionsCulturesScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  void _rafraichir() => setState(() => _future = OptionsService.getCultures());

  void _ouvrirFormulaire({Map<String, dynamic>? culture}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaireCulture(culture: culture, onSauvegarde: _rafraichir),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cultures')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.vertPrincipal,
        onPressed: () => _ouvrirFormulaire(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final cultures = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cultures.length,
            itemBuilder: (context, i) {
              final c = cultures[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(c['nom']),
                  subtitle: Text('Kc mi-saison : ${c['kc_mi_saison']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _ouvrirFormulaire(culture: c)),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: AppColors.danger),
                        onPressed: () async {
                          await OptionsService.supprimerCulture(c['id']);
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

class _FormulaireCulture extends StatefulWidget {
  final Map<String, dynamic>? culture;
  final VoidCallback onSauvegarde;
  const _FormulaireCulture({this.culture, required this.onSauvegarde});

  @override
  State<_FormulaireCulture> createState() => _FormulaireCultureState();
}

class _FormulaireCultureState extends State<_FormulaireCulture> {
  late final TextEditingController _nom;
  late final TextEditingController _kcInitial;
  late final TextEditingController _kcDev;
  late final TextEditingController _kcMi;
  late final TextEditingController _kcMat;

  @override
  void initState() {
    super.initState();
    final c = widget.culture;
    _nom = TextEditingController(text: c?['nom'] ?? '');
   //  _kcInitial = TextEditingController(text: c?['kc_initial']?.toString() ?? '0.5');
    // _kcDev = TextEditingController(text: c?['kc_developpement']?.toString() ?? '0.7');
   //  _kcMi = TextEditingController(text: c?['kc_mi_saison']?.toString() ?? '1.1');
    // _kcMat = TextEditingController(text: c?['kc_maturation']?.toString() ?? '0.8');
  }

  Future<void> _sauvegarder() async {
    try {
      final donnees = {'nom': _nom.text};
      if (widget.culture != null) {
        await OptionsService.modifierCulture(widget.culture!['id'], donnees);
      } else {
        await OptionsService.creerCulture(donnees);
      }
      widget.onSauvegarde();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Culture enregistree.')));
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
      child: ConteneurFormulaire(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.culture != null ? 'Modifier la culture' : 'Nouvelle culture', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Ecris juste le nom (ex: Tomate, Mais, Piment, Oignon, Gombo) — les besoins en eau sont remplis automatiquement.',
            style: TextStyle(fontSize: 12, color: AppColors.texteSecondaire),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom de la culture')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _sauvegarder, child: const Text('Enregistrer'))),
          const SizedBox(height: 20),
        ],
      ),
      )
    );
  }
}