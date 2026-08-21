"""
Configuration Django du projet SmartWater.

CE QUE TU DOIS FAIRE AVANT DE LANCER LE PROJET :
1. Copier .env.example en .env et remplir les vraies valeurs
   (voir le guide docs/DEPLOIEMENT.md pour savoir ou trouver
   chaque information).
2. Ne jamais modifier ce fichier settings.py pour y mettre des
   mots de passe en clair -- tout passe par le fichier .env.
"""

from pathlib import Path
from decouple import config

BASE_DIR = Path(__file__).resolve().parent.parent

# --- Securite ---
SECRET_KEY = config('SECRET_KEY', default='dev-secret-key-a-changer')
DEBUG = config('DEBUG', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='127.0.0.1,localhost').split(',')

# --- Applications installees ---
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Bibliotheques tierces
    'rest_framework',
    'corsheaders',

    # Applications SmartWater
    'core',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',   # sert les fichiers statiques en production
    'corsheaders.middleware.CorsMiddleware',   # doit etre tot dans la liste
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'smartwater_backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'smartwater_backend.wsgi.application'

# --- Base de donnees : PostgreSQL via Supabase ---
# Sur Render, tu peux soit renseigner les variables DB_* separement,
# soit utiliser une seule variable DATABASE_URL (format
# postgres://user:password@host:port/nom) -- les deux fonctionnent.
import dj_database_url

DATABASE_URL = config('DATABASE_URL', default='')
if DATABASE_URL:
    DATABASES = {'default': dj_database_url.parse(DATABASE_URL)}
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': config('DB_NAME', default='postgres'),
            'USER': config('DB_USER', default='postgres'),
            'PASSWORD': config('DB_PASSWORD', default=''),
            'HOST': config('DB_HOST', default=''),
            'PORT': config('DB_PORT', default='5432'),
        }
    }

# --- Validation des mots de passe (utilise seulement pour le Django Admin) ---
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Lome'   # heure du Togo (GMT, pas de changement d'heure)
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'   # necessaire pour que whitenoise serve les fichiers en production
STORAGES = {
    'staticfiles': {
        'BACKEND': 'whitenoise.storage.CompressedManifestStaticFilesStorage',
    },
}
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# --- Django REST Framework ---
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'core.authentication.SimpleTokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

# --- CORS : autorise l'app Flutter (et un futur site web) a appeler l'API ---
# En developpement on autorise tout ; a restreindre en production.
CORS_ALLOW_ALL_ORIGINS = config('DEBUG', default=True, cast=bool)

# --- Cles Supabase (verification des tokens d'authentification) ---
SUPABASE_URL = config('SUPABASE_URL', default='')
SUPABASE_ANON_KEY = config('SUPABASE_ANON_KEY', default='')
SUPABASE_SERVICE_ROLE_KEY = config('SUPABASE_SERVICE_ROLE_KEY', default='')

# --- MQTT ---
MQTT_BROKER_HOST = config('MQTT_BROKER_HOST', default='')
MQTT_BROKER_PORT = config('MQTT_BROKER_PORT', default=8883, cast=int)
MQTT_USERNAME = config('MQTT_USERNAME', default='')
MQTT_PASSWORD = config('MQTT_PASSWORD', default='')

# --- SMS (Africa's Talking, optionnel en phase pilote) ---
AFRICASTALKING_USERNAME = config('AFRICASTALKING_USERNAME', default='')
AFRICASTALKING_API_KEY = config('AFRICASTALKING_API_KEY', default='')
