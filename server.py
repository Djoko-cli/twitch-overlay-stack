#!/usr/bin/env python3
"""Serveur local pour la stack d'overlays — sert les fichiers statiques
comme `python3 -m http.server`, plus un petit point d'API (`/api/timer`)
pour l'état du minuteur "starting soon".

Pourquoi pas juste localStorage, comme les autres ponts du projet (Twitch,
Spotify) ? Ceux-là marchent parce que les deux pages tournent dans LE MÊME
moteur de navigateur (la source Browser d'OBS, un CEF Chromium isolé). Ici,
le panneau de contrôle est censé tourner dans ton navigateur normal pendant
qu'OBS affiche la source dans le sien : ce sont deux moteurs différents avec
chacun leur propre stockage, même en visant la même URL. Un vrai
aller-retour réseau vers ce serveur est le seul pont qui fonctionne dans les
deux sens, peu importe qui appelle.

Usage : python3 server.py [port]   (5500 par défaut, comme avant)
"""
import http.server
import json
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
STATE_FILE = os.path.join(ROOT, '.timer-state.json')


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/timer':
            body = b'{}'
            if os.path.exists(STATE_FILE):
                with open(STATE_FILE, 'rb') as f:
                    body = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        if self.path == '/api/timer':
            length = int(self.headers.get('Content-Length', 0))
            raw = self.rfile.read(length)
            try:
                state = json.loads(raw)
            except ValueError:
                self.send_response(400)
                self.end_headers()
                return
            with open(STATE_FILE, 'w') as f:
                json.dump(state, f)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(state).encode())
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, fmt, *args):
        # discret : n'affiche que les erreurs, pas chaque GET de fichier statique
        if not args or not str(args[0]).startswith(('GET', 'POST')) or ' 200' not in ' '.join(map(str, args)):
            super().log_message(fmt, *args)


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5500
    os.chdir(ROOT)
    server = http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler)
    print(f"Overlays Twitch — http://127.0.0.1:{port}  (état du minuteur synchronisé via /api/timer)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
