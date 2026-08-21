"""
Authentification simplifiee pour la phase pilote : pas de mot de
passe, pas d'OTP -- l'app envoie le "session_token" recu a
l'inscription dans l'en-tete Authorization de chaque requete :

    Authorization: Token <session_token>
"""

from rest_framework import authentication, exceptions
from .models import Utilisateur


class SimpleTokenAuthentication(authentication.BaseAuthentication):

    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Token '):
            return None

        token = auth_header.split(' ', 1)[1]

        try:
            utilisateur = Utilisateur.objects.get(session_token=token)
        except Utilisateur.DoesNotExist:
            raise exceptions.AuthenticationFailed('Session invalide -- reconnecte-toi.')

        return (utilisateur, token)