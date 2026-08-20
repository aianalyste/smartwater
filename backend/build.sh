#!/usr/bin/env bash
# Script execute automatiquement par Render a chaque deploiement.
set -o errexit

pip install -r requirements.txt
python manage.py collectstatic --no-input
python manage.py migrate
