"""
Modeles de donnees SmartWater.

Ces classes correspondent exactement au diagramme de classes qu'on a
valide ensemble : Utilisateur -> Parcelle -> Zone -> Culture/Capteur/
Vanne -> Decisions/Alertes/Rapports.

Pour appliquer ces modeles a la base de donnees, lance (voir le guide
de deploiement) :
    python manage.py makemigrations
    python manage.py migrate
"""

from django.db import models


# =========================================================
# UTILISATEURS ET ACCES
# =========================================================

class Utilisateur(models.Model):
    """
    Un utilisateur de l'app : agriculteur, agronome, technicien ou admin.
    Inscription simplifiee pour la phase pilote : nom, telephone, ville,
    localite -- sans mot de passe ni verification SMS.
    """

    ROLE_CHOICES = [
        ('agriculteur', 'Agriculteur'),
        ('agronome', 'Agronome'),
        ('technicien', 'Technicien'),
        ('admin', 'Administrateur'),
        ('demo', 'Compte demo (jury)'),
    ]

    nom = models.CharField(max_length=120)
    telephone = models.CharField(max_length=20, unique=True)
    ville = models.CharField(max_length=120, blank=True)
    localite = models.CharField(max_length=120, blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='agriculteur')
    session_token = models.CharField(max_length=64, unique=True, editable=False)
    date_creation = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if not self.session_token:
            import secrets
            self.session_token = secrets.token_urlsafe(32)
        super().save(*args, **kwargs)

    @property
    def is_authenticated(self):
        return True

    def __str__(self):
        return f"{self.nom} ({self.telephone})"

class DemandeRattachement(models.Model):
    """
    Demande d'un agriculteur pour etre rattache a une parcelle.
    Flux valide : l'agriculteur remplit cette demande depuis l'app,
    un agronome/admin la valide ou la refuse depuis le Django Admin.
    """

    STATUT_CHOICES = [
        ('en_attente', 'En attente'),
        ('validee', 'Validee'),
        ('refusee', 'Refusee'),
    ]

    utilisateur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='demandes')
    nom_parcelle_indique = models.CharField(max_length=200, help_text="Nom/localite indiques par l'agriculteur")
    localisation_indiquee = models.CharField(max_length=200, blank=True)
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default='en_attente')
    parcelle_liee = models.ForeignKey(
        'Parcelle', null=True, blank=True, on_delete=models.SET_NULL,
        help_text="Rempli par l'agronome au moment de la validation"
    )
    date_creation = models.DateTimeField(auto_now_add=True)
    date_traitement = models.DateTimeField(null=True, blank=True)
    traite_par = models.ForeignKey(
        Utilisateur, null=True, blank=True, on_delete=models.SET_NULL,
        related_name='demandes_traitees'
    )

    def __str__(self):
        return f"Demande de {self.utilisateur} - {self.statut}"


# =========================================================
# PARCELLES, ZONES, CULTURES
# =========================================================

class Parcelle(models.Model):
    """Une exploitation agricole, situee a un endroit precis."""

    proprietaire = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='parcelles')
    nom = models.CharField(max_length=120)
    localisation = models.CharField(max_length=200, help_text="Nom de la localite, ex: Aneho, Tsevie")
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    date_creation = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nom} ({self.localisation})"


class Culture(models.Model):
    """
    Catalogue des cultures supportees, avec leurs coefficients Kc par
    phase phenologique (methode FAO-56). Ces valeurs sont des points
    de depart standards -- A FAIRE VALIDER PAR L'AGRONOME DE L'EQUIPE
    avant utilisation reelle, elles peuvent varier selon la variete
    locale et les conditions du Togo.
    """

    nom = models.CharField(max_length=80, unique=True)
    kc_initial = models.FloatField(default=0.5, help_text="Phase germination/levee")
    kc_developpement = models.FloatField(default=0.7, help_text="Croissance vegetative")
    kc_mi_saison = models.FloatField(default=1.1, help_text="Floraison / mi-saison")
    kc_maturation = models.FloatField(default=0.8, help_text="Maturation")
    duree_phase_initiale_jours = models.IntegerField(default=20)
    duree_phase_developpement_jours = models.IntegerField(default=25)
    duree_phase_mi_saison_jours = models.IntegerField(default=35)
    duree_phase_maturation_jours = models.IntegerField(default=20)
    seuil_humidite_min_pct = models.FloatField(
        default=40.0, help_text="En dessous de ce %, on envisage d'irriguer"
    )
    seuil_humidite_max_pct = models.FloatField(
        default=70.0, help_text="Au dessus, le sol est considere gorge d'eau"
    )

    def __str__(self):
        return self.nom


