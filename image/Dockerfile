# Surcouche de l'image OpenChamber : outils en ligne de commande.
#
# Les versions des binaires amont (docker, yq, codebase-memory-mcp) sont
# centralisées dans versions.env (source unique). Les paquets Debian ne sont
# pas épinglés : ils suivent la version courante de trixie.
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

# Paquets Debian : installés dans la version courante de trixie par APT.
# Ils ne sont volontairement pas épinglés (voir versions.env) : une épingle
# périmait régulièrement et le build retombait alors sur la version courante,
# pour une maintenance constante sans reproductibilité réelle.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        gh glab curl wget jq sshpass rsync python3-pip vim iproute2 procps \
        lsof gnupg bsdextrautils patch xz-utils bzip2 tree \
        iputils-ping iputils-tracepath traceroute bind9-dnsutils bind9-host \
        netcat-openbsd whois ethtool net-tools; \
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

# codebase-memory-mcp (DeusData) : native code-intelligence MCP server.
# Fully static "-portable" Linux build (same choice as upstream install.sh) :
# no glibc requirement, works on any base. Archive verified by SHA256 from
# versions.env, then only the binary is extracted to /usr/local/bin.
RUN set -eux; \
    . /tmp/versions.env; \
    case "$(dpkg --print-architecture)" in \
      arm64) cbm_arch=arm64; cbm_sha=${CBM_SHA256_ARM64} ;; \
      amd64) cbm_arch=amd64; cbm_sha=${CBM_SHA256_AMD64} ;; \
      *) echo "architecture non gérée : $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    archive="codebase-memory-mcp-linux-${cbm_arch}-portable.tar.gz"; \
    curl -fsSL -o "/tmp/${archive}" \
      "https://github.com/DeusData/codebase-memory-mcp/releases/download/${CBM_VERSION}/${archive}"; \
    printf '%s  %s\n' "$cbm_sha" "/tmp/${archive}" | sha256sum -c -; \
    tar -xzf "/tmp/${archive}" -C /tmp codebase-memory-mcp; \
    install -m 0755 /tmp/codebase-memory-mcp /usr/local/bin/codebase-memory-mcp; \
    rm -f "/tmp/${archive}" /tmp/codebase-memory-mcp; \
    codebase-memory-mcp --version

# Vérifie que tous les outils attendus sont présents et trace leurs versions
# dans les logs de build : le build échoue si un outil manque.
RUN set -eux; \
    for c in curl wget jq yq git ssh scp sshpass rsync python3 pip3 vim gh glab docker ip ss ps lsof gpg column patch xz bzip2 tree codebase-memory-mcp \
             ping tracepath traceroute dig nslookup host nc netcat whois ethtool netstat ifconfig route arp; do \
      command -v "$c" >/dev/null 2>&1 || { echo "ERREUR : $c est introuvable" >&2; exit 1; }; \
    done; \
    curl --version | head -n 1; \
    wget --version | head -n 1; \
    jq --version; \
    yq --version; \
    git --version; \
    ssh -V 2>&1; \
    sshpass -V | head -n 1; \
    rsync --version | head -n 1; \
    python3 --version; \
    pip3 --version; \
    vim --version | head -n 1; \
    gh --version | head -n 1; \
    glab --version; \
    docker --version; \
    ip -V; \
    ps --version; \
    lsof -v 2>&1 | head -n 2; \
    gpg --version | head -n 1; \
    column --version | head -n 1; \
    patch --version | head -n 1; \
    xz --version | head -n 1; \
    bzip2 --version | head -n 1; \
    tree --version | head -n 1; \
    codebase-memory-mcp --version; \
    echo "--- diagnostic réseau ---"; \
    dpkg-query -W -f '${binary:Package} ${Version}\n' \
      iputils-ping iputils-tracepath traceroute bind9-dnsutils bind9-host \
      netcat-openbsd whois ethtool net-tools

# Forwarder 0.0.0.0:9748 -> 127.0.0.1:9749 : l'UI cbm n'écoute que sur
# localhost, sans option d'adresse d'écoute — Traefik et les ports publiés
# sont sans effet sans ce pont (stdlib uniquement, voir cbm-ui-forward.py).
# Le wrapper démarre ce forwarder puis l'entrypoint standard (voir ENTRYPOINT
# en fin de fichier) : aucun changement nécessaire dans docker-compose.yml.
COPY cbm-ui-forward.py openchamber-entrypoint-with-cbm-ui.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/cbm-ui-forward.py /usr/local/bin/openchamber-entrypoint-with-cbm-ui.sh && \
    python3 -B -m py_compile /usr/local/bin/cbm-ui-forward.py && \
    sh -n /usr/local/bin/openchamber-entrypoint-with-cbm-ui.sh

# xdg-open shim for headless container: CLI tools (e.g. `opencode auth login`)
# spawn `xdg-open <url>` to start a browser OAuth/device flow. There is no
# browser inside the container, so print the URL instead and let the user
# open it on the host. Real xdg-utils would still fail without a browser.
RUN printf '#!/bin/sh\nprintf "Open in your browser: %%s\\n" "$*"\n' > /usr/local/bin/xdg-open && \
    chmod 0755 /usr/local/bin/xdg-open && \
    xdg-open "https://example.invalid/__selftest__"

RUN rm -f /tmp/versions.env
USER openchamber

# Seed codebase-memory-mcp defaults into the image layer (~/.cache is not a
# mounted volume, so this survives container restarts) : new projects are
# indexed automatically on first MCP session instead of on explicit request,
# and the 3D graph UI is served on port 9749 (same defaults as
# `codebase-memory-mcp --ui=true --port=9749`, persisted via config keys).
RUN codebase-memory-mcp config set auto_index true && \
    codebase-memory-mcp config set ui_enabled true && \
    codebase-memory-mcp config set ui_port 9749 && \
    codebase-memory-mcp config list

# Note : les labels Traefik de l'UI sont dans docker-compose.yml (convention
# du repo : tout le routage est déclaré côté compose), pas ici : quand un
# conteneur expose deux services (openchamber:3000 + cbm-ui:9748), Traefik
# exige une liaison routeur->service explicite, posée côté compose.

# Wrapper : forwarder UI cbm + entrypoint standard. Les args éventuels
# (command:, exec, run) sont transmis à l'entrypoint d'origine.
ENTRYPOINT ["/usr/local/bin/openchamber-entrypoint-with-cbm-ui.sh"]
