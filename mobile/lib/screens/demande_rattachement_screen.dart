import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Ecran de demande manuelle de rattachement a une parcelle, comme
/// valide ensemble : l'agriculteur decrit sa parcelle, la demande
/// part vers l'agronome qui valide depuis le Django Admin.
class DemandeRattachementScreen extends StatefulWidget {
  const DemandeRattachementScreen({super.key});

  @override
  State<DemandeRattachementScreen> createState() => _DemandeRattachementScreenState();
}

class _DemandeRattachementScreenState extends State<DemandeRattachementScreen> {
  final _nomController = TextEditingController();
  final _localisationController = TextEditingController();
  bool _envoi = false;
  bool _envoye = false;
  String? _erreur;

  Future<void> _envoyer() async {
    if (_nomController.text.trim().isEmpty) {
      setState(() => _erreur = 'Indique un nom ou repere pour ta parcelle.');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await ApiService.envoyerDemandeRattachement(
        _nomController.text.trim(),
        _localisationController.text.trim(),
      );
      setState(() => _envoye = true);
    } catch (e) {
      setState(() => _erreur = "Erreur lors de l'envoi. Reessaie.");
    } finally {
      setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demande de rattachement')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _envoye
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 56),
                    SizedBox(height: 16),
                    Text(
                      "Demande envoyee.\nL'agronome va la valider prochainement.",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Decris ta parcelle pour que l'agronome puisse te retrouver et valider ta demande.",
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nomController,
                    decoration: const InputDecoration(labelText: 'Nom / repere de la parcelle'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _localisationController,
                    decoration: const InputDecoration(labelText: 'Localite (optionnel)'),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 8),
                    Text(_erreur!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _envoi ? null : _envoyer,
                    child: _envoi
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Envoyer la demande'),
                  ),
                ],
              ),
      ),
    );
  }
}
