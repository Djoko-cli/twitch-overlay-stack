#!/usr/bin/env bash
# Affiche l'état du serveur et sort avec un code adapté à un script appelant
# (0 = en route, 1 = arrêté) — utilisable aussi bien par un humain que par un
# futur plugin Stream Deck qui interrogerait ce script pour son feedback visuel.
set -euo pipefail

PORT="${1:-5500}"

pid="$(lsof -ti ":$PORT" 2>/dev/null || true)"
if [ -n "$pid" ]; then
  echo "en route (pid $pid, port $PORT)"
  exit 0
else
  echo "arrêté (port $PORT)"
  exit 1
fi
