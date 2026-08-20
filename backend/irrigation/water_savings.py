"""
Estimation du volume d'eau irrigue (sans debitmetre physique) et
calcul du rapport d'economie d'eau -- comme valide ensemble.
"""


def estimer_volume_irrigation(zone, besoin_mm):
    """
    Estime le volume d'eau (litres) et la duree d'ouverture de vanne
    (minutes) necessaires pour apporter `besoin_mm` millimetres d'eau
    sur la superficie de la zone.

    1mm d'eau sur 1m2 = 1 litre. Donc :
        volume_litres = besoin_mm * superficie_m2

    La duree se deduit du debit theorique de l'electrovanne
    (Vanne.debit_theorique_l_min).
    """
    superficie = zone.superficie_m2 or 50.0  # valeur par defaut si non renseignee
    volume_l = besoin_mm * superficie

    try:
        debit = zone.vanne.debit_theorique_l_min
    except Exception:
        debit = 15.0  # valeur par defaut si aucune vanne n'est encore configuree

    duree_min = volume_l / debit if debit > 0 else 0
    return round(volume_l, 1), round(duree_min, 1)


def estimer_volume_arrosage_manuel_reference(zone, jours):
    """
    Estime ce qu'un arrosage manuel "classique" (sans intelligence,
    frequence fixe) aurait consomme sur `jours` jours, pour servir de
    reference dans le rapport d'economie d'eau.

    Hypothese simplifiee : un arrosage manuel classique apporte
    systematiquement l'ETc maximal de la phase mi-saison, tous les
    jours, sans tenir compte de la pluie ni de la phase reelle.
    C'est volontairement une hypothese "pessimiste" realiste -- a
    ajuster si vous avez de meilleures donnees de terrain plus tard.
    """
    from irrigation.fao56 import calculer_eto_simplifie

    eto_moyen = calculer_eto_simplifie(temperature_c=28)  # temperature moyenne Togo
    etc_max_par_jour = zone.culture.kc_mi_saison * eto_moyen
    superficie = zone.superficie_m2 or 50.0
    return round(etc_max_par_jour * superficie * jours, 1)


def generer_rapport_economie_eau(zone, periode_debut, periode_fin):
    """
    Genere (sans sauvegarder) les chiffres d'un rapport d'economie
    d'eau pour une zone sur une periode donnee, a partir de l'historique
    des DecisionIrrigation.
    """
    from core.models import DecisionIrrigation

    decisions = DecisionIrrigation.objects.filter(
        zone=zone,
        date_heure__date__gte=periode_debut,
        date_heure__date__lte=periode_fin,
        decision__in=['irrigation', 'irrigation_manuelle'],
    )
    volume_reel = sum(d.volume_irrigue_estime_l or 0 for d in decisions)

    nb_jours = (periode_fin - periode_debut).days + 1
    volume_reference = estimer_volume_arrosage_manuel_reference(zone, nb_jours)

    if volume_reference > 0:
        pourcentage_economise = round((1 - volume_reel / volume_reference) * 100, 1)
    else:
        pourcentage_economise = 0.0

    return {
        'volume_utilise_estime_l': round(volume_reel, 1),
        'volume_reference_manuel_l': volume_reference,
        'pourcentage_economise': max(0.0, pourcentage_economise),
    }
