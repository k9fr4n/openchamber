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
RUN set -eux; \
    . /tmp/versions.env; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        "gh=${GH_VERSION}" \
        "glab=${GLAB_VERSION}" \
        "curl=${CURL_VERSION}" \
        "jq=${JQ_VERSION}" \
        "iproute2=${IPROUTE2_VERSION}" \
        "procps=${PROCPS_VERSION}" \
        "lsof=${LSOF_VERSION}"; \
    rm -rf /var/lib/apt/lists/*

# CLI Docker (binaire statique officiel) : pilote le démon de l'hôte à travers
# /var/run/docker.sock, monté par Docker Compose.
RUN set -eux; \
    . /tmp/versions.env; \
    case "$(dpkg --print-architecture)" in \
      arm64) docker_arch=aarch64 ;; \
      amd64) docker_arch=x86_64 ;; \
      *) echo "architecture non gérée : $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/docker.tgz \
      "https://download.docker.com/linux/static/stable/${docker_arch}/docker-${DOCKER_CLI_VERSION}.tgz"; \
    tar -xzf /tmp/docker.tgz -C /tmp; \
    install -m 0755 /tmp/docker/docker /usr/local/bin/docker; \
    rm -rf /tmp/docker /tmp/docker.tgz

# yq (mikefarah) : binaire officiel, vérifié par somme SHA256.
RUN set -eux; \
    . /tmp/versions.env; \
    case "$(dpkg --print-architecture)" in \
      arm64) yq_arch=arm64 ;; \
      amd64) yq_arch=amd64 ;; \
      *) echo "architecture non gérée : $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}"; \
    curl -fsSL -o "/tmp/yq_linux_${yq_arch}" "${base}/yq_linux_${yq_arch}"; \
    curl -fsSL -o /tmp/yq_checksums "${base}/checksums"; \
    (cd /tmp && grep -E "[[:space:]]yq_linux_${yq_arch}$" yq_checksums | sha256sum -c -); \
    install -m 0755 "/tmp/yq_linux_${yq_arch}" /usr/local/bin/yq; \
    rm -f "/tmp/yq_linux_${yq_arch}" /tmp/yq_checksums

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