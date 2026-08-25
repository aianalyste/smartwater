"""
Verifie toutes les Zones ayant une decision d'irrigation en attente
depuis plus d'1h sans action manuelle, et declenche automatiquement
l'irrigation (point 3 : mode automatique).

A EXECUTER PERIODIQUEMENT (toutes les 10-15 min) via un Cron Job
Render -- voir docs/DEPLOIEMENT.md pour la configuration.

Usage : python manage.py verifier_irrigation_auto
"""

from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import Zone, DecisionIrrigation


class Command(BaseCommand):
    help = "Declenche automatiquement l'irrigation si aucune action manuelle apres 1h"

    DELAI_AUTO = timedelta(minutes=2)
    

    def handle(self, *args, **options):
        seuil = timezone.now() - self.DELAI_AUTO

        decisions_en_attente = DecisionIrrigation.objects.filter(
            decision='irrigation',
            date_heure__lte=seuil,
            date_heure__gte=seuil - timedelta(minutes=30),
        )

        for decision in decisions_en_attente:
            zone = decision.zone

            # Verifie si une action manuelle ou auto a deja eu lieu APRES cette decision
            action_deja_faite = DecisionIrrigation.objects.filter(
                zone=zone,
                decision__in=['irrigation_manuelle', 'irrigation_automatique'],
                date_heure__gt=decision.date_heure,
            ).exists()

            if action_deja_faite:
                continue

            from irrigation.water_savings import estimer_volume_irrigation
            from mqtt_client.mqtt_listener import envoyer_commande_vanne

            volume_l, duree_min = estimer_volume_irrigation(zone, decision.etc_calcule_mm or 5.0)
            envoyer_commande_vanne(zone, ouverture=True, duree_minutes=duree_min)

            DecisionIrrigation.objects.create(
                zone=zone,
                decision='irrigation_automatique',
                volume_irrigue_estime_l=volume_l,
                duree_minutes=duree_min,
                explication=(
                    f"Irrigation declenchee automatiquement (delai depasse sans action manuelle, "
                    f"decision initiale du {decision.date_heure:%d/%m %H:%M})."
                ),
            )

            self.stdout.write(self.style.SUCCESS(f"Irrigation auto declenchee pour {zone.nom}"))

        self.stdout.write(f"Verification terminee : {decisions_en_attente.count()} decision(s) examinee(s).")