# SmartWater - Backend Django

Voir ../docs/DEPLOIEMENT.md, Etape 3, pour la configuration complete.

Modules cles :
- core/models.py          -> tous les modeles de donnees
- irrigation/              -> le moteur de decision (FAO-56, meteo, prediction)
- mqtt_client/              -> communication avec les ESP32
- core/management/commands/seed_demo_data.py -> donnees demo pour le jury
