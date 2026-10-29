#!/usr/bin/env bash
# Met à jour OpenChamber : récupère les dernières images de TOUS les services
# du compose (openchamber, playwright-mcp, ...) et recrée uniquement les
# conteneurs dont l'image ou la configuration a changé (`up -d` ne touche
# pas aux conteneurs déjà à jour, pas besoin de --force-recreate).
set -euo pipefail
cd "$(dirname "$0")/.."

# IDs des images utilisées par les conteneurs avant mise à jour
# (vide au premier lancement).
before=$(for c in $(docker compose ps -q 2>/dev/null); do
  docker inspect --format '{{.Image}}' "$c"
done 2>/dev/null | sort -u || true)

docker compose pull

docker compose up -d

# IDs après mise à jour : identiques => rien n'a changé.
after=$(for c in $(docker compose ps -q 2>/dev/null); do
  docker inspect --format '{{.Image}}' "$c"
done 2>/dev/null | sort -u || true)

if [ -n "$before" ] && [ "$before" = "$after" ]; then
  echo "Déjà à jour."
else
  echo "Conteneurs mis à jour."
  # Nettoie les anciennes images devenues orphelines.
  docker image prune -f >/dev/null
fi

docker compose ps
