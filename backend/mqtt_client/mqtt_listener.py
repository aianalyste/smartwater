"""
Client MQTT : communication en temps reel avec les ESP32 sur le terrain.

=============================================================
SPECIFICATION DES TOPICS ET FORMATS (a transmettre au GE)
=============================================================

Topics utilises (namespace par DEVICE, un ESP32 peut gerer plusieurs
zones -- chaque zone est identifiee par son "code_terrain", ex: Z1, Z2) :

    smartwater/<device_id>/capteurs        -> ESP32 publie les lectures (JSON, voir plus bas)
    smartwater/<device_id>/commande        -> backend publie les commandes vanne (JSON, voir plus bas)
    smartwater/<device_id>/status          -> ESP32 publie son statut (batterie, etc.)
    smartwater/<device_id>/capteurs_differe -> ESP32 publie les lectures accumulees
                                                pendant une coupure reseau, une fois reconnecte

--- Format EXACT du topic "capteurs" (ESP32 -> backend) ---
Un ESP32 peut avoir plusieurs zones (plusieurs capteurs/vannes) : on
envoie donc un TABLEAU JSON, un objet par zone :

    [
      {"zone_code": "Z1", "humidite_pct": 42.5, "temperature_c": 27.3},
      {"zone_code": "Z2", "humidite_pct": 38.1, "temperature_c": 28.0}
    ]

"zone_code" DOIT correspondre exactement au champ "code_terrain" de
la Zone dans le Django Admin.

--- Format EXACT du topic "commande" (backend -> ESP32) ---
    {"zone_code": "Z1", "vanne": "ouvrir", "duree_minutes": 20}
    {"zone_code": "Z1", "vanne": "fermer"}

--- Format EXACT du topic "status" ---
    {"batterie_pct": 87}

--- Format EXACT du topic "capteurs_differe" (mode hors-ligne) ---
Meme structure que "capteurs", mais avec un horodatage relatif
(secondes ecoulees depuis la mesure, puisque l'ESP32 n'a pas
d'horloge reseau en mode hors-ligne) :

    [
      {"zone_code": "Z1", "humidite_pct": 41.0, "temperature_c": 27.0, "il_y_a_secondes": 720},
      {"zone_code": "Z1", "humidite_pct": 39.5, "temperature_c": 27.5, "il_y_a_secondes": 360}
    ]

=============================================================
AUTHENTIFICATION DE L'ESP32 (repond au point 3 de la liste GE)
=============================================================
L'ESP32 s'authentifie directement aupres du broker MQTT avec un
identifiant/mot de passe (voir MQTT_USERNAME/MQTT_PASSWORD dans le
firmware et le .env backend) -- ce n'est PAS un token applicatif
comme pour l'app Flutter, c'est l'authentification native du broker
MQTT (HiveMQ Cloud).

=============================================================
REPARTITION DE LA LOGIQUE (repond au point 7 de la liste GE)
=============================================================
CONFIRME : l'ESP32 execute uniquement les commandes recues et
remonte les donnees brutes des capteurs. Aucune decision d'irrigation
n'est prise localement sur l'ESP32 -- tout le calcul (meteo, Kc/ETc,
prediction d'humidite) se fait cote backend Django, dans
irrigation/decision_engine.py.

=============================================================
FREQUENCE DE REMONTEE DES DONNEES (repond au point 8 de la liste GE)
=============================================================
Deux frequences DISTINCTES et configurables separement cote firmware :
- Verification retour reseau (si en mode secours AP) : 2 minutes
- Envoi des lectures capteurs (mode normal) : 5 minutes par defaut
  (voir INTERVALLE_ENVOI_DONNEES_MS dans le firmware -- ajustable
  selon vos besoins reels sur le terrain)

=============================================================
GESTION DU BROKER MQTT (repond au point 6 de la liste GE)
=============================================================
A CONFIRMER AVEC L'EQUIPE : recommandation par defaut, Chalom (toi)
cree le compte HiveMQ Cloud en tant que responsable de la partie
materielle/reseau, et partage les identifiants avec le GE via un
canal securise (ex: gestionnaire de mots de passe partage, jamais
par SMS/WhatsApp en clair). A valider ensemble avant de communiquer
au GE.
"""

import json
import os
from datetime import timedelta

import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartwater_backend.settings')

import paho.mqtt.client as mqtt
from django.conf import settings


def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("[MQTT] Connecte au broker.")
        client.subscribe("smartwater/+/capteurs")
        client.subscribe("smartwater/+/capteurs_differe")
        client.subscribe("smartwater/+/status")
    else:
        print(f"[MQTT] Echec de connexion, code {rc}")


