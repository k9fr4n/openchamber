# OpenChamber — déploiement Raspberry Pi

Repo de déploiement personnel pour [OpenChamber](https://github.com/openchamber/openchamber), l'environnement de développement agentique basé sur OpenCode.

L'image Docker **arm64** est construite par GitHub Actions directement depuis les sources upstream et publiée sur GHCR. Le Raspberry Pi ne construit rien : il télécharge l'image et la lance avec Docker Compose.

```text
openchamber/openchamber (upstream, version épinglée)
        │
        ▼  GitHub Actions (runner arm64 natif, sans QEMU)
ghcr.io/k9fr4n/openchamber:latest
        │
        ▼  docker compose pull
Raspberry Pi ── conteneur openchamber (port 3000)
```

L'image publiée est l'image upstream enrichie d'outils en ligne de commande : **`gh`**, **`glab`**, **`docker`** (client), **`curl`**, **`wget`**, **`jq`**, **`yq`**, **`codebase-memory-mcp`** (serveur MCP d'indexation du code, voir ci-dessous), **`sshpass`**, **`rsync`**, **`vim`**, **`pip`**, **`iproute2`**, **`procps`**, **`lsof`**, **`gpg`**, **`column`**, **`patch`**, **`xz`**, **`bzip2`** et **`tree`** — en plus de **`git`**, **`openssh-client`** et **`python3`** fournis par l'image upstream.

Le diagnostic réseau est couvert par **`ping`** (y compris `ping -6`), **`tracepath`**, **`traceroute`**, **`dig`**, **`nslookup`**, **`host`**, **`nc`**, **`whois`**, **`ethtool`**, ainsi que les commandes héritées **`netstat`**, **`ifconfig`**, **`route`** et **`arp`**. Ces outils viennent des paquets Debian de l'image, installés dans leur version courante.

## Prérequis (Pi)

- Raspberry Pi **64 bits** (Pi 4 ou Pi 5 recommandé) sous Raspberry Pi OS 64 bits, Debian ou Ubuntu arm64. Un OS 32 bits ne peut pas exécuter l'image.
- Docker Engine avec le plugin Compose (`docker compose version` doit répondre).
- ~2 Go de RAM libres et ~3 Go d'espace disque pour l'image.
- Accès sortant à `ghcr.io` pour télécharger l'image.

## Mise en route

### 1. Cloner le repo sur le Pi

```bash
git clone git@github.com:k9fr4n/openchamber.git ~/openchamber
cd ~/openchamber
```

### 2. Configurer le mot de passe

```bash
cp .env.example .env
openssl rand -base64 24   # copier le résultat dans OPENCHAMBER_UI_PASSWORD
nano .env
```

`.env` n'est jamais commité. C'est aussi le fichier où personnaliser l'espace de travail, le port et l'image.

### 3. S'authentifier sur GHCR

Le package GHCR est privé (comme ce repo), donc le Pi doit s'authentifier une fois :

1. Créer un token GitHub **classic** avec la seule permission `read:packages` : https://github.com/settings/tokens
2. Se connecter :

```bash
echo "LE_TOKEN" | docker login ghcr.io -u k9fr4n --password-stdin
```

> Variante sans token : rendre le package public (GitHub → onglet *Packages* → `openchamber` → *Package settings* → *Change visibility*), puis supprimer la connexion sur le Pi.

### 4. Lancer

```bash
docker compose up -d
docker compose ps
```

Ouvrir `http://<ip-du-pi>:3000` et se connecter avec le mot de passe défini à l'étape 2.

## Données et volumes

Tout est persisté dans le dossier du repo, sur le Pi :

| Chemin sur le Pi | Chemin dans le conteneur | Contenu |
| --- | --- | --- |
| `./data/openchamber` | `/home/openchamber/.config/openchamber` | Configuration OpenChamber (sessions, préférences) |
| `./data/opencode/share` | `/home/openchamber/.local/share/opencode` | Données partagées OpenCode (identifiants, providers) |
| `./data/opencode/state` | `/home/openchamber/.local/state/opencode` | État OpenCode |
| `./data/opencode/config` | `/home/openchamber/.config/opencode` | Configuration OpenCode |
| `./data/ssh` | `/home/openchamber/.ssh` | Clé SSH générée automatiquement pour les accès Git |
| `./workspaces` (ou `WORKSPACES_DIR`) | `/home/openchamber/workspaces` | Espace de travail exposé à l'agent |

Le contenu de `data/` est ignoré par git : il peut contenir des identifiants. Les dossiers vides sont eux versionnés (`.gitkeep`) pour qu'un clone soit directement utilisable — sinon Docker les créerait en `root:root`, illisibles par le conteneur (UID 1000).

## Authentification des CLI (gh / glab)

L'image embarque `gh` (GitHub) et `glab` (GitLab). Les deux sont authentifiés par variables d'environnement, injectées par Compose depuis `.env` — rien à configurer dans le conteneur, et les jetons ne sont jamais commités.

