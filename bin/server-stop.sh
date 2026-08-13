#!/usr/bin/env bash
# Arrête le serveur écoutant sur le port — idempotent : appeler sur un
# serveur déjà arrêté ne fait rien. Tue par port plutôt que par PID stocké
# comme source de vérité (le PID stocké peut être obsolète si le serveur a
# été relancé autrement), le fichier .server.pid n'est que du confort.
set -euo pipefail

PORT="${1:-5500}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDFILE="$ROOT/.server.pid"

pids="$(lsof -ti ":$PORT" 2>/dev/null || true)"
if [ -z "$pids" ]; then
  echo "déjà arrêté (rien sur le port $PORT)"
  rm -f "$PIDFILE"
  exit 0
fi

kill $pids 2>/dev/null || true
sleep 0.5

# SIGTERM insuffisant (rare, mais arrive) → on insiste avec SIGKILL
still="$(lsof -ti ":$PORT" 2>/dev/null || true)"
if [ -n "$still" ]; then
  kill -9 $still 2>/dev/null || true
fi

rm -f "$PIDFILE"
echo "arrêté (port $PORT libéré)"
