import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'options_cultures_screen.dart';
import 'options_parcelles_screen.dart';
import 'options_zones_screen.dart';
import 'options_demandes_screen.dart';
import 'options_utilisateurs_screen.dart';
import 'options_materiel_screen.dart';

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      {'titre': 'Demandes de rattachement', 'icone': Icons.person_add_alt, 'ecran': const OptionsDemandesScreen()},
      {'titre': 'Cultures', 'icone': Icons.eco_outlined, 'ecran': const OptionsCulturesScreen()},
      {'titre': 'Parcelles', 'icone': Icons.map_outlined, 'ecran': const OptionsParcellesScreen()},
      {'titre': 'Zones', 'icone': Icons.grid_view_outlined, 'ecran': const OptionsZonesScreen()},
      {'titre': 'Utilisateurs', 'icone': Icons.people_outline, 'ecran': const OptionsUtilisateursScreen()},
      {'titre': 'Materiel (Devices/Capteurs/Vannes)', 'icone': Icons.developer_board, 'ecran': const OptionsMaterielScreen()},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final s = sections[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: Icon(s['icone'] as IconData, color: AppColors.vertPrincipal),
              title: Text(s['titre'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.texteSecondaire),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => s['ecran'] as Widget)),
            ),
          );
        },
      ),
    );
  }
}