"""
Configuration du Django Admin -- c'est l'interface qu'utiliseront
l'agronome/admin pour valider les demandes de rattachement, gerer
les parcelles, et consulter toutes les donnees sans avoir besoin
de coder un ecran dedie.

Accessible a l'adresse : http://<ton-serveur>/admin/
(voir docs/DEPLOIEMENT.md pour creer le premier compte admin)
"""

from django.contrib import admin
from .models import (
    Utilisateur, DemandeRattachement, Parcelle, Culture, Zone,
    Device, Capteur, LectureCapteur, Vanne, DecisionIrrigation,
    Alerte, RapportEconomieEau,
)


@admin.register(Utilisateur)
class UtilisateurAdmin(admin.ModelAdmin):
    list_display = ('nom', 'telephone', 'role', 'date_creation')
    list_filter = ('role',)
    search_fields = ('nom', 'telephone')


@admin.register(DemandeRattachement)
class DemandeRattachementAdmin(admin.ModelAdmin):
    """
    C'est ici que l'agronome valide ou refuse une demande d'un
    agriculteur : ouvrir la demande, choisir la parcelle a lier
    dans le champ "parcelle_liee", puis changer le statut a "validee".
    """
    list_display = ('utilisateur', 'nom_parcelle_indique', 'statut', 'date_creation')
    list_filter = ('statut',)
    actions = ['valider_demandes']

    @admin.action(description="Valider les demandes selectionnees")
    def valider_demandes(self, request, queryset):
        from django.utils import timezone
        queryset.update(statut='validee', date_traitement=timezone.now())


@admin.register(Parcelle)
class ParcelleAdmin(admin.ModelAdmin):
    list_display = ('nom', 'localisation', 'proprietaire')
    search_fields = ('nom', 'localisation')


@admin.register(Culture)
class CultureAdmin(admin.ModelAdmin):
    list_display = ('nom', 'kc_initial', 'kc_developpement', 'kc_mi_saison', 'kc_maturation')


@admin.register(Zone)
class ZoneAdmin(admin.ModelAdmin):
    list_display = ('nom', 'code_terrain', 'parcelle', 'culture', 'date_semis')
    list_filter = ('culture',)


@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = ('identifiant', 'zone', 'mode_connexion', 'derniere_communication')
    list_filter = ('mode_connexion',)


@admin.register(Capteur)
class CapteurAdmin(admin.ModelAdmin):
    list_display = ('type_capteur', 'zone', 'derniere_humidite_pct', 'derniere_lecture')


admin.site.register(LectureCapteur)


@admin.register(Vanne)
class VanneAdmin(admin.ModelAdmin):
    list_display = ('zone', 'etat', 'debit_theorique_l_min')


@admin.register(DecisionIrrigation)
class DecisionIrrigationAdmin(admin.ModelAdmin):
    list_display = ('zone', 'decision', 'humidite_mesuree_pct', 'date_heure')
    list_filter = ('decision',)


@admin.register(Alerte)
class AlerteAdmin(admin.ModelAdmin):
    list_display = ('type_alerte', 'zone', 'canal', 'envoyee', 'date_creation')
    list_filter = ('type_alerte', 'canal', 'envoyee')


@admin.register(RapportEconomieEau)
class RapportEconomieEauAdmin(admin.ModelAdmin):
    list_display = ('zone', 'periode_debut', 'periode_fin', 'pourcentage_economise')
