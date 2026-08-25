"""
Prediction de l'humidite future basee sur la tendance historique
recente (point 5 de la liste validee) : "pendant 24h l'humidite
baisse de 3%, donc dans 5 jours elle sera environ X%".

Different de humidity_prediction.py : ce module ne se limite pas a
la prochaine pluie, il projette sur plusieurs jours a partir du
rythme de baisse observe dans les vraies mesures passees.
"""

from datetime import timedelta

from django.utils import timezone


def calculer_tendance_recente(capteur, heures=24):
    """
    Calcule la vitesse de variation de l'humidite (en %/heure) sur
    les dernieres heures, a partir des vraies lectures enregistrees.

    Retourne None si pas assez de donnees pour calculer une tendance
    fiable.
    """
    depuis = timezone.now() - timedelta(hours=heures)
    lectures = list(
        capteur.lectures.filter(horodatage__gte=depuis, humidite_pct__isnull=False)
        .order_by('horodatage')
    )

    if len(lectures) < 2:
        return None

    premiere = lectures[0]
    derniere = lectures[-1]

    duree_heures = (derniere.horodatage - premiere.horodatage).total_seconds() / 3600
    if duree_heures <= 0:
        return None

    variation_totale = derniere.humidite_pct - premiere.humidite_pct
    return variation_totale / duree_heures  # %/heure (negatif = baisse)


def predire_humidite_future(capteur, jours=5):
    """
    Projette l'humidite pour les prochains jours a partir de la
    tendance recente. Retourne une liste de points
    [{'jour': 1, 'humidite_projetee_pct': ...}, ...], ou une liste
    vide si pas assez de donnees pour predire.
    """
    tendance_par_heure = calculer_tendance_recente(capteur)
    if tendance_par_heure is None or capteur.derniere_humidite_pct is None:
        return []

    resultats = []
    humidite = capteur.derniere_humidite_pct

    for jour in range(1, jours + 1):
        humidite += tendance_par_heure * 24
        humidite = max(0, min(100, humidite))
        resultats.append({'jour': jour, 'humidite_projetee_pct': round(humidite, 1)})

    return resultats