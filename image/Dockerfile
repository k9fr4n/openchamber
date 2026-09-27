# Surcouche de l'image OpenChamber : outils en ligne de commande.
#
# Les versions sont centralisées dans versions.env (source unique).
# En CI, BASE_IMAGE pointe vers l'image de base construite localement ;
# on peut aussi construire depuis l'image publiée :
#
#   docker build --tag openchamber-local .

ARG BASE_IMAGE=ghcr.io/k9fr4n/openchamber:latest
FROM ${BASE_IMAGE}

COPY versions.env /tmp/versions.env

# Le conteneur tourne en utilisateur `openchamber` (UID 1000) :
# repasser root uniquement le temps d'installer les outils.
USER root

# Paquets Debian (versions épinglées dans versions.env).
# Si une épingle a expiré (mise à jour Debian en cours de propagation), on
# retombe sur les versions courantes de trixie avec un avertissement visible
# dans les logs de build : le déploiement ne casse pas.
RUN set -eux; \
    . /tmp/versions.env; \
    apt-get update; \
    if ! apt-get install -y --no-install-recommends \
        "gh=${GH_VERSION}" \
        "glab=${GLAB_VERSION}" \
        "curl=${CURL_VERSION}" \
        "jq=${JQ_VERSION}" \
        "iproute2=${IPROUTE2_VERSION}" \
        "procps=${PROCPS_VERSION}" \
        "lsof=${LSOF_VERSION}"; then \
      echo ""; \
      echo "AVERTISSEMENT : une version épinglée dans image/versions.env n'est plus disponible."; \
      echo "Installation des versions courantes de trixie — actualiser image/versions.env."; \
      echo ""; \
      apt-get update; \
      apt-get install -y --no-install-recommends gh glab curl jq iproute2 procps lsof; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# CLI Docker (binaire statique officiel) : pilote le démon de l'hôte à travers
# /var/run/docker.sock, monté par Docker Compose. Archive vérifiée par SHA256.
RUN set -eux; \
    . /tmp/versions.env; \
    case "$(dpkg --print-architecture)" in \
      arm64) docker_arch=aarch64; sha_var=DOCKER_CLI_SHA256_ARM64 ;; \
      amd64) docker_arch=x86_64; sha_var=DOCKER_CLI_SHA256_AMD64 ;; \
      *) echo "architecture non gérée : $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/docker.tgz \
      "https://download.docker.com/linux/static/stable/${docker_arch}/docker-${DOCKER_CLI_VERSION}.tgz"; \
    eval "docker_sha=\${${sha_var}:-}"; \
    if [ -n "$docker_sha" ]; then \
      printf '%s  %s\n' "$docker_sha" /tmp/docker.tgz | sha256sum -c -; \
    else \
      echo "AVERTISSEMENT : ${sha_var} vide dans versions.env, archive non vérifiée."; \
    fi; \
    tar -xzf /tmp/docker.tgz -C /tmp; \
    install -m 0755 /tmp/docker/docker /usr/local/bin/docker; \
    rm -rf /tmp/docker /tmp/docker.tgz

# yq (mikefarah) : binaire officiel, vérifié par le fichier checksums-bsd.
RUN set -eux; \
    . /tmp/versions.env; \
    case "$(dpkg --print-architecture)" in \
      arm64) yq_arch=arm64 ;; \
      amd64) yq_arch=amd64 ;; \
      *) echo "architecture non gérée : $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}"; \
    curl -fsSL -o "/tmp/yq_linux_${yq_arch}" "${base}/yq_linux_${yq_arch}"; \
    hash=$(curl -fsSL "${base}/checksums-bsd" | sed -n "s/^SHA256 (yq_linux_${yq_arch}) = //p"); \
    printf '%s  %s\n' "$hash" "/tmp/yq_linux_${yq_arch}" | sha256sum -c -; \
    install -m 0755 "/tmp/yq_linux_${yq_arch}" /usr/local/bin/yq; \
    rm -f "/tmp/yq_linux_${yq_arch}"

# Trace des versions installées dans les logs de build.
RUN set -eux; \
    gh --version | head -n 1; \
    glab --version; \
    docker --version; \
    curl --version | head -n 1; \
    jq --version; \
    yq --version; \
    ip -V; \
    ps --version; \
    lsof -v 2>&1 | head -n 2

RUN rm -f /tmp/versions.env
USER openchamber