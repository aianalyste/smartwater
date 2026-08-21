import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'home_shell.dart';

class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});

  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _villeController = TextEditingController();
  final _localiteController = TextEditingController();

  bool _chargement = false;
  String? _erreur;

  Future<void> _valider() async {
    if (_nomController.text.trim().isEmpty || _telephoneController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le nom et le telephone sont obligatoires.');
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      await SessionService.inscrireOuConnecter(
        nom: _nomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        ville: _villeController.text.trim(),
        localite: _localiteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _erreur = 'Impossible de se connecter. Verifie ta connexion.');
    } finally {
      setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', height: 100),
                const SizedBox(height: 8),
                const Text(
                  'SmartWater',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.vertFonce),
                ),
                const SizedBox(height: 4),
                Text('Irrigation intelligente', style: TextStyle(fontSize: 14, color: AppColors.texteSecondaire)),
                const SizedBox(height: 36),

                TextField(
                  controller: _nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numero de telephone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _villeController,
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _localiteController,
                  decoration: const InputDecoration(
                    labelText: 'Localite',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),

                if (_erreur != null) ...[
                  const SizedBox(height: 12),
                  Text(_erreur!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _chargement ? null : _valider,
                    child: _chargement
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Continuer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}