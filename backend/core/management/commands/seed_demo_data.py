"""
Genere un jeu de donnees fictives realistes pour le compte demo
(presentation au jury), comme valide ensemble.

Usage : python manage.py seed_demo_data

Cree :
- Un utilisateur demo (role='demo'), a associer au numero de test
  configure dans Supabase (voir docs/DEPLOIEMENT.md, section
  "Configurer les numeros de test OTP")
- Une parcelle avec 2 zones (tomate + mais)
- Un historique de lectures capteur sur 30 jours
- Des decisions d'irrigation passees
- Un rapport d'economie d'eau deja rempli
"""

import random
from datetime import date, timedelta, datetime

from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import (
    Utilisateur, Parcelle, Culture, Zone, Device, Capteur,
    LectureCapteur, Vanne, DecisionIrrigation, RapportEconomieEau,
)


class Command(BaseCommand):
    help = "Genere des donnees de demonstration pour le compte jury"

    def handle(self, *args, **options):
        # --- Utilisateur demo ---
        # A CHANGER : remplace ce numero par celui que tu configures
        # comme numero de test OTP dans Supabase pour le compte jury.
        demo_user, _ = Utilisateur.objects.get_or_create(
            supabase_user_id='demo-jury-uuid-a-remplacer',
            defaults={'telephone': '+22890000000', 'nom': 'Compte Demo (Jury)', 'role': 'demo'},
        )

        # --- Cultures de reference (valeurs Kc standards FAO-56) ---
        tomate, _ = Culture.objects.get_or_create(
            nom='Tomate',
            defaults=dict(kc_initial=0.5, kc_developpement=0.75, kc_mi_saison=1.15, kc_maturation=0.8,
                          duree_phase_initiale_jours=20, duree_phase_developpement_jours=25,
                          duree_phase_mi_saison_jours=35, duree_phase_maturation_jours=20,
                          seuil_humidite_min_pct=45, seuil_humidite_max_pct=70),
        )
        mais, _ = Culture.objects.get_or_create(
            nom='Mais',
            defaults=dict(kc_initial=0.4, kc_developpement=0.7, kc_mi_saison=1.2, kc_maturation=0.6,
                          duree_phase_initiale_jours=15, duree_phase_developpement_jours=30,
                          duree_phase_mi_saison_jours=40, duree_phase_maturation_jours=25,
                          seuil_humidite_min_pct=40, seuil_humidite_max_pct=65),
        )

        # --- Parcelle et zones ---
        parcelle, _ = Parcelle.objects.get_or_create(
            proprietaire=demo_user, nom='Parcelle demo - Aneho',
            defaults=dict(localisation='Aneho', latitude=6.2333, longitude=1.6000),
        )

        zone1, _ = Zone.objects.get_or_create(
            parcelle=parcelle, nom='Zone 1 - Tomate',
            defaults=dict(culture=tomate, superficie_m2=120, date_semis=date.today() - timedelta(days=45)),
        )
        zone2, _ = Zone.objects.get_or_create(
            parcelle=parcelle, nom='Zone 2 - Mais',
            defaults=dict(culture=mais, superficie_m2=200, date_semis=date.today() - timedelta(days=25)),
        )

        # --- Materiel (device, capteurs, vannes) ---
        device, _ = Device.objects.get_or_create(
            identifiant='ESP32-DEMO-01',
            defaults=dict(zone=zone1, mode_connexion='mqtt', niveau_batterie_pct=87,
                          derniere_communication=timezone.now()),
        )

        for zone in (zone1, zone2):
            Capteur.objects.get_or_create(
                device=device, zone=zone, type_capteur='humidite_temperature',
                defaults=dict(derniere_humidite_pct=random.uniform(45, 60),
                              derniere_temperature_c=random.uniform(26, 30),
                              derniere_lecture=timezone.now()),
            )
            Vanne.objects.get_or_create(
                device=device, zone=zone,
                defaults=dict(etat='fermee', debit_theorique_l_min=15.0),
            )

        # --- Historique de lectures sur 30 jours ---
        capteur1 = Capteur.objects.filter(zone=zone1).first()
        for jours_passes in range(30, 0, -1):
            horodatage = timezone.now() - timedelta(days=jours_passes)
            humidite = random.uniform(38, 65)
            LectureCapteur.objects.create(
                capteur=capteur1,
                humidite_pct=round(humidite, 1),
                temperature_c=round(random.uniform(25, 31), 1),
                horodatage=horodatage,
            )

        # --- Decisions d'irrigation passees (pour l'historique) ---
        for jours_passes in range(10, 0, -1):
            humidite = random.uniform(35, 55)
            decision_type = 'irrigation' if humidite < 45 else 'aucune'
            DecisionIrrigation.objects.create(
                zone=zone1,
                humidite_mesuree_pct=round(humidite, 1),
                pluie_prevue_mm=round(random.uniform(0, 5), 1),
                etc_calcule_mm=round(random.uniform(3, 7), 1),
                volume_irrigue_estime_l=round(random.uniform(50, 150), 1) if decision_type == 'irrigation' else None,
                duree_minutes=round(random.uniform(5, 15), 1) if decision_type == 'irrigation' else None,
                decision=decision_type,
                explication="Donnee generee pour la demonstration.",
            )

        # --- Rapport d'economie d'eau ---
        RapportEconomieEau.objects.get_or_create(
            zone=zone1,
            periode_debut=date.today() - timedelta(days=30),
            periode_fin=date.today(),
            defaults=dict(
                volume_utilise_estime_l=2140,
                volume_reference_manuel_l=3520,
                pourcentage_economise=39.2,
            ),
        )

        self.stdout.write(self.style.SUCCESS(
            "Donnees de demonstration generees avec succes.\n"
            "N'oublie pas d'associer le compte demo au bon numero de "
            "telephone de test dans Supabase (voir docs/DEPLOIEMENT.md)."
        ))
