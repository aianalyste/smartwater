"""
Calculs agronomiques bases sur la methode FAO-56 : coefficient
cultural (Kc) et besoin en eau reel de la culture (ETc = Kc x ETo).

C'est le calcul qu'on a defini ensemble et qui distingue SmartWater
d'un simple arrosage par seuil d'humidite.
"""

from datetime import date


def calculer_phase_phenologique(zone, aujourdhui=None):
    """
    Determine la phase phenologique actuelle d'une zone.

    Deux sources possibles (voir Zone.phase_source) :
    - 'date_semis' : calcul a partir du nombre de jours depuis le semis
      et des durees de phase definies sur la Culture.
    - 'capteur_spectral' : la derniere phase detectee par le capteur
      AS7265x est utilisee directement (voir irrigation/spectral_ia.py
      -- A COMPLETER une fois que les vraies donnees du capteur AS7265x
      seront disponibles, car le mapping longueur d'onde -> phase
      depend de calibrations qu'on n'a pas encore).

    Retourne un tuple (nom_phase, kc_associe).
    """
    if aujourdhui is None:
        aujourdhui = date.today()

    culture = zone.culture
    jours_depuis_semis = (aujourdhui - zone.date_semis).days

    if jours_depuis_semis < 0:
        return ('non_semee', 0.0)

    fin_initiale = culture.duree_phase_initiale_jours
    fin_developpement = fin_initiale + culture.duree_phase_developpement_jours
    fin_mi_saison = fin_developpement + culture.duree_phase_mi_saison_jours
    fin_maturation = fin_mi_saison + culture.duree_phase_maturation_jours

    if jours_depuis_semis <= fin_initiale:
        return ('initiale', culture.kc_initial)
    elif jours_depuis_semis <= fin_developpement:
        return ('developpement', culture.kc_developpement)
    elif jours_depuis_semis <= fin_mi_saison:
        return ('mi_saison', culture.kc_mi_saison)
    elif jours_depuis_semis <= fin_maturation:
        return ('maturation', culture.kc_maturation)
    else:
        return ('recolte', culture.kc_maturation)


def calculer_eto_simplifie(temperature_c, humidite_air_pct=60, ensoleillement_h=7):
    """
    Calcul SIMPLIFIE de l'evapotranspiration de reference (ETo),
    utilisable au demarrage sans station meteo complete.

    ATTENTION : c'est une approximation (methode Hargreaves simplifiee),
    pas le calcul FAO Penman-Monteith complet qui necessite plus de
    donnees (vent, rayonnement net, etc.). A ameliorer plus tard si
    vous obtenez plus de donnees meteo detaillees (ex: vitesse du
    vent via une station meteo locale).

    Retourne l'ETo en mm/jour.
    """
    # Formule d'Hargreaves simplifiee : ETo ~ 0.0135 * (T + 17.8) * facteur ensoleillement
    facteur_ensoleillement = ensoleillement_h / 12.0
    eto = 0.0135 * (temperature_c + 17.8) * facteur_ensoleillement * 5.0
    return max(0.0, round(eto, 2))


def calculer_etc(zone, temperature_c, aujourdhui=None):
    """
    Calcule le besoin en eau reel de la culture pour aujourd'hui.

    ETc = Kc x ETo

    Retourne (etc_mm, phase, kc).
    """
    phase, kc = calculer_phase_phenologique(zone, aujourdhui)
    eto = calculer_eto_simplifie(temperature_c)
    etc = round(kc * eto, 2)
    return etc, phase, kc
