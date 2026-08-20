"""
Serializers Django REST Framework : convertissent les modeles en
JSON pour l'app Flutter, et inversement.
"""

from rest_framework import serializers
from .models import (
    Utilisateur, DemandeRattachement, Parcelle, Culture, Zone,
    Device, Capteur, LectureCapteur, Vanne, DecisionIrrigation,
    Alerte, RapportEconomieEau,
)


class CultureSerializer(serializers.ModelSerializer):
    class Meta:
        model = Culture
        fields = '__all__'


class VanneSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vanne
        fields = ('id', 'etat', 'debit_theorique_l_min', 'derniere_ouverture')


class CapteurSerializer(serializers.ModelSerializer):
    class Meta:
        model = Capteur
        fields = ('id', 'type_capteur', 'derniere_humidite_pct', 'derniere_temperature_c', 'derniere_lecture')


class ZoneSerializer(serializers.ModelSerializer):
    culture = CultureSerializer(read_only=True)
    vanne = VanneSerializer(read_only=True)
    capteurs = CapteurSerializer(many=True, read_only=True)
    phase_actuelle = serializers.SerializerMethodField()

    class Meta:
        model = Zone
        fields = ('id', 'nom', 'culture', 'superficie_m2', 'date_semis',
                  'vanne', 'capteurs', 'phase_actuelle')

    def get_phase_actuelle(self, obj):
        phase, kc = obj.phase_actuelle()
        return {'phase': phase, 'kc': kc}


class ParcelleSerializer(serializers.ModelSerializer):
    zones = ZoneSerializer(many=True, read_only=True)

    class Meta:
        model = Parcelle
        fields = ('id', 'nom', 'localisation', 'latitude', 'longitude', 'zones')


class DemandeRattachementSerializer(serializers.ModelSerializer):
    class Meta:
        model = DemandeRattachement
        fields = ('id', 'nom_parcelle_indique', 'localisation_indiquee', 'statut', 'date_creation')
        read_only_fields = ('statut', 'date_creation')


class LectureCapteurSerializer(serializers.ModelSerializer):
    class Meta:
        model = LectureCapteur
        fields = ('humidite_pct', 'temperature_c', 'horodatage')


class DecisionIrrigationSerializer(serializers.ModelSerializer):
    class Meta:
        model = DecisionIrrigation
        fields = '__all__'


class AlerteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Alerte
        fields = '__all__'


class RapportEconomieEauSerializer(serializers.ModelSerializer):
    class Meta:
        model = RapportEconomieEau
        fields = '__all__'
