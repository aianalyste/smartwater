"""
Genere des donnees historiques artificielles pour le compte de test
'aer' (93042517), afin de pouvoir tester toutes les fonctionnalites
(courbes, stats, prediction) sans attendre les vrais capteurs.

Usage : python manage.py generer_donnees_test_aer
"""

import random
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import Utilisateur, LectureCapteur, DecisionIrrigation


class Command(BaseCommand):
    help = "Genere des donnees de test pour le compte aer (93042517)"

    def handle(self, *args, **options):
        try:
            utilisateur = Utilisateur.objects.get(telephone='93042517')
        except Utilisateur.DoesNotExist:
            self.stdout.write(self.style.ERROR("Compte 93042517 introuvable."))
            return

        parcelle = utilisateur.parcelles.first()
        if not parcelle:
            self.stdout.write(self.style.ERROR("Aucune parcelle pour ce compte."))
            return

        zone = parcelle.zones.first()
        capteur = zone.capteurs.filter(type_capteur='humidite_temperature').first()
        if not capteur:
            self.stdout.write(self.style.ERROR("Aucun capteur humidite/temperature pour cette zone."))
            return

        humidite = 60.0
        maintenant = timezone.now()

        for jours_passes in range(30, 0, -1):
            for heure in [6, 12, 18, 23]:
                horodatage = maintenant - timedelta(days=jours_passes) + timedelta(hours=heure)

                humidite -= random.uniform(0.5, 1.5)
                if random.random() < 0.15:
                    humidite += random.uniform(15, 30)
                humidite = max(20, min(75, humidite))
                temperature = round(random.uniform(25, 32), 1)

                LectureCapteur.objects.create(
                    capteur=capteur,
                    humidite_pct=round(humidite, 1),
                    temperature_c=temperature,
                    horodatage=horodatage,
                )

        derniere = LectureCapteur.objects.filter(capteur=capteur).order_by('-horodatage').first()
        capteur.derniere_humidite_pct = derniere.humidite_pct
        capteur.derniere_temperature_c = derniere.temperature_c
        capteur.derniere_lecture = derniere.horodatage
        capteur.save()

        for jours_passes in range(10, 0, -1):
            humidite_test = random.uniform(30, 55)
            decision_type = 'irrigation' if humidite_test < 40 else 'aucune'
            DecisionIrrigation.objects.create(
                zone=zone,
                humidite_mesuree_pct=round(humidite_test, 1),
                pluie_prevue_mm=round(random.uniform(0, 5), 1),
                etc_calcule_mm=round(random.uniform(3, 7), 1),
                volume_irrigue_estime_l=round(random.uniform(50, 150), 1) if decision_type == 'irrigation' else None,
                duree_minutes=round(random.uniform(5, 15), 1) if decision_type == 'irrigation' else None,
                decision=decision_type,
                explication="Donnee generee pour test (compte aer).",
            )

        self.stdout.write(self.style.SUCCESS(
            f"Donnees generees : {LectureCapteur.objects.filter(capteur=capteur).count()} lectures, "
            f"{DecisionIrrigation.objects.filter(zone=zone).count()} decisions pour la zone {zone.nom}."
        ))