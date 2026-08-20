"""
Verification des tokens envoyes par l'app Flutter (authentifies via
Supabase Auth : telephone + OTP).

Principe : l'app Flutter recoit un token JWT de Supabase apres
connexion, et l'envoie dans chaque requete API sous la forme
    Authorization: Bearer <token>
Ce fichier verifie ce token aupres de Supabase et retrouve/cree
l'Utilisateur correspondant dans notre base.

A FAIRE avant la mise en production : remplacer la verification
simplifiee ci-dessous par une vraie verification de signature JWT
avec la cle publique Supabase (voir docs/DEPLOIEMENT.md, section
"Securiser l'authentification").
"""

import requests
from django.conf import settings
from rest_framework import authentication, exceptions

from .models import Utilisateur


class SupabaseAuthentication(authentication.BaseAuthentication):

    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return None  # pas de token -> laisse DRF gerer le refus d'acces

        token = auth_header.split(' ', 1)[1]

        # Verifie le token aupres de Supabase (endpoint /auth/v1/user)
        response = requests.get(
            f"{settings.SUPABASE_URL}/auth/v1/user",
            headers={
                'Authorization': f'Bearer {token}',
                'apikey': settings.SUPABASE_ANON_KEY,
            },
            timeout=5,
        )
        if response.status_code != 200:
            raise exceptions.AuthenticationFailed('Token Supabase invalide ou expire.')

        supabase_user = response.json()
        supabase_user_id = supabase_user.get('id')
        telephone = supabase_user.get('phone', '')

        utilisateur, _ = Utilisateur.objects.get_or_create(
            supabase_user_id=supabase_user_id,
            defaults={'telephone': telephone},
        )
        return (utilisateur, token)
