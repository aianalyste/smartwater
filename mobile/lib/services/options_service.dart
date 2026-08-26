import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart' show apiBaseUrl;
import 'session_service.dart';

class OptionsService {
  static Future<Map<String, String>> _headers() async {
    final token = await SessionService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  // --- Generique liste ---
  static Future<List<dynamic>> _getListe(String chemin) async {
    final response = await http.get(Uri.parse('$apiBaseUrl/options/$chemin/'), headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
    throw Exception('Erreur ($chemin) : ${response.statusCode}');
  }

  static Future<List<dynamic>> getCultures() => _getListe('cultures');
  static Future<List<dynamic>> getParcelles() => _getListe('parcelles');
  static Future<List<dynamic>> getZones() => _getListe('zones');
  static Future<List<dynamic>> getUtilisateurs() => _getListe('utilisateurs');
  static Future<List<dynamic>> getDevices() => _getListe('devices');
  static Future<List<dynamic>> getCapteurs() => _getListe('capteurs');
  static Future<List<dynamic>> getVannes() => _getListe('vannes');
  static Future<List<dynamic>> getDemandesEnAttente() => _getListe('demandes');

  // --- Culture CRUD ---
  static Future<void> creerCulture(Map<String, dynamic> donnees) async {
    final response = await http.post(Uri.parse('$apiBaseUrl/options/cultures/'), headers: await _headers(), body: jsonEncode(donnees));
    if (response.statusCode != 201) throw Exception('Erreur creation culture');
  }

  static Future<void> modifierCulture(int id, Map<String, dynamic> donnees) async {
    final response = await http.patch(Uri.parse('$apiBaseUrl/options/cultures/$id/'), headers: await _headers(), body: jsonEncode(donnees));
    if (response.statusCode != 200) throw Exception('Erreur modification culture');
  }

  static Future<void> supprimerCulture(int id) async {
    final response = await http.delete(Uri.parse('$apiBaseUrl/options/cultures/$id/'), headers: await _headers());
    if (response.statusCode != 204) throw Exception('Erreur suppression culture');
  }

  // --- Parcelle CRUD ---
  static Future<void> creerParcelle(Map<String, dynamic> donnees) async {
    final response = await http.post(Uri.parse('$apiBaseUrl/options/parcelles/'), headers: await _headers(), body: jsonEncode(donnees));
    if (response.statusCode != 201) throw Exception('Erreur creation parcelle');
  }

  static Future<void> modifierParcelle(int id, Map<String, dynamic> donnees) async {
    final response = await http.patch(Uri.parse('$apiBaseUrl/options/parcelles/$id/'), headers: await _headers(), body: jsonEncode(donnees));
    if (response.statusCode != 200) throw Exception('Erreur modification parcelle');
  }

  static Future<void> supprimerParcelle(int id) async {
    final response = await http.delete(Uri.parse('$apiBaseUrl/options/parcelles/$id/'), headers: await _headers());
    if (response.statusCode != 204) throw Exception('Erreur suppression parcelle');
  }

  // --- Zone CRUD ---
  static Future<void> creerZone(Map<String, dynamic> donnees) async {
    final response = await http.post(Uri.parse('$apiBaseUrl/options/zones/'), headers: await _headers(), body: jsonEncode(donnees));
    if (response.statusCode != 201) throw Exception('Erreur creation zone');
  }

  static Future<void> modifierZone(int id, Map<String, dynamic> donnees) async {
    final response = await http.patch(Uri.parse('$apiBaseUrl/options/zones/$id/'), headers: await _headers(), body: jsonEncode(donnees));
    if (response.statusCode != 200) throw Exception('Erreur modification zone');
  }

  static Future<void> supprimerZone(int id) async {
    final response = await http.delete(Uri.parse('$apiBaseUrl/options/zones/$id/'), headers: await _headers());
    if (response.statusCode != 204) throw Exception('Erreur suppression zone');
  }

  // --- Utilisateur (role modifiable) ---
  static Future<void> modifierRoleUtilisateur(int id, String role) async {
    final response = await http.patch(Uri.parse('$apiBaseUrl/options/utilisateurs/$id/'), headers: await _headers(), body: jsonEncode({'role': role}));
    if (response.statusCode != 200) throw Exception('Erreur modification role');
  }

  // --- Demandes de rattachement ---
  static Future<void> validerDemande(int demandeId, int parcelleId) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/options/demandes/$demandeId/valider/'),
      headers: await _headers(),
      body: jsonEncode({'parcelle_id': parcelleId}),
    );
    if (response.statusCode != 200) throw Exception('Erreur validation demande');
  }

  static Future<void> refuserDemande(int demandeId) async {
    final response = await http.post(Uri.parse('$apiBaseUrl/options/demandes/$demandeId/refuser/'), headers: await _headers());
    if (response.statusCode != 200) throw Exception('Erreur refus demande');
  }
}