"""
Commande Django pour lancer le listener MQTT.
Usage : python manage.py run_mqtt_listener

A garder actif en permanence en production (voir docs/DEPLOIEMENT.md,
section "Garder les services actifs" -- on recommande d'utiliser un
outil comme systemd ou supervisor pour le redemarrer automatiquement
s'il plante).
"""
from django.core.management.base import BaseCommand
from mqtt_client.mqtt_listener import demarrer_listener


class Command(BaseCommand):
    help = "Demarre le listener MQTT qui recoit les donnees des ESP32"

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS("Demarrage du listener MQTT SmartWater..."))
        demarrer_listener()
