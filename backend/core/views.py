"""
Vues de l'API SmartWater -- ce sont les endpoints que l'app Flutter
appelle. Voir core/urls.py pour la liste complete des routes.
"""

from datetime import date, timedelta

from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Parcelle, Zone, DemandeRattachement, DecisionIrrigation
from .serializers import (
    ParcelleSerializer, ZoneSerializer, DemandeRattachementSerializer,
    DecisionIrrigationSerializer,
)
from irrigation.water_savings import generer_rapport_economie_eau


class MesParcellesView(generics.ListAPIView):
    """
    GET /api/parcelles/
    Retourne les parcelles de l'utilisateur connecte.
    Si l'utilisateur n'a aucune parcelle, retourne une liste vide --
    c'est l'app Flutter qui affiche alors l'ecran "Aucune parcelle
    associee" avec le bouton de demande de rattachement.
    """
    serializer_class = ParcelleSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Parcelle.objects.filter(proprietaire=self.request.user)


class DemandeRattachementCreateView(generics.CreateAPIView):
    """
    POST /api/demandes-rattachement/
    L'agriculteur soumet une demande manuelle pour etre rattache a
    une parcelle. Elle sera visible et validee par l'agronome dans
    le Django Admin.
    """
    serializer_class = DemandeRattachementSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(utilisateur=self.request.user)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def demarrer_irrigation_manuelle(request, zone_id):
    """
    POST /api/zones/<id>/irrigation-manuelle/
    Corps attendu : {"duree_minutes": 20}

    Declenche l'irrigation manuelle demandee par l'agriculteur depuis
    l'app (ecran Controle).
    """
    try:
        zone = Zone.objects.get(id=zone_id, parcelle__proprietaire=request.user)
    except Zone.DoesNotExist:
        return Response({'erreur': 'Zone introuvable ou acces non autorise.'}, status=status.HTTP_404_NOT_FOUND)

    duree_minutes = request.data.get('duree_minutes', 15)

    from mqtt_client.mqtt_listener import envoyer_commande_vanne
    envoyer_commande_vanne(zone, ouverture=True, duree_minutes=duree_minutes)

    decision = DecisionIrrigation.objects.create(
        zone=zone,
        decision='irrigation_manuelle',
        duree_minutes=duree_minutes,
        explication=f"Irrigation manuelle demarree par {request.user}.",
    )
    return Response(DecisionIrrigationSerializer(decision).data, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def arreter_irrigation(request, zone_id):
    """POST /api/zones/<id>/arreter-irrigation/"""
    try:
        zone = Zone.objects.get(id=zone_id, parcelle__proprietaire=request.user)
    except Zone.DoesNotExist:
        return Response({'erreur': 'Zone introuvable.'}, status=status.HTTP_404_NOT_FOUND)

    from mqtt_client.mqtt_listener import envoyer_commande_vanne
    envoyer_commande_vanne(zone, ouverture=False)
    return Response({'statut': 'vanne fermee'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def rapport_economie_eau(request, zone_id):
    """
    GET /api/zones/<id>/rapport-eau/?jours=30
    Retourne le rapport d'economie d'eau chiffre pour l'ecran dedie.
    """
    try:
        zone = Zone.objects.get(id=zone_id, parcelle__proprietaire=request.user)
    except Zone.DoesNotExist:
        return Response({'erreur': 'Zone introuvable.'}, status=status.HTTP_404_NOT_FOUND)

    nb_jours = int(request.query_params.get('jours', 30))
    periode_fin = date.today()
    periode_debut = periode_fin - timedelta(days=nb_jours)

    rapport = generer_rapport_economie_eau(zone, periode_debut, periode_fin)
    return Response(rapport)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def historique_capteur(request, zone_id):
    """
    GET /api/zones/<id>/historique/?jours=7
    Retourne l'historique des lectures capteur pour le graphique
    d'humidite (moyenne/max/min) de l'ecran Capteurs.
    """
    from django.db.models import Avg, Max, Min
    from .models import LectureCapteur

    try:
        zone = Zone.objects.get(id=zone_id, parcelle__proprietaire=request.user)
    except Zone.DoesNotExist:
        return Response({'erreur': 'Zone introuvable.'}, status=status.HTTP_404_NOT_FOUND)

    nb_jours = int(request.query_params.get('jours', 7))
    depuis = date.today() - timedelta(days=nb_jours)

    lectures = LectureCapteur.objects.filter(
        capteur__zone=zone, horodatage__date__gte=depuis
    ).order_by('horodatage')

    stats = lectures.aggregate(moyenne=Avg('humidite_pct'), max=Max('humidite_pct'), min=Min('humidite_pct'))

    return Response({
        'lectures': [
            {'heure': l.horodatage, 'humidite_pct': l.humidite_pct, 'temperature_c': l.temperature_c}
            for l in lectures
        ],
        'statistiques': stats,
    })
