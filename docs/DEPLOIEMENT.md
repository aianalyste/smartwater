# Guide de déploiement SmartWater — pas à pas

Ce guide t'explique comment faire fonctionner tout ce qui a été codé,
étape par étape, en partant du principe que tu n'es pas développeur.
Suis les étapes **dans l'ordre**. Chaque étape indique clairement ce
qu'il faut faire et où.

---

## Vue d'ensemble du projet

```
SmartWater/
├── backend/     -> Le "cerveau" (Python/Django) : calculs, décisions, base de données
├── mobile/      -> L'application Flutter que les agriculteurs utilisent
├── firmware/    -> Le code à mettre sur les ESP32
└── docs/        -> Ce guide
```

Il y a **3 briques à mettre en place** : le backend, l'app mobile, et
le firmware ESP32. On les fait dans cet ordre, parce que l'app mobile
a besoin du backend pour fonctionner.

---

## Étape 0 — Environnements test/staging et production

Pour ne jamais risquer d'abîmer les vraies données pendant les tests,
crée **deux projets Supabase distincts** dès le départ :
- `smartwater-test` : pour tous vos essais, le test de demain, les
  démonstrations
- `smartwater-prod` : à créer plus tard, uniquement quand vous êtes
  prêts pour de vrais agriculteurs

Chaque projet a sa propre URL et ses propres clés — tu auras donc
deux fichiers `.env` (`​.env.test` et `.env.prod`), et tu choisis
lequel copier en `.env` selon ce que tu veux lancer. Le fichier
`.env.example` du projet a une ligne `ENVIRONMENT` prévue pour ça
(elle s'affiche dans les logs, pratique pour savoir dans quel
environnement tu es).

## Étape 1 — Créer les comptes gratuits nécessaires

Avant de toucher au code, crée ces comptes (tous gratuits en phase pilote) :

1. **Supabase** (base de données + authentification) : https://supabase.com
   → Crée un compte, puis un nouveau projet (choisis une région proche,
   ex. Europe). Note le mot de passe de la base de données que tu choisis.

2. **HiveMQ Cloud** (broker MQTT, pour parler aux ESP32) : https://www.hivemq.com/mqtt-cloud-broker/
   → Crée un compte, un cluster gratuit ("Serverless"), puis un utilisateur
   MQTT avec un mot de passe.
   **Qui s'en occupe** : recommandé que ce soit toi (Chalom), en tant que
   responsable de la partie matérielle/réseau. Partage ensuite les
   identifiants avec le Génie Électricien via un canal sécurisé
   (gestionnaire de mots de passe partagé) — jamais par SMS/WhatsApp
   en clair.

3. **Firebase** (notifications push) : https://console.firebase.google.com
   → Crée un projet, active "Cloud Messaging".

Garde un fichier texte de côté avec toutes ces informations (URL,
mots de passe, clés) — tu en auras besoin dans les étapes suivantes.

---

## Étape 2 — Récupérer les informations Supabase

Dans ton projet Supabase :
1. Va dans **Project Settings > Database**. Note :
   - Le mot de passe de la base
   - L'hôte (Host), ex: `db.xxxxxxxxxxxxxxxx.supabase.co`
2. Va dans **Project Settings > API**. Note :
   - Project URL (ex: `https://xxxxxxxxxxxxxxxx.supabase.co`)
   - `anon` `public` key
   - `service_role` key (⚠️ à garder secrète, ne jamais la partager)

---

## Étape 3 — Configurer et lancer le backend Django

