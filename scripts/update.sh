#!/usr/bin/env bash
# Met à jour OpenChamber : récupère la dernière image GHCR et recrée le
# conteneur uniquement si l'image a changé.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose pull openchamber

# ID de l'image utilisée par le conteneur (vide s'il n'existe pas encore).
CURRENT_ID=$(docker inspect --format '{{.Image}}' openchamber 2>/dev/null || true)

# Référence d'image résolue par Compose (tient compte de .env).
TARGET_REF=$(docker compose config --images | head -n1)
TARGET_ID=$(docker image inspect "$TARGET_REF" --format '{{.Id}}')

if [ -n "$CURRENT_ID" ] && [ "$CURRENT_ID" = "$TARGET_ID" ]; then
  echo "Déjà à jour ($TARGET_REF)."
  docker compose up -d
else
  echo "Nouvelle image détectée, recréation du conteneur..."
  docker compose up -d --force-recreate
  # Nettoie l'ancienne image devenue orpheline.
  docker image prune -f >/dev/null
fi

docker compose ps