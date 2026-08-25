"""
Routes de l'API SmartWater. Prefixe deja applique : /api/
(voir smartwater_backend/urls.py)
"""

from django.urls import path
from . import views

urlpatterns = [
    path('inscription/', views.inscription_ou_connexion, name='inscription'),
    path('parcelles/', views.MesParcellesView.as_view(), name='mes-parcelles'),
    path('demandes-rattachement/', views.DemandeRattachementCreateView.as_view(), name='demande-rattachement'),
    path('zones/<int:zone_id>/irrigation-manuelle/', views.demarrer_irrigation_manuelle, name='irrigation-manuelle'),
    path('zones/<int:zone_id>/arreter-irrigation/', views.arreter_irrigation, name='arreter-irrigation'),
    path('zones/<int:zone_id>/rapport-eau/', views.rapport_economie_eau, name='rapport-eau'),
    path('zones/<int:zone_id>/historique/', views.historique_capteur, name='historique-capteur'),
    path('zones/<int:zone_id>/meteo/', views.previsions_meteo, name='previsions-meteo'),
    path('zones/<int:zone_id>/decision/', views.decision_actuelle, name='decision-actuelle'),
    path('cron/verifier-irrigation/', views.cron_verifier_irrigation_auto, name='cron-verifier-irrigation'),
]