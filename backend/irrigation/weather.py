"""
Recuperation des previsions meteo via Open-Meteo (gratuit, sans cle API).

Documentation officielle : https://open-meteo.com/en/docs
"""

import requests
from datetime import datetime, timedelta


OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"


def get_previsions_pluie(latitude, longitude, heures=24):
    """
    Recupere les previsions de pluie heure par heure pour une position
    donnee, sur les prochaines `heures` heures.
    """
    if latitude is None or longitude is None:
        latitude, longitude = 6.1319, 1.2228  # Lome, Togo (valeur par defaut)

    try:
        response = requests.get(
            OPEN_METEO_URL,
            params={
                'latitude': latitude,
                'longitude': longitude,
                'hourly': 'precipitation,precipitation_probability',
                'forecast_days': 2,
                'timezone': 'Africa/Lome',
            },
            timeout=8,
        )
        response.raise_for_status()
        data = response.json()
    except requests.RequestException:
        return []

    heures_list = data.get('hourly', {}).get('time', [])
    pluie_list = data.get('hourly', {}).get('precipitation', [])
    proba_list = data.get('hourly', {}).get('precipitation_probability', [])

    from django.utils import timezone as django_timezone

    maintenant = django_timezone.now()
    resultats = []
    for i, heure_str in enumerate(heures_list):
        heure_dt = datetime.fromisoformat(heure_str)
        # Rendre la date "consciente" du fuseau horaire, comme le reste
        # de Django (USE_TZ=True) -- sinon Python refuse de la comparer
        # a timezone.now().
        if django_timezone.is_naive(heure_dt):
            heure_dt = django_timezone.make_aware(heure_dt, django_timezone.get_current_timezone())

        if maintenant <= heure_dt <= maintenant + timedelta(hours=heures):
            resultats.append({
                'heure': heure_dt,
                'pluie_mm': pluie_list[i] if i < len(pluie_list) else 0.0,
                'probabilite_pct': proba_list[i] if i < len(proba_list) else 0,
            })
    return resultats


def prochaine_pluie_significative(previsions, seuil_mm=2.0):
    """
    Trouve la prochaine heure ou une pluie jugee "significative" est
    prevue (par defaut, plus de 2mm -- ce seuil peut etre ajuste).

    Retourne un dict {'heure': datetime, 'pluie_mm': float} ou None
    si aucune pluie significative n'est prevue dans la fenetre fournie.
    """
    for prevision in previsions:
        if prevision['pluie_mm'] >= seuil_mm:
            return prevision
    return None


def pluie_cumulee_avant(previsions, heure_limite):
    """Somme la pluie prevue (mm) entre maintenant et une heure donnee."""
    return sum(p['pluie_mm'] for p in previsions if p['heure'] <= heure_limite)


def get_previsions_quotidiennes_2_semaines(latitude, longitude):
    """
    Prevision de pluie jour par jour sur les 2 prochaines semaines
    (affichage permanent demande dans le bloc Decision, meme sans
    capteur installe).
    """
    if latitude is None or longitude is None:
        latitude, longitude = 6.1319, 1.2228  # Lome par defaut

    try:
        response = requests.get(
            OPEN_METEO_URL,
            params={
                'latitude': latitude,
                'longitude': longitude,
                'daily': 'precipitation_sum,precipitation_probability_max',
                'forecast_days': 14,
                'timezone': 'Africa/Lome',
            },
            timeout=8,
        )
        response.raise_for_status()
        data = response.json()
    except requests.RequestException:
        return []

    dates = data.get('daily', {}).get('time', [])
    pluies = data.get('daily', {}).get('precipitation_sum', [])
    probas = data.get('daily', {}).get('precipitation_probability_max', [])

    return [
        {
            'date': dates[i],
            'pluie_mm': pluies[i] if i < len(pluies) else 0,
            'probabilite_pct': probas[i] if i < len(probas) else 0,
        }
        for i in range(len(dates))
    ]