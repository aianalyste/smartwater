import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import 'otp_screen.dart';

/// Ecran de connexion : l'utilisateur saisit son numero de telephone,
/// recoit un code OTP par SMS (ou utilise un numero de test pendant
/// la phase pilote -- voir docs/DEPLOIEMENT.md).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _telephoneController = TextEditingController();
  bool _chargement = false;
  String? _erreur;

  Future<void> _envoyerCode() async {
    final telephone = _telephoneController.text.trim();
    if (telephone.isEmpty) {
      setState(() => _erreur = 'Entre ton numero de telephone.');
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      // Format E.164 attendu par Supabase : +228XXXXXXXX pour le Togo
      final telephoneFormate = telephone.startsWith('+') ? telephone : '+228$telephone';
      await Supabase.instance.client.auth.signInWithOtp(phone: telephoneFormate);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(telephone: telephoneFormate)),
      );
    } catch (e) {
      setState(() => _erreur = "Impossible d'envoyer le code. Verifie ta connexion.");
    } finally {
      setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 8),
              const Text(
                'SmartWater',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.vertFonce),
              ),
              const SizedBox(height: 4),
              Text(
                "Irrigation intelligente",
                style: TextStyle(fontSize: 14, color: AppColors.texteSecondaire),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numero de telephone',
                  hintText: '90 XX XX XX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 8),
                Text(_erreur!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _chargement ? null : _envoyerCode,
                  child: _chargement
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Recevoir un code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
