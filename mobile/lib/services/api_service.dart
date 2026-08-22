import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart' show apiBaseUrl;
import 'session_service.dart';

class ApiService {
  static Future<Map<String, String>> _headers() async {
    final token = await SessionService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  static Future<Map<String, dynamic>> getMeteo(int zoneId) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/zones/$zoneId/meteo/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur meteo (${response.statusCode})');
  }

  static Future<List<dynamic>> getMesParcelles() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/parcelles/'), headers: await _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Erreur lors du chargement des parcelles (${response.statusCode})');
  }

  static Future<void> envoyerDemandeRattachement(String nomParcelle, String localisation) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/demandes-rattachement/'),
      headers: await _headers(),
      body: jsonEncode({
        'nom_parcelle_indique': nomParcelle,
        'localisation_indiquee': localisation,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Erreur lors de l\'envoi de la demande (${response.statusCode})');
    }
  }

  static Future<void> demarrerIrrigationManuelle(int zoneId, double dureeMinutes) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/zones/$zoneId/irrigation-manuelle/'),
      headers: await _headers(),
      body: jsonEncode({'duree_minutes': dureeMinutes}),
    );
    if (response.statusCode != 201) {
      throw Exception('Erreur lors du demarrage de l\'irrigation (${response.statusCode})');
    }
  }

  static Future<void> arreterIrrigation(int zoneId) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/zones/$zoneId/arreter-irrigation/'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'arret de l\'irrigation (${response.statusCode})');
    }
  }

  static Future<Map<String, dynamic>> getRapportEconomieEau(int zoneId, {int jours = 30}) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/zones/$zoneId/rapport-eau/?jours=$jours'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur lors du chargement du rapport (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> getHistoriqueCapteur(int zoneId, {int jours = 7}) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/zones/$zoneId/historique/?jours=$jours'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur lors du chargement de l\'historique (${response.statusCode})');
  }
}
