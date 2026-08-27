"""
Rafraichit le cache meteo (14 jours + 24h) pour toutes les parcelles.
A executer periodiquement (toutes les 3h) via le cron externe gratuit,
comme verifier_irrigation_auto.

Usage : python manage.py rafraichir_meteo
"""

from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import Parcelle
from irrigation.weather import get_previsions_quotidiennes_2_semaines, get_previsions_pluie


class Command(BaseCommand):
    help = "Rafraichit le cache meteo pour toutes les parcelles"

    def handle(self, *args, **options):
        compteur = 0
        for parcelle in Parcelle.objects.all():
            meteo_14j = get_previsions_quotidiennes_2_semaines(parcelle.latitude, parcelle.longitude)

            previsions_24h = get_previsions_pluie(parcelle.latitude, parcelle.longitude, heures=24)
            # Convertit les datetime en texte pour pouvoir les stocker en JSON
            meteo_24h = [
                {'heure': p['heure'].isoformat(), 'pluie_mm': p['pluie_mm'], 'probabilite_pct': p['probabilite_pct']}
                for p in previsions_24h
            ]

            parcelle.meteo_cache_14j = meteo_14j
            parcelle.meteo_cache_24h = meteo_24h
            parcelle.meteo_cache_maj_le = timezone.now()
            parcelle.save(update_fields=['meteo_cache_14j', 'meteo_cache_24h', 'meteo_cache_maj_le'])
            compteur += 1

        self.stdout.write(self.style.SUCCESS(f"Cache meteo rafraichi pour {compteur} parcelle(s)."))