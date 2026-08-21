import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/inscription_screen.dart';
import 'screens/home_shell.dart';
import 'services/session_service.dart';

const String apiBaseUrl = 'https://smartwater-mn2b.onrender.com/api';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SessionService.estConnecte(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final connecte = snapshot.data ?? false;
        return connecte ? const HomeShell() : const InscriptionScreen();
      },
    );
  }
}