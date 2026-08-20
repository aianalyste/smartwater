import 'package:flutter/material.dart';

/// Theme visuel de l'app SmartWater, base sur les couleurs du logo
/// (goutte bleu/vert avec feuilles).
class AppColors {
  // Couleurs extraites du logo fourni
  static const vertPrincipal = Color(0xFF2E7D4A);   // feuilles / boutons principaux
  static const vertFonce = Color(0xFF1F5C34);        // texte "Smartwater" du logo
  static const vertClair = Color(0xFF7CC142);        // accents, succes
  static const bleuEau = Color(0xFF4FC3F7);          // goutte d'eau
  static const bleuClairFond = Color(0xFFE7F8FD);    // fonds de carte "eau"

  // Couleurs fonctionnelles
  static const alerte = Color(0xFFE0A02E);
  static const danger = Color(0xFFD84A3A);
  static const fondClair = Color(0xFFF7FAF7);
  static const texteSecondaire = Color(0xFF6B7A70);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.fondClair,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.vertPrincipal,
        primary: AppColors.vertPrincipal,
        secondary: AppColors.bleuEau,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.fondClair,
        foregroundColor: AppColors.vertFonce,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.vertFonce,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vertPrincipal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.vertPrincipal,
        unselectedItemColor: AppColors.texteSecondaire,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
