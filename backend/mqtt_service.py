"""
Petit service qui garde le listener MQTT actif en continu sur Render
(plan gratuit) : le vrai listener tourne dans un thread separe, et
un mini serveur HTTP repond aux "pings" reguliers (via cron-job.org)
pour empecher Render de mettre ce service en veille.

Usage sur Render : Start Command = "python mqtt_service.py"
"""

import os
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartwater_backend.settings')

import django
django.setup()

from mqtt_client.mqtt_listener import demarrer_listener


class PingHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'MQTT listener actif')

    def log_message(self, format, *args):
        pass


def demarrer_serveur_ping():
    port = int(os.environ.get('PORT', 10000))
    serveur = HTTPServer(('0.0.0.0', port), PingHandler)
    serveur.serve_forever()


if __name__ == '__main__':
    thread_mqtt = threading.Thread(target=demarrer_listener, daemon=True)
    thread_mqtt.start()

    demarrer_serveur_ping()