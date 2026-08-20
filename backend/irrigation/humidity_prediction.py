"""
Prediction de l'evolution de l'humidite du sol jusqu'a la prochaine
pluie prevue.

C'est la fonctionnalite qu'on a definie ensemble : plutot que de
seulement regarder l'humidite ACTUELLE, le systeme projette son
evolution future et decide s'il est vraiment utile d'irriguer avant
que la pluie n'arrive.

Principe : l'humidite du sol diminue avec le temps a cause de
l'evapotranspiration (ETc, deja calcule dans fao56.py). On simule
cette baisse heure par heure jusqu'a l'heure de la pluie prevue.
"""

from datetime import timedelta

from .fao56 import calculer_etc


def capacite_retention_sol_mm(zone):
    """
    Capacite de retention en eau du sol pour la zone (en mm equivalent).
    Valeur par defaut generique -- A AFFINER plus tard avec une vraie
    analyse de sol (texture argileuse/sableuse/limoneuse) si disponible,
    car ca change significativement la vitesse de dessechement reelle.
    """
    return 60.0  # mm -- valeur moyenne pour un sol limoneux, a ajuster


def projeter_humidite(zone, humidite_actuelle_pct, temperature_c, heure_pluie_prevue,
                       maintenant=None, pas_de_temps_heures=1):
    """
    Projette l'evolution de l'humidite du sol, heure par heure,
    jusqu'a l'heure de la pluie prevue.

    Retourne une liste de points :
        [{'heure': datetime, 'humidite_projetee_pct': float}, ...]
    """
    from datetime import datetime as dt
    if maintenant is None:
        maintenant = dt.now()

    if heure_pluie_prevue is None or heure_pluie_prevue <= maintenant:
        return []

    etc_mm, _phase, _kc = calculer_etc(zone, temperature_c, maintenant.date())
    capacite = capacite_retention_sol_mm(zone)

    # Vitesse de baisse d'humidite par heure, exprimee en points de %
    # (ETc journalier reparti sur 24h, converti en % de la capacite du sol)
    baisse_pct_par_heure = (etc_mm / capacite) * 100 / 24 if capacite > 0 else 0

    points = []
    heure_courante = maintenant
    humidite_courante = humidite_actuelle_pct

    while heure_courante <= heure_pluie_prevue:
        points.append({'heure': heure_courante, 'humidite_projetee_pct': round(humidite_courante, 1)})
        humidite_courante = max(0.0, humidite_courante - baisse_pct_par_heure * pas_de_temps_heures)
        heure_courante += timedelta(hours=pas_de_temps_heures)

    return points


def faut_il_irriguer_avant_la_pluie(zone, humidite_actuelle_pct, temperature_c,
                                     heure_pluie_prevue, maintenant=None):
    """
    Applique la regle validee ensemble :
    "Si l'humidite projetee reste dans la fourchette sure (seuils de
    la culture) jusqu'a la pluie prevue, inutile d'irriguer."

    Retourne un dict avec la decision et l'explication :
        {
            'irriguer': bool,
            'trajectoire': [...],
            'explication': str,
        }
    """
    trajectoire = projeter_humidite(
        zone, humidite_actuelle_pct, temperature_c, heure_pluie_prevue, maintenant
    )

    seuil_min = zone.culture.seuil_humidite_min_pct

    if not trajectoire:
        # Pas de pluie prevue dans la fenetre -> decision basee sur
        # l'humidite actuelle uniquement (voir decision_engine.py)
        return {
            'irriguer': humidite_actuelle_pct < seuil_min,
            'trajectoire': [],
            'explication': "Aucune pluie significative prevue prochainement.",
        }

    humidite_minimale_projetee = min(p['humidite_projetee_pct'] for p in trajectoire)

    if humidite_minimale_projetee >= seuil_min:
        return {
            'irriguer': False,
            'trajectoire': trajectoire,
            'explication': (
                f"L'humidite restera au-dessus de {seuil_min:.0f}% "
                f"(minimum projete : {humidite_minimale_projetee:.0f}%) "
                f"jusqu'a la pluie prevue -- irrigation inutile."
            ),
        }
    else:
        return {
            'irriguer': True,
            'trajectoire': trajectoire,
            'explication': (
                f"L'humidite descendrait a {humidite_minimale_projetee:.0f}% "
                f"avant la pluie prevue (sous le seuil de {seuil_min:.0f}%) "
                f"-- une irrigation d'appoint est necessaire pour tenir jusqu'a la pluie."
            ),
        }
