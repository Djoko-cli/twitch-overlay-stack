#!/usr/bin/env bash
# Recompile les .app depuis les sources .applescript — à relancer seulement
# si tu modifies un .applescript, ou si tu déplaces le dossier du projet
# (les chemins sont codés en dur dans les .applescript ; édite-les d'abord).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

for name in "Start Server" "Stop Server" "Toggle Server" "Server Status"; do
  osacompile -o "$name.app" "$name.applescript"
  echo "compilé : $name.app"
done