class Zone(models.Model):
    """
    Une zone d'irrigation independante a l'interieur d'une parcelle.
    Chaque zone a sa propre culture, son propre capteur, sa propre
    vanne -- c'est le multi-zones a calendrier differencie qu'on a
    defini ensemble.
    """

    parcelle = models.ForeignKey(Parcelle, on_delete=models.CASCADE, related_name='zones')
    nom = models.CharField(max_length=80, help_text="Ex: Zone 1, Jardin, Potager...")
    code_terrain = models.CharField(
        max_length=10, unique=True,
        help_text="Code court utilise par le firmware ESP32 pour identifier cette zone "
                   "dans les messages MQTT (ex: Z1, Z2, Z3). DOIT correspondre exactement "
                   "au code defini dans le firmware -- voir firmware/smartwater_esp32/smartwater_esp32.ino"
    )
    culture = models.ForeignKey(Culture, on_delete=models.PROTECT, related_name='zones')
    superficie_m2 = models.FloatField(null=True, blank=True)
    date_semis = models.DateField(help_text="Sert a calculer automatiquement la phase phenologique")
    phase_source = models.CharField(
        max_length=20,
        choices=[('date_semis', 'Calculee via date de semis'), ('capteur_spectral', 'Detectee par capteur AS7265x')],
        default='date_semis',
    )

    def __str__(self):
        return f"{self.nom} - {self.parcelle.nom} ({self.culture.nom})"

    def phase_actuelle(self, aujourdhui=None):
        """
        Calcule la phase phenologique actuelle a partir de la date de
        semis, si aucune lecture recente du capteur spectral n'est
        disponible. Voir irrigation/fao56.py pour le detail du calcul.
        """
        from irrigation.fao56 import calculer_phase_phenologique
        return calculer_phase_phenologique(self, aujourdhui)


# =========================================================
# MATERIEL : DEVICES, CAPTEURS, VANNES
# =========================================================

class Device(models.Model):
    """Un boitier ESP32 physique sur le terrain."""

    MODE_CHOICES = [
        ('mqtt', 'Connecte via MQTT (Wifi/cloud)'),
        ('ap_local', 'Mode Access Point local (secours, pas de reseau)'),
        ('hors_ligne', 'Hors ligne / injoignable'),
    ]

    identifiant = models.CharField(max_length=50, unique=True, help_text="Ex: ESP32-001")
    zone = models.ForeignKey(Zone, on_delete=models.CASCADE, related_name='devices', null=True, blank=True)
    mode_connexion = models.CharField(max_length=20, choices=MODE_CHOICES, default='hors_ligne')
    derniere_communication = models.DateTimeField(null=True, blank=True)
    niveau_batterie_pct = models.FloatField(null=True, blank=True)

    def __str__(self):
        return self.identifiant


class Capteur(models.Model):
    """Un capteur physique rattache a un device (SEN0600 ou AS7265x)."""

    TYPE_CHOICES = [
        ('humidite_temperature', "Humidite + temperature (SEN0600)"),
        ('spectral_phenologique', "Spectral - phase phenologique (AS7265x)"),
    ]

    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='capteurs')
    zone = models.ForeignKey(Zone, on_delete=models.CASCADE, related_name='capteurs')
    type_capteur = models.CharField(max_length=30, choices=TYPE_CHOICES)
    derniere_humidite_pct = models.FloatField(null=True, blank=True)
    derniere_temperature_c = models.FloatField(null=True, blank=True)
    derniere_lecture = models.DateTimeField(null=True, blank=True)
    statut_maintenance = models.BooleanField(
        default=False,
        help_text="Coche manuellement si ce capteur est en cours de nettoyage/reparation."
    )

    def __str__(self):
        return f"{self.get_type_capteur_display()} - {self.zone.nom}"

    def etat_sante(self):
        """
        Determine l'etat du capteur : 'maintenance', 'aucune_donnee',
        'defaillant', ou 'normal'.

        Logique de detection de panne (point 1 de la liste validee) :
        - Aucune lecture jamais recue -> 'aucune_donnee'
        - Pas de nouvelle lecture depuis plus de 48h -> 'defaillant'
        - Les 3 dernieres lectures (sur 48h) ont exactement la meme
          valeur d'humidite -> 'defaillant' (valeur figee anormale)
        - Sinon -> 'normal'
        """
        if self.statut_maintenance:
            return 'maintenance'

        if not self.derniere_lecture:
            return 'aucune_donnee'

        from django.utils import timezone
        from datetime import timedelta

        if self.derniere_lecture < timezone.now() - timedelta(hours=48):
            return 'defaillant'

        lectures_recentes = list(
            self.lectures.filter(
                horodatage__gte=timezone.now() - timedelta(hours=48)
            ).order_by('-horodatage')[:3]
        )
        if len(lectures_recentes) >= 3:
            valeurs = [l.humidite_pct for l in lectures_recentes]
            if len(set(valeurs)) == 1:
                return 'defaillant'

        return 'normal'

    def generer_alerte_si_besoin(self):
        """Cree une Alerte si l'etat du capteur le justifie (defaillant/maintenance)."""
        from .models import Alerte

        etat = self.etat_sante()
        if etat not in ('defaillant', 'maintenance'):
            return

        deja_existe = Alerte.objects.filter(
            device=self.device, type_alerte='panne_capteur', envoyee=False
        ).exists()
        if deja_existe:
            return

        if etat == 'defaillant':
            message = f"Le capteur {self.get_type_capteur_display()} de la zone {self.zone.nom} semble en panne (valeur figee ou pas de nouvelle donnee)."
        else:  # maintenance
            message = f"Le capteur {self.get_type_capteur_display()} de la zone {self.zone.nom} est en maintenance."

        Alerte.objects.create(
            zone=self.zone,
            device=self.device,
            type_alerte='panne_capteur',
            message=message,
            canal='push',
        )


