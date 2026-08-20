# Architecture SmartWater

Résumé de toutes les décisions techniques prises ensemble, pour
retrouver rapidement "pourquoi on a choisi ça".

## Stack technique

| Couche | Choix | Pourquoi |
|---|---|---|
| App mobile | Flutter | Un seul code pour Android/iOS |
| Backend | Python / Django + DRF | Moteur de décision, ORM puissant |
| Base de données | PostgreSQL via Supabase | Gratuit en pilote, SQL puissant |
| Authentification | Supabase Auth (téléphone + OTP) | Adapté à un public sans email |
| Communication ESP32 ↔ cloud | MQTT + mode AP local de secours | Léger, tient sur connexion faible |
| Météo | Open-Meteo | Gratuite, sans clé API |
| Notifications | Firebase Cloud Messaging | Gratuit, standard |
| SMS/USSD (production) | Module GSM physique (SIM Togocel/Moov) | Coût minimal pour le pilote |
| IA - phase phénologique | Random Forest / XGBoost (capteur AS7265x) | Léger, peu de données nécessaires |
| IA - prédiction | Prophet | Simple pour séries temporelles |
| Décision d'irrigation | Calcul FAO-56 (Kc × ETo), pas de ML | Fiable, explicable |

## Logique de décision (le cœur du système)

Voir `backend/irrigation/decision_engine.py` — résumé :

1. Humidité suffisante ? → pas d'irrigation.
2. Pluie prévue aujourd'hui suffisante ? → irrigation reportée.
3. Projection de l'humidité jusqu'à la prochaine pluie reste dans la
   fourchette sûre ? → pas d'irrigation (voir `humidity_prediction.py`).
4. Sinon → irrigation, volume calculé via ETc = Kc × ETo.

## Modèle de données

Voir `backend/core/models.py`. Structure : un Utilisateur peut
posséder plusieurs Parcelles, chaque Parcelle contient plusieurs
Zones (multi-zones à calendrier différencié), chaque Zone a sa
Culture, ses Capteurs, sa Vanne.

## Comptes et rôles

- **Agriculteur** : téléphone + OTP, voit uniquement ses parcelles.
  S'il n'en a aucune, peut soumettre une `DemandeRattachement`.
- **Agronome/technicien** : même flux, rôle différent en base.
- **Admin (toi)** : Django Admin, login/mot de passe classique.
- **Démo (jury)** : numéro de test OTP dédié + données fictives
  générées via `seed_demo_data`.

## Matériel (devis Génie électrique)

2× ESP32-WROOM-32, 2× capteur humidité/température SEN0600, 2×
capteur spectral AS7265x (détection phase phénologique), 3×
électrovanne Hunter PGV 1" (3 zones), MAX485, alimentation
220VAC-12V DC.

## Spécification ESP32 ↔ Backend (réponses aux 10 points du GE)

Voir le détail complet en commentaire en tête de
`backend/mqtt_client/mqtt_listener.py` — résumé :

1. **Format JSON capteurs** : tableau par device, un objet par zone —
   `[{"zone_code": "Z1", "humidite_pct": 42.5, "temperature_c": 27.3}]`
2. **Endpoint** : pas de REST HTTP pour l'ESP32 — tout passe par MQTT
   vers le backend Django (jamais directement vers Supabase).
3. **Authentification ESP32** : identifiants du broker MQTT
   (username/password HiveMQ), pas un token applicatif.
4. **Topics MQTT** : `smartwater/<device_id>/capteurs`,
   `.../commande`, `.../status`, `.../capteurs_differe` — un device
   peut gérer plusieurs zones, distinguées par `zone_code` dans le
   payload.
5. **Format des commandes** : JSON —
   `{"zone_code": "Z1", "vanne": "ouvrir", "duree_minutes": 20}`
6. **Gestion du broker** : Chalom crée le compte HiveMQ Cloud,
   partage les identifiants avec le GE via canal sécurisé.
7. **Répartition de la logique** : confirmé — l'ESP32 exécute
   uniquement les commandes et remonte les données brutes, zéro
   décision locale.
8. **Fréquence** : vérification réseau toutes les 2 min, envoi des
   données toutes les 5 min (les deux sont ajustables séparément
   dans le firmware).
9. **Environnement de test** : deux projets Supabase distincts
   (`smartwater-test` / `smartwater-prod`), voir docs/DEPLOIEMENT.md
   Étape 0.
10. **Synchronisation différée** : buffer en mémoire sur l'ESP32
    pendant une coupure réseau, publié sur `capteurs_differe` avec
    un champ `il_y_a_secondes` par mesure une fois reconnecté ; le
    backend reconstitue l'horodatage réel.
