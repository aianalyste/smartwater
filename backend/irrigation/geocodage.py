"""
Trouve automatiquement latitude/longitude a partir du nom d'une
localite (ville, village), pour eviter que l'utilisateur ait a
connaitre/saisir des coordonnees GPS manuellement.

Utilise l'API de geocodage gratuite d'Open-Meteo (pas de cle requise).
"""

import requests

GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search"


def trouver_coordonnees(nom_localite, pays="Togo"):
    """
    Retourne (latitude, longitude) pour une localite donnee, ou
    None si introuvable.
    """
    if not nom_localite:
        return None

    try:
        response = requests.get(
            GEOCODING_URL,
            params={'name': nom_localite, 'count': 5, 'language': 'fr'},
            timeout=8,
        )
        response.raise_for_status()
        data = response.json()
    except requests.RequestException:
        return None

    resultats = data.get('results', [])
    if not resultats:
        return None

    # Priorite aux resultats situes au Togo si plusieurs correspondances
    for r in resultats:
        if r.get('country', '').lower() == pays.lower():
            return (r['latitude'], r['longitude'])

    # Sinon, premier resultat par defaut
    return (resultats[0]['latitude'], resultats[0]['longitude'])