"""
Table de reference des coefficients culturaux Kc (methode FAO-56)
pour les cultures courantes au Togo/Afrique de l'Ouest -- evite a
l'utilisateur d'avoir a connaitre ces valeurs agronomiques.

A FAIRE VALIDER PAR L'AGRONOME DE L'EQUIPE si des ajustements
locaux sont necessaires -- ce sont des valeurs de reference standard.
"""

CULTURES_REFERENCE = {
    'tomate': {
        'kc_initial': 0.5, 'kc_developpement': 0.75, 'kc_mi_saison': 1.15, 'kc_maturation': 0.8,
        'duree_phase_initiale_jours': 20, 'duree_phase_developpement_jours': 25,
        'duree_phase_mi_saison_jours': 35, 'duree_phase_maturation_jours': 20,
        'seuil_humidite_min_pct': 45, 'seuil_humidite_max_pct': 70,
        'ph_min': 5.5, 'ph_max': 7.5,
    },
    'mais': {
        'kc_initial': 0.4, 'kc_developpement': 0.7, 'kc_mi_saison': 1.2, 'kc_maturation': 0.6,
        'duree_phase_initiale_jours': 15, 'duree_phase_developpement_jours': 30,
        'duree_phase_mi_saison_jours': 40, 'duree_phase_maturation_jours': 25,
        'seuil_humidite_min_pct': 40, 'seuil_humidite_max_pct': 65,
        'ph_min': 5.5, 'ph_max': 7.5,
    },
    'piment': {
        'kc_initial': 0.35, 'kc_developpement': 0.65, 'kc_mi_saison': 1.05, 'kc_maturation': 0.85,
        'duree_phase_initiale_jours': 25, 'duree_phase_developpement_jours': 30,
        'duree_phase_mi_saison_jours': 40, 'duree_phase_maturation_jours': 25,
        'seuil_humidite_min_pct': 45, 'seuil_humidite_max_pct': 70,
        'ph_min': 5.5, 'ph_max': 7.0,
    },
    'oignon': {
        'kc_initial': 0.5, 'kc_developpement': 0.75, 'kc_mi_saison': 1.05, 'kc_maturation': 0.75,
        'duree_phase_initiale_jours': 15, 'duree_phase_developpement_jours': 25,
        'duree_phase_mi_saison_jours': 70, 'duree_phase_maturation_jours': 40,
        'seuil_humidite_min_pct': 50, 'seuil_humidite_max_pct': 70,
        'ph_min': 6.0, 'ph_max': 7.0,
    },
    'gombo': {
        'kc_initial': 0.4, 'kc_developpement': 0.7, 'kc_mi_saison': 1.1, 'kc_maturation': 0.65,
        'duree_phase_initiale_jours': 20, 'duree_phase_developpement_jours': 30,
        'duree_phase_mi_saison_jours': 45, 'duree_phase_maturation_jours': 20,
        'seuil_humidite_min_pct': 40, 'seuil_humidite_max_pct': 65,
        'ph_min': 6.0, 'ph_max': 7.5,
    },
}

def trouver_valeurs_reference(nom_culture):
    """Cherche les valeurs Kc de reference pour un nom de culture donne
    (recherche insensible a la casse et aux accents/emojis)."""
    import unicodedata

    nom_normalise = ''.join(
        c for c in unicodedata.normalize('NFD', nom_culture.lower())
        if unicodedata.category(c) != 'Mn'
    ).strip()

    for cle, valeurs in CULTURES_REFERENCE.items():
        if cle in nom_normalise:
            return valeurs
    return None