import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import 'home_shell.dart';

/// Ecran de saisie du code OTP recu par SMS.
/// Pendant les tests (voir docs/DEPLOIEMENT.md), utilise un des
/// numeros de test configures dans Supabase avec leur code fixe --
/// aucun vrai SMS ne sera envoye pour ces numeros-la.
class OtpScreen extends StatefulWidget {
  final String telephone;
  const OtpScreen({super.key, required this.telephone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  bool _chargement = false;
  String? _erreur;

  Future<void> _verifierCode() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _erreur = 'Le code doit contenir 6 chiffres.');
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        phone: widget.telephone,
        token: code,
        type: OtpType.sms,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _erreur = 'Code incorrect ou expire.');
    } finally {
      setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Entre le code recu au ${widget.telephone}',
                style: const TextStyle(fontSize: 15, color: AppColors.texteSecondaire),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
                decoration: const InputDecoration(counterText: ''),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 8),
                Text(_erreur!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _chargement ? null : _verifierCode,
                child: _chargement
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Valider'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