### 3.1 Installer Python
Si ce n'est pas déjà fait, installe Python 3.11+ depuis https://python.org
(coche bien "Add Python to PATH" pendant l'installation sur Windows).

### 3.2 Ouvrir un terminal dans le dossier backend
```bash
cd SmartWater/backend
```

### 3.3 Créer un environnement virtuel et installer les dépendances
```bash
python -m venv venv

# Sur Windows :
venv\Scripts\activate
# Sur Mac/Linux :
source venv/bin/activate

pip install -r requirements.txt
```

### 3.4 Configurer les variables d'environnement
```bash
# Sur Windows :
copy .env.example .env
# Sur Mac/Linux :
cp .env.example .env
```
Ouvre le fichier `.env` avec un éditeur de texte (Notepad, VS Code...)
et remplis chaque valeur avec les informations notées à l'Étape 2
(Supabase, HiveMQ, Firebase).

Pour `SECRET_KEY`, génère une vraie valeur avec :
```bash
python -c "import secrets; print(secrets.token_urlsafe(50))"
```
et colle le résultat dans le fichier `.env`.

### 3.5 Créer les tables de la base de données
```bash
python manage.py makemigrations
python manage.py migrate
```

### 3.6 Créer ton compte administrateur
```bash
python manage.py createsuperuser
```
Choisis un nom d'utilisateur et un mot de passe — c'est avec ça que tu
te connecteras au Django Admin.

### 3.7 Lancer le serveur
```bash
python manage.py runserver
```
Si tout fonctionne, tu verras un message indiquant que le serveur
tourne sur `http://127.0.0.1:8000/`.

Va dans ton navigateur à l'adresse `http://127.0.0.1:8000/admin/` et
connecte-toi avec le compte créé à l'étape 3.6 — tu devrais voir
l'interface d'administration avec toutes les tables (Parcelles,
Zones, Cultures, etc.).

### 3.8 Générer les données de démo (pour le jury)
Dans un **nouveau** terminal (garde le serveur lancé dans l'autre) :
```bash
cd SmartWater/backend
venv\Scripts\activate   (ou source venv/bin/activate sur Mac/Linux)
python manage.py seed_demo_data
```

### 3.9 Lancer le listener MQTT (pour recevoir les données des ESP32)
Dans encore un autre terminal :
```bash
python manage.py run_mqtt_listener
```
Laisse-le tourner en permanence.

---

## Étape 3bis — Mettre le code sur GitHub et déployer sur Render

Une fois que ton backend fonctionne bien sur ton PC (Étape 3), voici
comment le rendre accessible en permanence sur internet, pour que le
jury (ou n'importe qui) puisse utiliser l'app sans dépendre de ton
ordinateur.

### 1. Créer le dépôt GitHub
1. Va sur https://github.com et crée un compte si tu n'en as pas.
2. Clique sur **New repository**, nomme-le `smartwater` (privé si tu
   préfères que le code ne soit pas public).
3. Dans un terminal, à la racine du projet `SmartWater/` :
```bash
git init
git add .
git commit -m "Premiere version du projet SmartWater"
git branch -M main
git remote add origin https://github.com/TON-NOM-UTILISATEUR/smartwater.git
git push -u origin main
```
Le fichier `.gitignore` déjà présent empêche tes fichiers `.env` et
mots de passe d'être envoyés — vérifie quand même sur GitHub après
le premier push qu'aucun secret n'apparaît.

### 2. Créer le service sur Render
1. Va sur https://render.com et crée un compte (tu peux te connecter
   directement avec ton compte GitHub, c'est plus simple).
2. Clique sur **New > Web Service**.
3. Choisis ton dépôt `smartwater`.
4. Renseigne :
   - **Root Directory** : `backend`
   - **Build Command** : `./build.sh`
   - **Start Command** : `gunicorn smartwater_backend.wsgi`
   - **Instance Type** : Free
5. Dans la section **Environment Variables**, ajoute exactement les
   mêmes variables que dans ton fichier `.env` (Étape 3.4) — copie-les
   une par une : `SECRET_KEY`, `DEBUG` (mets `False` cette fois),
   `DATABASE_URL` (ou les `DB_*` séparés), `SUPABASE_URL`,
   `SUPABASE_ANON_KEY`, `MQTT_BROKER_HOST`, etc.
6. Clique sur **Create Web Service**. Render installe tout et démarre
   ton serveur — ça prend quelques minutes la première fois.
7. Une fois terminé, Render te donne une URL du type
   `https://smartwater-backend.onrender.com` — c'est cette URL que tu
   mettras dans `apiBaseUrl` (fichier `mobile/lib/main.dart`) au lieu
   de `http://10.0.2.2:8000/api`.

### 3. Redéploiement automatique
À partir de maintenant, à chaque fois que tu modifies le code et que
tu fais :
```bash
git add .
git commit -m "Description du changement"
git push
```
Render détecte automatiquement le nouveau code sur GitHub et relance
ton serveur avec la version à jour — tu n'as rien d'autre à faire.

⚠️ **Limite du plan gratuit Render** : le service "s'endort" après
15 minutes d'inactivité et met quelques secondes à se réveiller au
premier appel suivant — à garder en tête si tu fais une démo en
direct (le premier chargement peut être un peu lent).

## Étape 4 — Configurer les numéros de test OTP (essentiel pour vos tests)

1. Dans Supabase, va dans **Authentication > Providers > Phone**.
2. Active le fournisseur Phone.
3. Descends jusqu'à **"Phone numbers for testing"** (ou section
   similaire selon la version de l'interface Supabase).
4. Ajoute les numéros de ton équipe (toi, l'agronome, etc.) avec un
   code fixe à 6 chiffres de ton choix (ex: `123456`).
5. Ajoute aussi un numéro pour le **compte démo jury** (ex:
   `+22890000000` avec le code `654321` — ce numéro doit correspondre
   exactement à celui utilisé dans
   `backend/core/management/commands/seed_demo_data.py`, sinon
   modifie le fichier avec le numéro que tu as choisi ici).

Avec ces numéros configurés, aucun vrai SMS n'est nécessaire pour se
connecter pendant les tests — vous entrez juste le numéro + le code
fixe.

---

## Étape 5 — Configurer et lancer l'application Flutter

### 5.1 Installer Flutter
Suis le guide officiel : https://docs.flutter.dev/get-started/install
(choisis ton système d'exploitation). Vérifie que tout est bien
installé avec :
```bash
flutter doctor
```

### 5.2 Configurer les clés dans le code
Ouvre `mobile/lib/main.dart` et remplace :
- `supabaseUrl` par ton Project URL Supabase (Étape 2)
- `supabaseAnonKey` par ta clé `anon public` (Étape 2)
- `apiBaseUrl` : si tu testes sur un émulateur Android, garde
  `http://10.0.2.2:8000/api`. Si tu testes sur un vrai téléphone
  connecté au même Wi-Fi que ton ordinateur, remplace par l'adresse
  IP locale de ton ordinateur (ex: `http://192.168.1.42:8000/api` —
  trouve cette adresse avec `ipconfig` sur Windows ou `ifconfig` sur
  Mac/Linux).

### 5.3 Installer les dépendances et lancer l'app
```bash
cd SmartWater/mobile
flutter pub get
flutter run
```
Choisis l'émulateur ou l'appareil sur lequel lancer l'app quand
Flutter te le demande.

### 5.4 Générer l'icône de l'application (le logo que tu as fourni)
```bash
flutter pub add flutter_launcher_icons --dev
```
Puis ajoute ceci à la fin de `mobile/pubspec.yaml` :
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo.png"
```
Et lance :
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

### 5.5 Générer un APK à partager (pour le jury, sans passer par le Play Store)
```bash
flutter build apk --release
```
Le fichier sera créé dans
`mobile/build/app/outputs/flutter-apk/app-release.apk`. Envoie ce
fichier au jury par lien Google Drive, WhatsApp, ou clé USB. Sur leur
téléphone Android, ils devront autoriser l'installation depuis une
"source inconnue" (une option proposée automatiquement à l'ouverture
du fichier).

⚠️ Pense à bien remplacer `apiBaseUrl` (Étape 5.2) par l'URL Render
**avant** de générer cet APK, sinon l'app ne pourra pas se connecter
au backend une fois installée sur un autre téléphone que le tien.

---

## Étape 6 — Flasher le firmware sur les ESP32

1. Installe l'IDE Arduino : https://www.arduino.cc/en/software
2. Ajoute le support ESP32 : **Fichier > Préférences**, colle cette
   URL dans "URL de gestionnaire de cartes supplémentaires" :
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
3. Va dans **Outils > Type de carte > Gestionnaire de cartes**,
   cherche "esp32" et installe-le.
4. Installe les bibliothèques nécessaires : **Outils > Gérer les
   bibliothèques**, cherche et installe : `PubSubClient`,
   `ArduinoJson`.
5. Ouvre `firmware/smartwater_esp32/smartwater_esp32.ino`.
6. Remplace toutes les valeurs marquées `A REMPLIR` en haut du
   fichier (WiFi, MQTT, identifiant du device).
7. Branche ton ESP32 en USB, sélectionne le bon port dans
   **Outils > Port**, et clique sur "Téléverser".

⚠️ Le firmware contient des sections marquées `A ADAPTER` pour la
lecture exacte du capteur SEN0600 et du capteur spectral AS7265x —
il faudra les ajuster avec ton génie électrique une fois les
capteurs en main, en suivant leurs datasheets exactes.

---

## Étape 7 — Enregistrer tes devices dans le Django Admin

Avant qu'un ESP32 puisse envoyer des données, il faut le déclarer :

1. Va sur `http://127.0.0.1:8000/admin/`
2. Crée une **Parcelle**, puis une **Zone** dedans (avec sa Culture
   et sa date de semis).
3. Crée un **Device** avec l'identifiant exact utilisé dans le
   firmware (ex: `ESP32-001`), relié à la Zone.
4. Crée les **Capteurs** et la **Vanne** associés à ce Device et
   cette Zone.

Une fois ça fait, dès que l'ESP32 publiera des données MQTT, elles
apparaîtront automatiquement dans l'app.

---

## Pour aller plus loin (à faire avant un vrai déploiement public)

Ces points ne sont **pas nécessaires pour les tests/démo**, mais à
prévoir avant d'ouvrir l'app à de vrais agriculteurs :

- **Sécuriser l'authentification** : remplacer la vérification
  simplifiée dans `backend/core/authentication.py` par une vraie
  vérification de signature JWT.
- **Brancher un vrai fournisseur SMS** (module GSM physique ou
  Africa's Talking) pour remplacer les numéros de test OTP.
- **Déployer le backend sur un vrai serveur** (ex: Railway, Render,
  ou un VPS) au lieu de le faire tourner sur ton ordinateur — sinon
  l'app ne fonctionnera que quand ton ordinateur est allumé.
- **Publier l'app** sur le Google Play Store (nécessite un compte
  développeur Google, ~25$ une fois).
- **Garder le listener MQTT actif en permanence** avec un outil comme
  `systemd` (Linux) ou un service Windows, pour qu'il redémarre
  automatiquement s'il plante.

---

## En cas de blocage

Si une étape ne fonctionne pas, note le message d'erreur exact — la
plupart des blocages viennent d'une valeur mal copiée dans le fichier
`.env` ou `main.dart`. Reviens vers moi avec le message d'erreur et
je t'aiderai à le résoudre.
