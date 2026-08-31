"""
Deduction de la phase phenologique a partir du capteur spectral
(NDVI), quand la Zone est configuree en mode_calcul_phase='capteur'.

IMPORTANT (valide ensemble) : le NDVI suit une courbe "en cloche" au
cours du cycle de la plante -- il monte pendant la croissance, atteint
un maximum en floraison, puis REDESCEND en maturation. Une seule
valeur de NDVI ne suffit donc pas a determiner la phase de facon
fiable (un NDVI moyen peut correspondre a une jeune plante en
croissance OU a une plante agee en fin de cycle).

C'est pourquoi ce module se base sur la TENDANCE (le NDVI monte-t-il
ou descend-il ?) combinee au pic historique observe pour cette zone,
plutot que sur un simple seuil fixe.

Seuils indicatifs -- A VALIDER/AJUSTER AVEC L'AGRONOME selon la
culture et les retours de terrain :
- NDVI < 0.2                          -> Germination
- NDVI en hausse, sous le pic connu   -> Vegetative
- NDVI proche du pic connu (>=90%)    -> Floraison
- NDVI en baisse apres avoir atteint
  le pic                              -> Maturation
"""

from django.utils import timezone
from datetime import timedelta

SEUIL_GERMINATION = 0.2
PROXIMITE_PIC = 0.9  # 90% du pic historique = considere "proche du pic"
NB_LECTURES_MIN = 2  # nombre minimum de lectures pour deduire une tendance


def deduire_phase_ndvi(capteur, fenetre_jours=90):
    """
    Retourne un dict {'phase', 'kc', 'source', 'ndvi_actuel',
    'ndvi_pic', 'explication'} ou None si pas assez de donnees
    pour deduire quoi que ce soit (l'appelant doit alors se
    rabattre sur la date de semis).
    """
    if capteur is None or capteur.dernier_ndvi is None:
        return None

    depuis = timezone.now() - timedelta(days=fenetre_jours)
    lectures = list(
        capteur.lectures.filter(ndvi__isnull=False, horodatage__gte=depuis)
        .order_by('horodatage')
    )

    if len(lectures) < NB_LECTURES_MIN:
        return None

    ndvi_actuel = capteur.dernier_ndvi
    ndvi_pic = max(l.ndvi for l in lectures)

    # Tendance : moyenne des 2 dernieres lectures vs les 2 precedentes
    recentes = [l.ndvi for l in lectures[-2:]]
    anterieures = [l.ndvi for l in lectures[-4:-2]] if len(lectures) >= 4 else [lectures[0].ndvi]
    tendance_hausse = (sum(recentes) / len(recentes)) >= (sum(anterieures) / len(anterieures))

    culture = capteur.zone.culture

    if ndvi_actuel < SEUIL_GERMINATION:
        phase, kc = 'initiale', culture.kc_initial
        explication = f"NDVI faible ({ndvi_actuel:.2f}) -- phase germination/levee."
    elif ndvi_actuel >= ndvi_pic * PROXIMITE_PIC and tendance_hausse:
        phase, kc = 'mi_saison', culture.kc_mi_saison
        explication = f"NDVI proche du maximum observe ({ndvi_actuel:.2f} / pic {ndvi_pic:.2f}) -- phase floraison/mi-saison."
    elif not tendance_hausse and ndvi_actuel < ndvi_pic * PROXIMITE_PIC:
        phase, kc = 'maturation', culture.kc_maturation
        explication = f"NDVI en baisse apres un pic de {ndvi_pic:.2f} -- phase maturation."
    else:
        phase, kc = 'developpement', culture.kc_developpement
        explication = f"NDVI en hausse ({ndvi_actuel:.2f}), sous le pic -- phase de developpement/croissance."

    return {
        'phase': phase,
        'kc': kc,
        'source': 'capteur',
        'ndvi_actuel': round(ndvi_actuel, 3),
        'ndvi_pic': round(ndvi_pic, 3),
        'explication': explication,
    }