"""
Permissions personnalisees pour l'onglet Options (equivalent Django
Admin dans l'app), reserve aux roles admin et agronome.
"""

from rest_framework.permissions import BasePermission


class EstAdminOuAgronome(BasePermission):
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            request.user.role in ('admin', 'agronome')
        )