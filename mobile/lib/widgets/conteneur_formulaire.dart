import 'package:flutter/material.dart';

/// Enveloppe un formulaire dans un conteneur de largeur limitee et
/// centre, comme sur Pulsar-Eco-Group -- evite que les champs
/// s'etirent sur toute la largeur de l'ecran (surtout genant sur le
/// web / grand ecran).
class ConteneurFormulaire extends StatelessWidget {
  final Widget child;
  final double largeurMax;
  const ConteneurFormulaire({super.key, required this.child, this.largeurMax = 420});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largeurMax),
        child: child,
      ),
    );
  }
}