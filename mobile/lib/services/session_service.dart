import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show apiBaseUrl;

class SessionService {
  static const _cleToken = 'smartwater_session_token';
  static const _cleNom = 'smartwater_nom';
  static const _cleRole = 'smartwater_role';

  static Future<void> inscrireOuConnecter({
    required String nom,
    required String telephone,
    required String ville,
    required String localite,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/inscription/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nom': nom,
        'telephone': telephone,
        'ville': ville,
        'localite': localite,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'inscription (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleToken, data['session_token']);
    await prefs.setString(_cleNom, data['nom'] ?? '');
    await prefs.setString(_cleRole, data['role'] ?? 'agriculteur');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cleToken);
  }

  static Future<String?> getNom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cleNom);
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cleRole) ?? 'agriculteur';
  }

  static Future<bool> peutGererOptions() async {
    final role = await getRole();
    return role == 'admin' || role == 'agronome';
  }

  static Future<bool> estConnecte() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> deconnecter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cleToken);
    await prefs.remove(_cleNom);
    await prefs.remove(_cleRole);
  }
}