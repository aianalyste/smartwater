#!/usr/bin/env python
"""Utilitaire en ligne de commande de Django pour SmartWater."""
import os
import sys


def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartwater_backend.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Django n'est pas installe. As-tu bien active ton environnement "
            "virtuel et lance 'pip install -r requirements.txt' ?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
