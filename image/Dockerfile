# Surcouche de l'image OpenChamber : ajoute les CLI GitHub (gh) et GitLab (glab).
#
# L'image de base est celle construite depuis les sources upstream
# (voir .github/workflows/build-image.yml). En CI, BASE_IMAGE pointe vers
# l'image de base construite localement ; on peut aussi construire depuis
# l'image publiée :
#
#   docker build --tag openchamber-local image/

ARG BASE_IMAGE=ghcr.io/k9fr4n/openchamber:latest
FROM ${BASE_IMAGE}

# Le conteneur tourne en utilisateur `openchamber` (UID 1000) :
# repasser root uniquement le temps d'installer les paquets.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gh glab \
    && rm -rf /var/lib/apt/lists/*

USER openchamber