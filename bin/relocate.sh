#!/usr/bin/env bash
# Met à jour tous les chemins codés en dur après un déplacement du dossier du
# projet — les .applescript (recompilés en .app) et le plugin Stream Deck
# (recompilé et republié). server.py et bin/server-*.sh n'ont rien de codé en
# dur (ils se localisent eux-mêmes) : rien à faire pour eux.
#
# Usage : lance ce script DEPUIS LE NOUVEL EMPLACEMENT, après avoir déplacé
# tout le dossier :
#   /nouveau/chemin/Twitch/bin/relocate.sh
#
# Fonctionne pour des déplacements en chaîne (A → B, puis B → C, etc.) :
# l'ancien chemin est LU depuis le contenu actuel des fichiers plutôt que
# supposé fixe, donc chaque appel repart de l'état réel, pas d'un chemin
# d'origine qui ne serait plus d'actualité après un premier déplacement.
set -euo pipefail

NEW_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF_FILE="$NEW_ROOT/bin/Start Server.applescript"

if [ ! -f "$REF_FILE" ]; then
  echo "Impossible de trouver '$REF_FILE' — le dossier bin/ est-il complet ?"
  exit 1
fi

# extrait le chemin actuellement codé en dur, quel qu'il soit, plutôt que de
# supposer un chemin d'origine fixe
OLD_ROOT="$(grep -o '"[^"]*/bin/server-start\.sh' "$REF_FILE" | head -1 | sed 's|^"||; s|/bin/server-start\.sh$||')"

if [ -z "$OLD_ROOT" ]; then
  echo "Chemin actuel introuvable dans '$REF_FILE' — rien à remplacer automatiquement."
  exit 1
fi

if [ "$NEW_ROOT" = "$OLD_ROOT" ]; then
  echo "Le dossier est encore à $OLD_ROOT — rien à faire."
  exit 0
fi

echo "Ancien chemin détecté : $OLD_ROOT"
echo "Nouveau chemin        : $NEW_ROOT"
echo

# ---- 1. Sources .applescript ------------------------------------------
echo "→ mise à jour des .applescript"
for f in "$NEW_ROOT"/bin/*.applescript; do
  sed -i '' "s|$OLD_ROOT|$NEW_ROOT|g" "$f"
done

echo "→ recompilation des .app"
"$NEW_ROOT/bin/make-apps.sh"

# ---- 2. Plugin Stream Deck ----------------------------------------------
PLUGIN_TS="$NEW_ROOT/streamdeck-plugin/src/actions/toggle-server.ts"
if [ -f "$PLUGIN_TS" ]; then
  echo "→ mise à jour du plugin Stream Deck"
  sed -i '' "s|$OLD_ROOT|$NEW_ROOT|g" "$PLUGIN_TS"

  if [ -d "$NEW_ROOT/streamdeck-plugin/node_modules" ]; then
    # cd explicite avant pack : sans ça, le .streamDeckPlugin de sortie est
    # écrit relatif au répertoire courant de l'appelant, pas à côté de la
    # source — et peut atterrir n'importe où selon d'où ce script est lancé.
    (
      cd "$NEW_ROOT/streamdeck-plugin"
      npm run build
      npx --yes @elgato/cli@1.8.1 pack com.majid.twitch-server-control.sdPlugin -f
    )
    echo
    echo "⚠️  Un nouveau com.majid.twitch-server-control.streamDeckPlugin a été"
    echo "   généré dans streamdeck-plugin/. Double-clique dessus pour"
    echo "   réinstaller le plugin avec le chemin à jour — sinon la version"
    echo "   déjà installée dans Stream Deck garde l'ANCIEN chemin."
  else
    echo "⚠️  streamdeck-plugin/node_modules absent — lance 'npm install' dans"
    echo "   streamdeck-plugin/ puis relance ce script pour reconstruire le"
    echo "   plugin avec le nouveau chemin."
  fi
fi

echo
echo "✔ Terminé. Pense à relancer server.py depuis ce nouvel emplacement :"
echo "  cd \"$NEW_ROOT\" && python3 server.py 5500"
