"""
Moteur de decision d'irrigation SmartWater.

C'est ici que tout ce qu'on a defini ensemble se rejoint :
- humidite mesuree par le capteur SEN0600
- meteo (Open-Meteo) : pluie prevue aujourd'hui, et projection jusqu'a
  la prochaine pluie
- phase phenologique de la culture (date de semis ou capteur spectral)
- besoin en eau reel (ETc = Kc x ETo, methode FAO-56)

Ce module est appele automatiquement (voir mqtt_client/mqtt_listener.py
pour le declenchement a chaque nouvelle lecture capteur, ou via une
tache planifiee Celery pour une verification reguliere meme sans
nouvelle lecture).
"""

from datetime import datetime, timedelta

from django.utils import timezone

from core.models import DecisionIrrigation, Zone
from .fao56 import calculer_etc
from .weather import get_previsions_pluie, prochaine_pluie_significative, pluie_cumulee_avant
from .humidity_prediction import faut_il_irriguer_avant_la_pluie
from .water_savings import estimer_volume_irrigation


def prendre_decision(zone: Zone, humidite_pct: float, temperature_c: float) -> DecisionIrrigation:
    """
    Prend une decision d'irrigation pour une zone, et l'enregistre en
    base de donnees (table DecisionIrrigation).

    C'est la fonction "cerveau" de tout SmartWater.
    """
    parcelle = zone.parcelle
    previsions = get_previsions_pluie(parcelle.latitude, parcelle.longitude, heures=24)
    prochaine_pluie = prochaine_pluie_significative(previsions)

    seuil_min = zone.culture.seuil_humidite_min_pct
    etc_mm, phase, kc = calculer_etc(zone, temperature_c)

    # --- Etape 1 : l'humidite actuelle est-elle deja suffisante ? ---
    if humidite_pct >= seuil_min:
        decision = DecisionIrrigation.objects.create(
            zone=zone,
            humidite_mesuree_pct=humidite_pct,
            pluie_prevue_mm=0,
            etc_calcule_mm=etc_mm,
            decision='aucune',
            explication=(
                f"Humidite suffisante ({humidite_pct:.0f}% >= seuil {seuil_min:.0f}%) "
                f"-- phase {phase}, pas d'irrigation necessaire."
            ),
        )
        return decision

    # --- Etape 2 : y a-t-il de la pluie prevue aujourd'hui qui couvre le besoin ? ---
    if prochaine_pluie:
        pluie_cumulee = pluie_cumulee_avant(previsions, prochaine_pluie['heure'] + timedelta(hours=1))
        if pluie_cumulee >= etc_mm:
            decision = DecisionIrrigation.objects.create(
                zone=zone,
                humidite_mesuree_pct=humidite_pct,
                pluie_prevue_mm=pluie_cumulee,
                etc_calcule_mm=etc_mm,
                decision='reportee',
                explication=(
                    f"Irrigation reportee : {pluie_cumulee:.1f}mm de pluie prevus, "
                    f"couvrant le besoin calcule de {etc_mm:.1f}mm."
                ),
            )
            return decision

    # --- Etape 3 : prediction de l'humidite jusqu'a la prochaine pluie ---
    heure_pluie = prochaine_pluie['heure'] if prochaine_pluie else None
    if heure_pluie:
        resultat_prediction = faut_il_irriguer_avant_la_pluie(
            zone, humidite_pct, temperature_c, heure_pluie
        )
        if not resultat_prediction['irriguer']:
            decision = DecisionIrrigation.objects.create(
                zone=zone,
                humidite_mesuree_pct=humidite_pct,
                pluie_prevue_mm=prochaine_pluie['pluie_mm'],
                etc_calcule_mm=etc_mm,
                decision='aucune',
                explication=resultat_prediction['explication'],
            )
            return decision

    # --- Etape 4 : irrigation necessaire -- calcul du volume ---
    pluie_deja_prevue = pluie_cumulee_avant(previsions, timezone.now() + timedelta(hours=6))
    besoin_net_mm = max(0.0, etc_mm - pluie_deja_prevue)
    volume_l, duree_min = estimer_volume_irrigation(zone, besoin_net_mm)

    decision = DecisionIrrigation.objects.create(
        zone=zone,
        humidite_mesuree_pct=humidite_pct,
        pluie_prevue_mm=pluie_deja_prevue,
        etc_calcule_mm=etc_mm,
        volume_irrigue_estime_l=volume_l,
        duree_minutes=duree_min,
        decision='irrigation',
        explication=(
            f"Irrigation necessaire : besoin calcule {etc_mm:.1f}mm (phase {phase}), "
            f"humidite {humidite_pct:.0f}% sous le seuil {seuil_min:.0f}%. "
            f"Volume estime : {volume_l:.0f}L sur {duree_min:.0f} min."
        ),
    )

    # A CONNECTER : declencher reellement la vanne via MQTT ici.
    # Voir mqtt_client/mqtt_listener.py -> fonction envoyer_commande_vanne()
    from mqtt_client.mqtt_listener import envoyer_commande_vanne
    envoyer_commande_vanne(zone, ouverture=True, duree_minutes=duree_min)

    return decision
