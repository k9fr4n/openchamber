#!/usr/bin/env bash
# Met à jour OpenChamber : récupère la dernière image GHCR et recrée le conteneur.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose pull openchamber
docker compose up -d --remove-orphans

# Nettoie les anciennes couches devenues orphelines (images <none>).
docker image prune -f >/dev/null

docker compose ps