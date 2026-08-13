#!/usr/bin/env bash
# Démarre server.py en arrière-plan si rien n'écoute déjà sur le port —
# idempotent : relancer sur un serveur déjà en route ne fait rien (pas de
# doublon, pas d'erreur "port déjà utilisé"). Pensé pour être appelé depuis
# un bouton Stream Deck (via la mini-app .app générée par make-apps.sh),
# donc jamais de fenêtre Terminal qui s'ouvre, jamais de sortie interactive.
set -euo pipefail

PORT="${1:-5500}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDFILE="$ROOT/.server.pid"
LOGFILE="$ROOT/.server.log"

existing_pid="$(lsof -ti ":$PORT" 2>/dev/null || true)"
if [ -n "$existing_pid" ]; then
  echo "déjà lancé (pid $existing_pid, port $PORT)"
  exit 0
fi

cd "$ROOT"
nohup python3 server.py "$PORT" > "$LOGFILE" 2>&1 &
new_pid=$!
disown
echo "$new_pid" > "$PIDFILE"

# laisse une seconde au serveur pour se lier au port, puis vérifie que ça a
# vraiment pris — sinon le bouton "start" mentirait en cas d'échec silencieux
sleep 1
if lsof -ti ":$PORT" > /dev/null 2>&1; then
  echo "démarré (pid $new_pid, port $PORT)"
  exit 0
else
  echo "échec du démarrage — voir $LOGFILE"
  exit 1
fi
