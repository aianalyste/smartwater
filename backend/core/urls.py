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
    path('alertes/', views.mes_alertes, name='mes-alertes'),
    # --- Onglet Options (admin/agronome) ---
    path('options/cultures/', views.AdminCultureListeView.as_view(), name='admin-cultures'),
    path('options/cultures/<int:pk>/', views.AdminCultureDetailView.as_view(), name='admin-culture-detail'),
    path('options/parcelles/', views.AdminParcelleListeView.as_view(), name='admin-parcelles'),
    path('options/parcelles/<int:pk>/', views.AdminParcelleDetailView.as_view(), name='admin-parcelle-detail'),
    path('options/zones/', views.AdminZoneListeView.as_view(), name='admin-zones'),
    path('options/zones/<int:pk>/', views.AdminZoneDetailView.as_view(), name='admin-zone-detail'),
    path('options/utilisateurs/', views.AdminUtilisateurListeView.as_view(), name='admin-utilisateurs'),
    path('options/utilisateurs/<int:pk>/', views.AdminUtilisateurDetailView.as_view(), name='admin-utilisateur-detail'),
    path('options/devices/', views.AdminDeviceListeView.as_view(), name='admin-devices'),
    path('options/capteurs/', views.AdminCapteurListeView.as_view(), name='admin-capteurs'),
    path('options/vannes/', views.AdminVanneListeView.as_view(), name='admin-vannes'),
    path('options/demandes/', views.AdminDemandesEnAttenteView.as_view(), name='admin-demandes'),
    path('options/demandes/<int:demande_id>/valider/', views.valider_demande, name='valider-demande'),
    path('options/demandes/<int:demande_id>/refuser/', views.refuser_demande, name='refuser-demande'),
    path('cron/rafraichir-meteo/', views.cron_rafraichir_meteo, name='cron-rafraichir-meteo'),
    path('zones/<int:zone_id>/comparaison-decisions/', views.comparaison_decisions, name='comparaison-decisions'),
]