| Variable | CLI | Rôle |
| --- | --- | --- |
| `GH_TOKEN` | `gh` | Token GitHub (github.com), portée `repo` (+ `workflow` si nécessaire) |
| `GITLAB_TOKEN` | `glab` | Token GitLab (gitlab.ecritel.net), portée `api` (+ `write_repository` si nécessaire) |
| `GITLAB_HOST` / `GITLAB_API_HOST` | `glab` | Instance GitLab ciblée (défaut : `gitlab.ecritel.net`) |

Création des tokens :

- GitHub : https://github.com/settings/tokens (token classique)
- GitLab : https://gitlab.ecritel.net/-/user_settings/personal_access_tokens

Après avoir renseigné `.env`, recréer le conteneur et vérifier :

```bash
docker compose up -d
docker compose exec openchamber gh auth status
docker compose exec openchamber glab auth status
```

### Opérations git en SSH (optionnel)

Pour que l'agent puisse cloner ou pousser en SSH, ajouter la clé publique du conteneur à tes comptes GitHub/GitLab :

```bash
docker compose exec openchamber cat ~/.ssh/id_ed25519.pub
```

- GitHub : https://github.com/settings/keys
- GitLab : https://gitlab.ecritel.net/-/user_settings/ssh_keys

## Accès au démon Docker (socket)

Le socket du démon Docker du Pi est monté dans le conteneur, avec le client `docker` : l'agent peut inspecter et gérer les conteneurs, images et volumes de l'hôte.

- Le socket est monté via `/var/run/docker.sock:/var/run/docker.sock`.
- Compose ajoute le GID du groupe `docker` de l'hôte (`group_add`), réglable via `DOCKER_GID` dans `.env` — le vérifier sur le Pi avec `getent group docker | cut -d: -f3`.

> ⚠️ Le socket Docker donne au conteneur un contrôle équivalent à `root` sur l'hôte (tous les conteneurs, images et volumes du Pi). À garder pour un usage de confiance.

Vérification :

```bash
docker compose exec openchamber docker ps
```

## Espace de travail

Par défaut, l'agent travaille dans `./workspaces`, à côté du repo. Pour travailler sur des repos déjà présents sur le Pi, définir dans `.env` :

```bash
WORKSPACES_DIR=/home/pi/gitlab
```

Le dossier monté est accessible en lecture/écriture par l'agent : ne monter que ce qui est nécessaire.

## Indexation du code (codebase-memory-mcp)

L'image embarque [`codebase-memory-mcp`](https://github.com/DeusData/codebase-memory-mcp) (`/usr/local/bin/codebase-memory-mcp`), un serveur MCP qui indexe le code en graphe de connaissances local (recherche structurelle, callers/callees, architecture). L'auto-indexation est activée dans l'image (`codebase-memory-mcp config set auto_index true`) : un projet est indexé automatiquement à la première session MCP, sans demande explicite.

L'UI 3D de visualisation du graphe est activée dans l'image (équivalent persisté de `codebase-memory-mcp --ui=true --port=9749`, via `config set ui_enabled true` + `config set ui_port 9749`) et servie par le conteneur `openchamber` lui-même : l'UI n'écoutant que sur `127.0.0.1` sans option d'adresse, l'image embarque un forwarder stdlib (`image/cbm-ui-forward.py`, `0.0.0.0:9748` → `127.0.0.1:9749`), démarré par un wrapper d'entrypoint (`image/openchamber-entrypoint-with-cbm-ui.sh`). Le routage Traefik (`https://cbm-ui.ecritel.net` → port `9748`) est déclaré dans `docker-compose.yml`, avec des liaisons routeur→service explicites : dès qu'un conteneur expose deux services, Traefik refuse les routeurs sans liaison explicite (`cannot be linked automatically with multiple Services`) — sans elles, même `openchamber.ecritel.net` tombe en 404. Le compose des MCP n'est pas touché : une seule instance, un seul index — celui de l'agent. L'UI ne répond qu'après démarrage du daemon (première session MCP).

> ⚠️ L'UI n'a aucune authentification. Ne pas exposer `cbm-ui.ecritel.net` sans protection (middleware Traefik `ipAllowList` ou `basicAuth`) si le Pi est joignable depuis Internet. Note : l'UI refuse tout `Host` non-local (`403 forbidden host`, anti-rebinding) — le routeur réécrit donc `Host` en `127.0.0.1` via le middleware `cbm-ui-host` après le routage.

Accès LAN (optionnel, non commité) : ajouter dans `docker-compose.yml`, sous `ports` :

```yaml
      - "${CBM_UI_PORT:-9749}:9748"
```

puis ouvrir `http://<ip-du-pi>:9749`.

