import 'package:flutter/material.dart';

import '../services/options_service.dart';

class OptionsUtilisateursScreen extends StatefulWidget {
  const OptionsUtilisateursScreen({super.key});

  @override
  State<OptionsUtilisateursScreen> createState() => _OptionsUtilisateursScreenState();
}

class _OptionsUtilisateursScreenState extends State<OptionsUtilisateursScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _rafraichir();
  }

  void _rafraichir() => setState(() => _future = OptionsService.getUtilisateurs());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final utilisateurs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: utilisateurs.length,
            itemBuilder: (context, i) {
              final u = utilisateurs[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(u['nom'] ?? ''),
                  subtitle: Text(u['telephone'] ?? ''),
                  trailing: DropdownButton<String>(
                    value: u['role'],
                    items: const [
                      DropdownMenuItem(value: 'agriculteur', child: Text('Agriculteur')),
                      DropdownMenuItem(value: 'agronome', child: Text('Agronome')),
                      DropdownMenuItem(value: 'technicien', child: Text('Technicien')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (nouveauRole) async {
                      if (nouveauRole != null) {
                        await OptionsService.modifierRoleUtilisateur(u['id'], nouveauRole);
                        _rafraichir();
                      }
                    },
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