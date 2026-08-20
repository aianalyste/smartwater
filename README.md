# SmartWater

Systeme d'irrigation intelligent (Togo) : capteurs d'humidite,
energie solaire, decision d'irrigation basee sur la meteo, le type
de culture et sa phase phenologique.

## Contenu de ce projet

- `backend/` — Serveur Django (moteur de decision, API, base de donnees)
- `mobile/` — Application Flutter (Android/iOS)
- `firmware/` — Code a flasher sur les ESP32
- `docs/DEPLOIEMENT.md` — **Commence ici** : guide pas a pas complet
- `docs/ARCHITECTURE.md` — Resume des choix techniques

## Demarrage rapide

Suis le guide **docs/DEPLOIEMENT.md** dans l'ordre — il explique tout,
etape par etape, meme si tu n'es pas developpeur.

## Fonctionnalites principales

- Decision d'irrigation intelligente : humidite + meteo (Open-Meteo)
  + phase phenologique de la culture (methode agronomique FAO-56)
- Prediction de l'humidite jusqu'a la prochaine pluie prevue
- Multi-zones a calendrier differencie par culture
- Rapport d'economie d'eau chiffre (estimation sans debitmetre)
- Demande de rattachement a une parcelle depuis l'app
- Compte demo pre-rempli pour presentation au jury
- Mode local de secours sur l'ESP32 (Access Point) si pas de reseau

## Support

Pour toute question de deploiement, voir docs/DEPLOIEMENT.md section
"En cas de blocage".