Pour l'exposer à l'agent, déclarer le serveur dans `opencode.json` (fichier persisté via le volume `data/opencode/config`). Le point important est **`"codemode": false`** : sans cela, OpenCode regroupe les 17 outils derrière le Code Mode au lieu de les exposer directement, ce que ce serveur ne supporte pas bien :

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "codebase-memory-mcp": {
        "type": "local",
        "command": ["/usr/local/bin/codebase-memory-mcp"],
        "codemode": false
      }
    }
  }
}
```

Vérification dans le conteneur :

```bash
docker compose exec openchamber codebase-memory-mcp --version
docker compose exec openchamber codebase-memory-mcp config get auto_index
docker compose exec openchamber codebase-memory-mcp config get ui_enabled
docker compose exec openchamber codebase-memory-mcp config get ui_port
docker compose exec openchamber curl -s -o /dev/null -w "%{http_code}\n" http://localhost:9748/   # via le forwarder
docker compose exec openchamber curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9749/  # UI directe
```

> Note : `codebase-memory-mcp install --clients=opencode` écrit la même entrée (sans `codemode`) dans le fichier managé d'OpenChamber ; préférer la déclaration ci-dessus dans `opencode.json` pour garder `codemode: false`.

## Mettre à jour la version d'OpenChamber

Deux façons de reconstruire l'image depuis une nouvelle version upstream :

- **Depuis GitHub** : onglet *Actions* → *Build image arm64* → *Run workflow* → indiquer le tag souhaité (ex. `v2.1.0`).
- **Via un commit** : changer `UPSTREAM_REF_DEFAULT` dans `.github/workflows/build-image.yml` puis pousser sur `main` — la build se déclenche automatiquement.

Ensuite, sur le Pi :

```bash
cd ~/openchamber
git pull
./scripts/update.sh
```

Le script ne recrée le conteneur que si l'image a changé.

Tous les paquets Debian de l'image (c'est-à-dire tous les outils sauf `docker`, `yq` et `codebase-memory-mcp`) suivent la version courante de trixie : ils sont rafraîchis à chaque rebuild, sans épingle à maintenir. Seuls les binaires amont **`docker`**, **`yq`** et **`codebase-memory-mcp`** sont épinglés dans [`image/versions.env`](image/versions.env) : modifier une valeur, pousser sur `main` — le workflow reconstruit l'image automatiquement.

L'image publiée est taguée `latest`, `vX.Y.Z` (ref upstream) et `sha-<commit>` ; pour épingler une version précise, définir `OPENCHAMBER_IMAGE=ghcr.io/k9fr4n/openchamber:vX.Y.Z` dans `.env`.

## Accès distant

- **LAN / VPN** : comportement par défaut, `http://<ip-du-pi>:3000`.
- **Tunnel Cloudflare** : `cloudflared` est embarqué dans l'image ; décommenter les variables `OPENCHAMBER_TUNNEL_*` dans `docker-compose.yml` (mode `quick`, ou `managed-remote` avec un domaine et un token).
- **Reverse proxy** : Nginx/Caddy/Traefik nécessitent le support WebSocket et le SSE sans buffering — voir le guide upstream [docs/REVERSE_PROXY.md](https://github.com/openchamber/openchamber/blob/main/docs/REVERSE_PROXY.md).

## Dépannage

- **`docker compose up` échoue avec `OPENCHAMBER_UI_PASSWORD`** : le fichier `.env` manque ou la variable est vide (étape 2).
- **`denied` au téléchargement de l'image** : refaire `docker login ghcr.io` avec un token ayant `read:packages`, ou rendre le package public.
- **Le workflow Actions échoue** : regarder les logs dans l'onglet *Actions* ; vérifier que le ref upstream demandé existe (`gh api repos/openchamber/openchamber/tags`).
- **Le port 3000 est déjà pris** : définir `OPENCHAMBER_PORT=3001` dans `.env`.
- **`EACCES: permission denied` dans les logs, conteneur en boucle de redémarrage** : les dossiers de données appartiennent à `root` (créés par un clone antérieur aux `.gitkeep`). Corriger sans `sudo` :

  ```bash
  docker run --rm -v "$PWD/data:/data" -v "$PWD/workspaces:/workspaces" alpine:3.21 \
    sh -c "chown -R 1000:1000 /data /workspaces && chmod 700 /data/ssh"
  docker compose up -d --force-recreate
  ```

- **`gh auth status` ou `glab auth status` indique « non authentifié »** : `GH_TOKEN` / `GITLAB_TOKEN` sont vides dans `.env` (voir la section *Authentification des CLI*).
- **`permission denied` sur `/var/run/docker.sock`** : `DOCKER_GID` dans `.env` ne correspond pas au groupe `docker` du Pi (`getent group docker | cut -d: -f3`), puis `docker compose up -d`.
- **Le conteneur redémarre en boucle** : `docker compose logs openchamber` pour voir la cause (RAM insuffisante, volume mal monté, etc.).

## Contenu du repo

```text
.
├── .github/workflows/build-image.yml  # build arm64 upstream → GHCR
├── image/Dockerfile                   # surcouche de l'image : outils CLI
├── image/versions.env                 # versions des binaires amont (docker, yq, codebase-memory-mcp)
├── docker-compose.yml                 # déploiement sur le Pi
├── .env.example                       # modèle de configuration
├── scripts/update.sh                  # pull + recréation si l'image a changé
└── data/, workspaces/                 # créés au premier lancement (ignorés par git)
```

OpenChamber est un projet MIT indépendant de ce repo de déploiement.
