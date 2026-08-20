import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

/// =========================================================
/// A REMPLIR AVANT DE LANCER L'APP :
/// Ces valeurs viennent de ton projet Supabase
/// (Project Settings > API).
/// =========================================================
const String supabaseUrl = 'https://xxxxxxxxxxxxxxxx.supabase.co';
const String supabaseAnonKey = 'ta-cle-anon-supabase';

/// A REMPLIR : adresse de ton backend Django une fois deploye.
/// En developpement local avec l'emulateur Android, utilise
/// 10.0.2.2 au lieu de 127.0.0.1 pour joindre ta machine.
const String apiBaseUrl = 'http://10.0.2.2:8000/api';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const SmartWaterApp());
}

class SmartWaterApp extends StatelessWidget {
  const SmartWaterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartWater',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthGate(),
    );
  }
}

/// Redirige vers l'ecran de connexion ou vers l'app principale
/// selon que l'utilisateur est deja authentifie (session Supabase).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const HomeShell() : const LoginScreen();
  }
}