class LectureCapteur(models.Model):
    """
    Historique des mesures brutes envoyees par les capteurs.
    Sert au graphique d'humidite (moyenne/max/min) et a l'IA predictive.
    """

    capteur = models.ForeignKey(Capteur, on_delete=models.CASCADE, related_name='lectures')
    humidite_pct = models.FloatField(null=True, blank=True)
    temperature_c = models.FloatField(null=True, blank=True)
    horodatage = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-horodatage']


class Vanne(models.Model):
    """Une electrovanne Hunter PGV controlant l'irrigation d'une zone."""

    ETAT_CHOICES = [('ouverte', 'Ouverte'), ('fermee', 'Fermee')]

    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='vannes')
    zone = models.OneToOneField(Zone, on_delete=models.CASCADE, related_name='vanne')
    etat = models.CharField(max_length=10, choices=ETAT_CHOICES, default='fermee')
    debit_theorique_l_min = models.FloatField(
        default=15.0,
        help_text="Debit theorique de l'electrovanne Hunter PGV 1po en litres/minute -- "
                   "A VERIFIER sur la fiche technique du fabricant, cette valeur est une estimation."
    )
    derniere_ouverture = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Vanne {self.zone.nom} - {self.etat}"


# =========================================================
# DECISIONS, ALERTES, RAPPORTS
# =========================================================

class DecisionIrrigation(models.Model):
    """
    Une decision prise par le moteur d'irrigation (voir
    irrigation/decision_engine.py) pour une zone donnee.
    """

    DECISION_CHOICES = [
        ('aucune', "Pas d'irrigation - humidite suffisante"),
        ('reportee', "Irrigation reportee - pluie prevue suffisante"),
        ('irrigation', "Irrigation declenchee"),
        ('irrigation_manuelle', "Irrigation demarree manuellement"),
        ('irrigation_automatique', "Irrigation demarree automatiquement (delai 1h depasse)"),
    ]

    zone = models.ForeignKey(Zone, on_delete=models.CASCADE, related_name='decisions')
    date_heure = models.DateTimeField(auto_now_add=True)
    humidite_mesuree_pct = models.FloatField(null=True, blank=True)
    pluie_prevue_mm = models.FloatField(null=True, blank=True)
    etc_calcule_mm = models.FloatField(null=True, blank=True, help_text="Besoin en eau calcule (Kc x ETo)")
    volume_irrigue_estime_l = models.FloatField(null=True, blank=True)
    duree_minutes = models.FloatField(null=True, blank=True)
    decision = models.CharField(max_length=25, choices=DECISION_CHOICES)
    explication = models.TextField(blank=True, help_text="Texte lisible affiche a l'agriculteur")

    class Meta:
        ordering = ['-date_heure']

    def __str__(self):
        return f"{self.zone.nom} - {self.decision} ({self.date_heure:%d/%m %H:%M})"


class Alerte(models.Model):
    """Une alerte envoyee a l'agriculteur (push, SMS ou USSD)."""

    TYPE_CHOICES = [
        ('sol_sec', 'Sol trop sec'),
        ('panne_capteur', 'Panne capteur'),
        ('batterie_faible', 'Batterie solaire faible'),
        ('vanne_anomalie', 'Anomalie sur une vanne'),
    ]
    CANAL_CHOICES = [('push', 'Notification push'), ('sms', 'SMS'), ('ussd', 'USSD')]

    zone = models.ForeignKey(Zone, on_delete=models.CASCADE, related_name='alertes', null=True, blank=True)
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='alertes', null=True, blank=True)
    type_alerte = models.CharField(max_length=20, choices=TYPE_CHOICES)
    message = models.TextField()
    canal = models.CharField(max_length=10, choices=CANAL_CHOICES, default='push')
    date_creation = models.DateTimeField(auto_now_add=True)
    envoyee = models.BooleanField(default=False)

    class Meta:
        ordering = ['-date_creation']

    def __str__(self):
        return f"{self.type_alerte} - {self.date_creation:%d/%m %H:%M}"


class RapportEconomieEau(models.Model):
    """
    Rapport periodique d'economie d'eau, calcule par estimation
    (duree d'ouverture de vanne x debit theorique), comme valide
    ensemble -- pas besoin de debitmetre physique.
    """

    zone = models.ForeignKey(Zone, on_delete=models.CASCADE, related_name='rapports_eau')
    periode_debut = models.DateField()
    periode_fin = models.DateField()
    volume_utilise_estime_l = models.FloatField()
    volume_reference_manuel_l = models.FloatField(
        help_text="Estimation de ce qu'un arrosage manuel classique aurait consomme"
    )
    pourcentage_economise = models.FloatField()

    def __str__(self):
        return f"{self.zone.nom} : {self.pourcentage_economise:.0f}% economise ({self.periode_debut} - {self.periode_fin})"
