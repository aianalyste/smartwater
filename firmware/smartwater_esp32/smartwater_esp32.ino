/*
 * ============================================================
 * SmartWater - Firmware ESP32
 * ============================================================
 * Lit les capteurs d'humidite/temperature (SEN0600) de chaque zone
 * geree par ce device, publie les donnees vers le backend via MQTT,
 * recoit les commandes d'ouverture/fermeture de vanne, et accumule
 * les mesures en memoire pendant les coupures reseau pour les
 * synchroniser une fois la connexion retablie.
 *
 * IMPORTANT : ce firmware N'EXECUTE AUCUNE DECISION D'IRRIGATION --
 * il remonte les donnees brutes et execute les commandes recues.
 * Toute la logique de decision est cote backend Django
 * (irrigation/decision_engine.py). Voir mqtt_client/mqtt_listener.py
 * pour la specification complete des topics et formats de messages.
 *
 * A FAIRE AVANT DE FLASHER CE CODE SUR L'ESP32 :
 * 1. Remplace les valeurs marquees "A REMPLIR" ci-dessous
 * 2. Adapte le tableau ZONES ci-dessous : chaque zone geree par CE
 *    device doit avoir un code_terrain IDENTIQUE a celui defini
 *    dans le Django Admin (champ Zone.code_terrain)
 * 3. Installe les bibliotheques : PubSubClient, ArduinoJson
 * 4. Adapte la lecture du capteur SEN0600 selon sa datasheet exacte
 * ============================================================
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <WebServer.h>

// ---------------- A REMPLIR : identifiants WiFi ----------------
const char* WIFI_SSID = "NOM_DU_RESEAU_WIFI";
const char* WIFI_PASSWORD = "MOT_DE_PASSE_WIFI";

// ---------------- A REMPLIR : broker MQTT -----------------------
const char* MQTT_HOST = "xxxxxxxxxxxx.hivemq.cloud";
const int MQTT_PORT = 8883;
const char* MQTT_USER = "smartwater";
const char* MQTT_PASSWORD = "ton-mot-de-passe-mqtt";

// ---------------- A REMPLIR : identifiant unique de ce device ---
// Doit correspondre EXACTEMENT au Device.identifiant du Django Admin
const char* DEVICE_ID = "ESP32-001";

// ---------------- A REMPLIR : zones gerees par CE device ---------
// Chaque ESP32 peut piloter PLUSIEURS zones (plusieurs capteurs et
// vannes). Le devis materiel prevoit 2 ESP32 pour 3 electrovannes --
// adapte ce tableau selon le cablage reel de chaque boitier.
// "code_terrain" DOIT correspondre exactement a la Zone dans Django.
struct ZoneConfig {
  const char* code_terrain;
  int pin_capteur_humidite;
  int pin_relais_vanne;
};

ZoneConfig ZONES[] = {
  {"Z1", 34, 26},   // A ADAPTER : broches reelles pour la zone Z1
  {"Z2", 35, 27},   // A ADAPTER : broches reelles pour la zone Z2 (si ce device en gere une 2e)
};
const int NB_ZONES = sizeof(ZONES) / sizeof(ZONES[0]);

// ---------------- Mode Access Point de secours -------------------
const char* AP_SSID = "SmartWater-Config";
const char* AP_PASSWORD = "smartwater2026";  // A CHANGER pour la production

// ---------------- Frequences (deux frequences distinctes) --------
const unsigned long INTERVALLE_VERIF_RESEAU_MS = 2UL * 60 * 1000;      // 2 minutes
const unsigned long INTERVALLE_ENVOI_DONNEES_MS = 5UL * 60 * 1000;     // 5 minutes -- A AJUSTER si besoin

// ---------------- Buffer hors-ligne (mode secours) ----------------
// Nombre maximum de lectures gardees en memoire pendant une coupure.
// Avec 12 lectures/zone/heure (toutes les 5 min) et 2 zones, 60
// entrees couvrent environ 2h30 de coupure avant saturation.
const int TAILLE_BUFFER = 60;
struct LectureDifferee {
  const char* zone_code;
  float humidite_pct;
  float temperature_c;
  unsigned long horodatage_millis;
};
LectureDifferee bufferHorsLigne[TAILLE_BUFFER];
int nbLecturesBufferisees = 0;

WiFiClientSecure espClient;
PubSubClient mqttClient(espClient);
WebServer serveurLocal(80);

unsigned long dernierVerifReseau = 0;
unsigned long dernierEnvoiDonnees = 0;
bool modeAccessPoint = false;

// =========================================================
// Lecture des capteurs
// =========================================================
float lireHumidite(int pin) {
  // A ADAPTER selon l'interface reelle du SEN0600 (I2C probable --
  // consulte sa datasheet). Exemple simplifie pour capteur analogique :
  int lecture = analogRead(pin);
  float pourcentage = map(lecture, 4095, 1200, 0, 100);  // a calibrer sur le terrain
  return constrain(pourcentage, 0, 100);
}

float lireTemperature(int pin) {
  // A COMPLETER selon l'interface reelle du SEN0600.
  return 27.5;  // valeur d'exemple -- A REMPLACER
}

// =========================================================
// Connexion WiFi + MQTT
// =========================================================
bool connecterWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int tentatives = 0;
  while (WiFi.status() != WL_CONNECTED && tentatives < 20) {
    delay(500);
    tentatives++;
  }
  return WiFi.status() == WL_CONNECTED;
}

int trouverIndexZone(const char* code) {
  for (int i = 0; i < NB_ZONES; i++) {
    if (strcmp(ZONES[i].code_terrain, code) == 0) return i;
  }
  return -1;
}

void onMessageMqtt(char* topic, byte* payload, unsigned int length) {
  // Format attendu : {"zone_code": "Z1", "vanne": "ouvrir", "duree_minutes": 20}
  StaticJsonDocument<256> doc;
  deserializeJson(doc, payload, length);

  const char* zoneCode = doc["zone_code"] | "";
  String vanne = doc["vanne"] | "";

  int idx = trouverIndexZone(zoneCode);
  if (idx == -1) return;  // zone_code inconnu de ce device

  if (vanne == "ouvrir") {
    digitalWrite(ZONES[idx].pin_relais_vanne, HIGH);
  } else if (vanne == "fermer") {
    digitalWrite(ZONES[idx].pin_relais_vanne, LOW);
  }
}

bool connecterMqtt() {
  espClient.setInsecure();  // A AMELIORER en production : verifier le certificat du broker
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(onMessageMqtt);

  if (mqttClient.connect(DEVICE_ID, MQTT_USER, MQTT_PASSWORD)) {
    String topicCommande = String("smartwater/") + DEVICE_ID + "/commande";
    mqttClient.subscribe(topicCommande.c_str());
    return true;
  }
  return false;
}

// Publie les lectures de TOUTES les zones de ce device en un seul
// message JSON (tableau), comme specifie dans mqtt_listener.py
void publierLectures() {
  StaticJsonDocument<512> doc;
  JsonArray tableau = doc.to<JsonArray>();

  for (int i = 0; i < NB_ZONES; i++) {
    JsonObject obj = tableau.createNestedObject();
    obj["zone_code"] = ZONES[i].code_terrain;
    obj["humidite_pct"] = lireHumidite(ZONES[i].pin_capteur_humidite);
    obj["temperature_c"] = lireTemperature(ZONES[i].pin_capteur_humidite);
  }

  char buffer[512];
  serializeJson(doc, buffer);

  String topic = String("smartwater/") + DEVICE_ID + "/capteurs";
  mqttClient.publish(topic.c_str(), buffer);
}

// Enregistre une lecture dans le buffer hors-ligne (mode secours)
void bufferiserLecture() {
  if (nbLecturesBufferisees >= TAILLE_BUFFER) return;  // buffer plein, on ignore (A AMELIORER si besoin : ecraser la plus ancienne)

  for (int i = 0; i < NB_ZONES; i++) {
    if (nbLecturesBufferisees >= TAILLE_BUFFER) break;
    bufferHorsLigne[nbLecturesBufferisees].zone_code = ZONES[i].code_terrain;
    bufferHorsLigne[nbLecturesBufferisees].humidite_pct = lireHumidite(ZONES[i].pin_capteur_humidite);
    bufferHorsLigne[nbLecturesBufferisees].temperature_c = lireTemperature(ZONES[i].pin_capteur_humidite);
    bufferHorsLigne[nbLecturesBufferisees].horodatage_millis = millis();
    nbLecturesBufferisees++;
  }
}

// Une fois reconnecte, envoie tout le buffer accumule sur le topic
// "capteurs_differe", avec l'anciennete de chaque mesure en secondes
void synchroniserBufferHorsLigne() {
  if (nbLecturesBufferisees == 0) return;

  StaticJsonDocument<2048> doc;
  JsonArray tableau = doc.to<JsonArray>();
  unsigned long maintenant = millis();

  for (int i = 0; i < nbLecturesBufferisees; i++) {
    JsonObject obj = tableau.createNestedObject();
    obj["zone_code"] = bufferHorsLigne[i].zone_code;
    obj["humidite_pct"] = bufferHorsLigne[i].humidite_pct;
    obj["temperature_c"] = bufferHorsLigne[i].temperature_c;
    unsigned long secondesEcoulees = (maintenant - bufferHorsLigne[i].horodatage_millis) / 1000;
    obj["il_y_a_secondes"] = secondesEcoulees;
  }

  char buffer[2048];
  serializeJson(doc, buffer);

  String topic = String("smartwater/") + DEVICE_ID + "/capteurs_differe";
  mqttClient.publish(topic.c_str(), buffer);

  nbLecturesBufferisees = 0;  // buffer vide une fois synchronise
}

// =========================================================
// Mode Access Point de secours (pas de reseau WiFi disponible)
// =========================================================
void demarrerModeAccessPoint() {
  modeAccessPoint = true;
  WiFi.softAP(AP_SSID, AP_PASSWORD);

  serveurLocal.on("/", []() {
    String html = "<h2>SmartWater - Mode local</h2>";
    for (int i = 0; i < NB_ZONES; i++) {
      html += "<p>" + String(ZONES[i].code_terrain) + " - Humidite : "
              + String(lireHumidite(ZONES[i].pin_capteur_humidite)) + "%</p>";
    }
    html += "<p><i>" + String(nbLecturesBufferisees) + " lecture(s) en attente de synchronisation</i></p>";
    serveurLocal.send(200, "text/html", html);
  });

  serveurLocal.begin();
}

// =========================================================
// Setup / Loop
// =========================================================
void setup() {
  Serial.begin(115200);
  for (int i = 0; i < NB_ZONES; i++) {
    pinMode(ZONES[i].pin_relais_vanne, OUTPUT);
    digitalWrite(ZONES[i].pin_relais_vanne, LOW);
  }

  if (connecterWifi()) {
    connecterMqtt();
  } else {
    demarrerModeAccessPoint();
  }
}

void loop() {
  if (modeAccessPoint) {
    serveurLocal.handleClient();
  } else {
    if (!mqttClient.connected()) {
      connecterMqtt();
    }
    mqttClient.loop();
  }

  // --- Verification du retour reseau (toutes les 2 minutes) ---
  if (millis() - dernierVerifReseau > INTERVALLE_VERIF_RESEAU_MS) {
    dernierVerifReseau = millis();

    if (modeAccessPoint) {
      WiFi.softAPdisconnect(true);
      if (connecterWifi()) {
        modeAccessPoint = false;
        if (connecterMqtt()) {
          synchroniserBufferHorsLigne();  // rattrape les mesures manquees
        }
      } else {
        demarrerModeAccessPoint();
      }
    } else if (WiFi.status() != WL_CONNECTED) {
      demarrerModeAccessPoint();
    }
  }

  // --- Envoi des lectures capteurs (toutes les 5 minutes) ---
  if (millis() - dernierEnvoiDonnees > INTERVALLE_ENVOI_DONNEES_MS) {
    dernierEnvoiDonnees = millis();

    if (!modeAccessPoint && WiFi.status() == WL_CONNECTED) {
      publierLectures();
    } else {
      bufferiserLecture();  // pas de reseau -> on garde la mesure en memoire
    }
  }
}
