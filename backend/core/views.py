"""
Vues de l'API SmartWater -- ce sont les endpoints que l'app Flutter
appelle. Voir core/urls.py pour la liste complete des routes.
"""

from datetime import date, timedelta

from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

from .models import Parcelle, Zone, DemandeRattachement, DecisionIrrigation, Utilisateur, Culture
from .serializers import (
    CultureSerializer, ParcelleSerializer, ZoneSerializer, DemandeRattachementSerializer,
    DecisionIrrigationSerializer, UtilisateurSerializer,
)
from irrigation.water_savings import generer_rapport_economie_eau

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def decision_actuelle(request, zone_id):
    """GET /api/zones/<id>/decision/ — bloc Decision complet (point 2)."""
    from irrigation.weather import get_previsions_quotidiennes_2_semaines
    from irrigation.fao56 import calculer_etc

    try:
        zone = Zone.objects.get(id=zone_id, parcelle__proprietaire=request.user)
    except Zone.DoesNotExist:
        return Response({'erreur': 'Zone introuvable.'}, status=status.HTTP_404_NOT_FOUND)

    capteur = zone.capteurs.filter(type_capteur='humidite_temperature').first()
    capteurs_data = None
    if capteur and capteur.derniere_humidite_pct is not None:
        capteurs_data = {
            'humidite_pct': capteur.derniere_humidite_pct,
            'temperature_c': capteur.derniere_temperature_c,
        }

    temperature = capteurs_data['temperature_c'] if capteurs_data else 28.0
    etc_mm, phase, kc = calculer_etc(zone, temperature)

    parcelle = zone.parcelle
        # Utilise le cache si disponible et recent (moins de 12h), sinon appel direct en secours
    from django.utils import timezone as django_timezone
    from datetime import timedelta as td

    cache_valide = (
        parcelle.meteo_cache_14j and
        isinstance(parcelle.meteo_cache_14j, list) and
        parcelle.meteo_cache_maj_le and
        parcelle.meteo_cache_maj_le > django_timezone.now() - td(hours=12)
    )
    if cache_valide:
        meteo_14j = parcelle.meteo_cache_14j
    else:
        meteo_14j = get_previsions_quotidiennes_2_semaines(parcelle.latitude, parcelle.longitude)

    prediction_humidite = []
    if capteur:
        from irrigation.prediction_tendance import predire_humidite_future
        prediction_humidite = predire_humidite_future(capteur, jours=5)

    derniere_decision = DecisionIrrigation.objects.filter(zone=zone).order_by('-date_heure').first()

    date_decision_iso = None
    delai_auto_secondes = None

    if capteurs_data is None:
        decision = 'indisponible'
        explication = "Pas de donnees capteurs -- decision impossible pour l'instant."
    elif derniere_decision and derniere_decision.decision == 'irrigation':
        # Decision en attente d'action -> le compte a rebours auto commence ici
        decision = 'oui'
        explication = derniere_decision.explication
        date_decision_iso = derniere_decision.date_heure.isoformat()
        delai_auto_secondes = 120  # 2 minutes pour le test -- A CHANGER en 3600 (1h) pour la prod
    elif derniere_decision and derniere_decision.decision in ('irrigation_manuelle', 'irrigation_automatique'):
        decision = 'oui'
        explication = derniere_decision.explication
    else:
        decision = 'non'
        explication = derniere_decision.explication if derniere_decision else "Humidite suffisante, pas d'irrigation necessaire."

    return Response({
        'capteurs': capteurs_data,
        'phase': phase,
        'kc': kc,
        'etc_mm': etc_mm,
        'meteo_14j': meteo_14j,
        'prediction_humidite': prediction_humidite,
        'decision': decision,
        'explication': explication,
        'date_decision': date_decision_iso,
        'delai_auto_secondes': delai_auto_secondes,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def previsions_meteo(request, zone_id):
    """GET /api/zones/<id>/meteo/ — prévisions de pluie pour la parcelle (utilise le cache)."""
    from django.utils import timezone as django_timezone
    from datetime import timedelta as td

    try:
        zone = Zone.objects.get(id=zone_id, parcelle__proprietaire=request.user)
    except Zone.DoesNotExist:
        return Response({'erreur': 'Zone introuvable.'}, status=status.HTTP_404_NOT_FOUND)

    parcelle = zone.parcelle

    cache_valide = (
        parcelle.meteo_cache_24h and
        isinstance(parcelle.meteo_cache_24h, list) and
        parcelle.meteo_cache_maj_le and
        parcelle.meteo_cache_maj_le > django_timezone.now() - td(hours=12)
    )
    if cache_valide:
        previsions = parcelle.meteo_cache_24h
    else:
        from irrigation.weather import get_previsions_pluie
        brut = get_previsions_pluie(parcelle.latitude, parcelle.longitude, heures=24)
        previsions = [{'heure': p['heure'].isoformat(), 'pluie_mm': p['pluie_mm'], 'probabilite_pct': p['probabilite_pct']} for p in brut]

    prochaine = next((p for p in previsions if p['pluie_mm'] >= 2.0), None)

    return Response({
        'pluie_prevue': prochaine is not None,
        'heure': prochaine['heure'] if prochaine else None,
        'volume_mm': prochaine['pluie_mm'] if prochaine else 0,
    })

@api_view(['POST'])
@permission_classes([AllowAny])
def inscription_ou_connexion(request):
    """
    POST /api/inscription/
    Corps attendu : {"nom": "...", "telephone": "...", "ville": "...", "localite": "..."}
    """
    telephone = request.data.get('telephone', '').strip()
    if not telephone:
        return Response({'erreur': 'Le numero de telephone est requis.'}, status=status.HTTP_400_BAD_REQUEST)

    utilisateur, cree = Utilisateur.objects.get_or_create(
        telephone=telephone,
        defaults={
            'nom': request.data.get('nom', ''),
            'ville': request.data.get('ville', ''),
            'localite': request.data.get('localite', ''),
        },
    )
    if not cree:
        utilisateur.nom = request.data.get('nom', utilisateur.nom)
        utilisateur.ville = request.data.get('ville', utilisateur.ville)
        utilisateur.localite = request.data.get('localite', utilisateur.localite)
        utilisateur.save()

    return Response(UtilisateurSerializer(utilisateur).data, status=status.HTTP_200_OK)

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


@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def cron_verifier_irrigation_auto(request):
    """
    GET /api/cron/verifier-irrigation/?cle=XXXX

    Endpoint appele periodiquement par un service externe gratuit
    (cron-job.org) pour declencher la verification du mode automatique
    -- alternative gratuite au Cron Job payant de Render.

    Protege par une cle secrete simple dans l'URL (pas une vraie
    authentification, mais suffisant pour eviter les appels random).
    """
    from django.conf import settings

    cle_fournie = request.GET.get('cle', '')
    if cle_fournie != settings.CRON_SECRET_KEY:
        return Response({'erreur': 'Cle invalide.'}, status=403)

    from django.core.management import call_command
    call_command('verifier_irrigation_auto')

    return Response({'statut': 'verification effectuee'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def mes_alertes(request):
    """GET /api/alertes/ — toutes les alertes des parcelles de l'utilisateur."""
    from .models import Alerte
    from .serializers import AlerteSerializer

    alertes = Alerte.objects.filter(
        zone__parcelle__proprietaire=request.user,
        envoyee=False,
    ).order_by('-date_creation')[:20]

    return Response(AlerteSerializer(alertes).data if False else AlerteSerializer(alertes, many=True).data)

from rest_framework import generics as drf_generics
from .permissions import EstAdminOuAgronome
from .serializers import (
    DeviceSerializer, VanneAdminSerializer, CapteurAdminSerializer,
    ParcelleAdminSerializer, ZoneAdminSerializer, UtilisateurAdminSerializer,
)
from .models import Device, Vanne, Capteur


# ===== Onglet Options : gestion Cultures =====
class AdminCultureListeView(drf_generics.ListCreateAPIView):
    queryset = Culture.objects.all()
    serializer_class = CultureSerializer
    permission_classes = [EstAdminOuAgronome]


class AdminCultureDetailView(drf_generics.RetrieveUpdateDestroyAPIView):
    queryset = Culture.objects.all()
    serializer_class = CultureSerializer
    permission_classes = [EstAdminOuAgronome]


# ===== Onglet Options : gestion Parcelles =====
class AdminParcelleListeView(drf_generics.ListCreateAPIView):
    queryset = Parcelle.objects.all()
    serializer_class = ParcelleAdminSerializer
    permission_classes = [EstAdminOuAgronome]


class AdminParcelleDetailView(drf_generics.RetrieveUpdateDestroyAPIView):
    queryset = Parcelle.objects.all()
    serializer_class = ParcelleAdminSerializer
    permission_classes = [EstAdminOuAgronome]


# ===== Onglet Options : gestion Zones =====
class AdminZoneListeView(drf_generics.ListCreateAPIView):
    queryset = Zone.objects.all()
    serializer_class = ZoneAdminSerializer
    permission_classes = [EstAdminOuAgronome]


class AdminZoneDetailView(drf_generics.RetrieveUpdateDestroyAPIView):
    queryset = Zone.objects.all()
    serializer_class = ZoneAdminSerializer
    permission_classes = [EstAdminOuAgronome]


# ===== Onglet Options : gestion Utilisateurs (role modifiable) =====
class AdminUtilisateurListeView(drf_generics.ListAPIView):
    queryset = Utilisateur.objects.all().order_by('-date_creation')
    serializer_class = UtilisateurAdminSerializer
    permission_classes = [EstAdminOuAgronome]


class AdminUtilisateurDetailView(drf_generics.RetrieveUpdateDestroyAPIView):
    queryset = Utilisateur.objects.all()
    serializer_class = UtilisateurAdminSerializer
    permission_classes = [EstAdminOuAgronome]


# ===== Onglet Options : consultation Devices/Capteurs/Vannes =====
class AdminDeviceListeView(drf_generics.ListAPIView):
    queryset = Device.objects.all()
    serializer_class = DeviceSerializer
    permission_classes = [EstAdminOuAgronome]


class AdminCapteurListeView(drf_generics.ListAPIView):
    queryset = Capteur.objects.all()
    serializer_class = CapteurAdminSerializer
    permission_classes = [EstAdminOuAgronome]


class AdminVanneListeView(drf_generics.ListAPIView):
    queryset = Vanne.objects.all()
    serializer_class = VanneAdminSerializer
    permission_classes = [EstAdminOuAgronome]


# ===== Onglet Options : demandes de rattachement en attente =====
class AdminDemandesEnAttenteView(drf_generics.ListAPIView):
    serializer_class = DemandeRattachementSerializer
    permission_classes = [EstAdminOuAgronome]

    def get_queryset(self):
        return DemandeRattachement.objects.filter(statut='en_attente').order_by('-date_creation')


@api_view(['POST'])
@permission_classes([EstAdminOuAgronome])
def valider_demande(request, demande_id):
    """POST /api/options/demandes/<id>/valider/ -- {"parcelle_id": 3}"""
    try:
        demande = DemandeRattachement.objects.get(id=demande_id)
    except DemandeRattachement.DoesNotExist:
        return Response({'erreur': 'Demande introuvable.'}, status=404)

    parcelle_id = request.data.get('parcelle_id')
    if not parcelle_id:
        return Response({'erreur': 'parcelle_id requis.'}, status=400)

    try:
        parcelle = Parcelle.objects.get(id=parcelle_id)
    except Parcelle.DoesNotExist:
        return Response({'erreur': 'Parcelle introuvable.'}, status=404)

    from django.utils import timezone
    demande.statut = 'validee'
    demande.parcelle_liee = parcelle
    demande.date_traitement = timezone.now()
    demande.traite_par = request.user
    demande.save()

    # Associe aussi directement l'utilisateur comme proprietaire, pour
    # que la parcelle apparaisse immediatement dans son app.
    parcelle.proprietaire = demande.utilisateur
    parcelle.save()

    return Response({'statut': 'validee'})


@api_view(['POST'])
@permission_classes([EstAdminOuAgronome])
def refuser_demande(request, demande_id):
    """POST /api/options/demandes/<id>/refuser/"""
    try:
        demande = DemandeRattachement.objects.get(id=demande_id)
    except DemandeRattachement.DoesNotExist:
        return Response({'erreur': 'Demande introuvable.'}, status=404)

    from django.utils import timezone
    demande.statut = 'refusee'
    demande.date_traitement = timezone.now()
    demande.traite_par = request.user
    demande.save()

    return Response({'statut': 'refusee'})

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def cron_rafraichir_meteo(request):
    """GET /api/cron/rafraichir-meteo/?cle=XXXX -- a appeler toutes les 3h via cron-job.org."""
    from django.conf import settings

    cle_fournie = request.GET.get('cle', '')
    if cle_fournie != settings.CRON_SECRET_KEY:
        return Response({'erreur': 'Cle invalide.'}, status=403)

    from django.core.management import call_command
    call_command('rafraichir_meteo')

    return Response({'statut': 'meteo rafraichie'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def comparaison_decisions(request, zone_id):
    """
    GET /api/zones/<id>/comparaison-decisions/?jours=30

    Compare, jour par jour, le volume irrigue par la plateforme
    (intelligent, base sur meteo+phase+humidite) au volume qu'un
    arrosage classique (sans intelligence, quotidien fixe) aurait
    utilise -- argument visuel pour montrer l'economie d'eau.
    """
    from datetime import date, timedelta as td
    from irrigation.fao56 import calculer_eto_simplifie

    try:
        zone = Zone.objects.get(id=zone_id, parcelle__proprietaire=request.user)
    except Zone.DoesNotExist:
        return Response({'erreur': 'Zone introuvable.'}, status=status.HTTP_404_NOT_FOUND)

    nb_jours = int(request.query_params.get('jours', 30))
    aujourd_hui = date.today()
    superficie = zone.superficie_m2 or 50.0

    # Volume classique de reference : ETc maximal (phase mi-saison),
    # applique tous les jours sans exception -- ce qu'un arrosage
    # manuel classique ferait, sans tenir compte de la meteo ni de la
    # phase reelle de la culture.
    eto_moyen = calculer_eto_simplifie(temperature_c=28)
    volume_classique_jour = round(zone.culture.kc_mi_saison * eto_moyen * superficie, 1)

    resultats = []
    for i in range(nb_jours, -1, -1):
        jour = aujourd_hui - td(days=i)

        decisions_du_jour = DecisionIrrigation.objects.filter(
            zone=zone,
            date_heure__date=jour,
            decision__in=['irrigation', 'irrigation_manuelle', 'irrigation_automatique'],
        )
        volume_systeme = sum(d.volume_irrigue_estime_l or 0 for d in decisions_du_jour)

        resultats.append({
            'date': jour.isoformat(),
            'volume_systeme_l': round(volume_systeme, 1),
            'volume_classique_l': volume_classique_jour,
        })

    return Response(resultats)