def _traiter_lecture(device, zone_code, humidite_pct, temperature_c, horodatage=None):
    """Enregistre une lecture pour la zone correspondant a zone_code, et
    declenche le moteur de decision. Reutilise pour le temps reel ET
    pour la synchronisation differee (mode hors-ligne)."""
    django.setup()
    from core.models import Capteur, LectureCapteur, Zone
    from irrigation.decision_engine import prendre_decision

    try:
        zone = Zone.objects.get(code_terrain=zone_code)
    except Zone.DoesNotExist:
        print(f"[MQTT] zone_code inconnu : {zone_code} -- verifie le Django Admin.")
        return

    capteur = Capteur.objects.filter(zone=zone, type_capteur='humidite_temperature').first()
    if not capteur:
        print(f"[MQTT] Aucun capteur humidite/temperature configure pour la zone {zone_code}")
        return

    capteur.derniere_humidite_pct = humidite_pct
    capteur.derniere_temperature_c = temperature_c
    capteur.save()

    LectureCapteur.objects.create(
        capteur=capteur,
        humidite_pct=humidite_pct,
        temperature_c=temperature_c,
    )

    if humidite_pct is not None:
        prendre_decision(zone, humidite_pct=humidite_pct, temperature_c=temperature_c or 28.0)


def on_message(client, userdata, msg):
    django.setup()
    from core.models import Device
    from django.utils import timezone

    topic_parts = msg.topic.split('/')
    if len(topic_parts) < 3:
        return
    device_id = topic_parts[1]
    canal = topic_parts[2]

    try:
        payload = json.loads(msg.payload.decode())
    except json.JSONDecodeError:
        print(f"[MQTT] Message invalide recu sur {msg.topic}")
        return

    try:
        device = Device.objects.get(identifiant=device_id)
    except Device.DoesNotExist:
        print(f"[MQTT] Device inconnu : {device_id} -- l'as-tu bien enregistre dans le Django Admin ?")
        return

    if canal == 'capteurs':
        device.mode_connexion = 'mqtt'
        device.derniere_communication = timezone.now()
        device.save(update_fields=['mode_connexion', 'derniere_communication'])

        # payload attendu : tableau [{"zone_code": "Z1", "humidite_pct":.., "temperature_c":..}, ...]
        for lecture in payload:
            _traiter_lecture(
                device, lecture.get('zone_code'),
                lecture.get('humidite_pct'), lecture.get('temperature_c'),
            )

    elif canal == 'capteurs_differe':
        # Synchronisation des mesures accumulees pendant une coupure reseau.
        # On reconstitue l'horodatage reel a partir de "il_y_a_secondes".
        maintenant = timezone.now()
        for lecture in payload:
            il_y_a = lecture.get('il_y_a_secondes', 0)
            horodatage_reel = maintenant - timedelta(seconds=il_y_a)
            _traiter_lecture(
                device, lecture.get('zone_code'),
                lecture.get('humidite_pct'), lecture.get('temperature_c'),
                horodatage=horodatage_reel,
            )
        print(f"[MQTT] {len(payload)} lecture(s) differee(s) synchronisee(s) pour {device_id}")

    elif canal == 'status':
        device.niveau_batterie_pct = payload.get('batterie_pct')
        device.save(update_fields=['niveau_batterie_pct'])


def envoyer_commande_vanne(zone, ouverture: bool, duree_minutes: float = None):
    """
    Publie une commande MQTT pour ouvrir/fermer la vanne d'une zone.
    Le payload inclut zone_code pour que l'ESP32 sache quelle vanne
    physique actionner (un device peut en piloter plusieurs).
    """
    try:
        vanne = zone.vanne
        device = vanne.device
    except Exception:
        print(f"[MQTT] Aucune vanne configuree pour la zone {zone}")
        return

    client = mqtt.Client()
    client.username_pw_set(settings.MQTT_USERNAME, settings.MQTT_PASSWORD)
    client.tls_set()
    client.connect(settings.MQTT_BROKER_HOST, settings.MQTT_BROKER_PORT)

    payload = json.dumps({
        'zone_code': zone.code_terrain,
        'vanne': 'ouvrir' if ouverture else 'fermer',
        'duree_minutes': duree_minutes,
    })
    client.publish(f"smartwater/{device.identifiant}/commande", payload)
    client.disconnect()

    vanne.etat = 'ouverte' if ouverture else 'fermee'
    from django.utils import timezone
    if ouverture:
        vanne.derniere_ouverture = timezone.now()
    vanne.save()


def demarrer_listener():
    """Lance le listener MQTT en continu (boucle bloquante)."""
    client = mqtt.Client()
    client.username_pw_set(settings.MQTT_USERNAME, settings.MQTT_PASSWORD)
    client.tls_set()
    client.on_connect = on_connect
    client.on_message = on_message

    client.connect(settings.MQTT_BROKER_HOST, settings.MQTT_BROKER_PORT)
    client.loop_forever()


if __name__ == '__main__':
    demarrer_listener()
