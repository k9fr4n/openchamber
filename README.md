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

## Espace de travail

Par défaut, l'agent travaille dans `./workspaces`, à côté du repo. Pour travailler sur des repos déjà présents sur le Pi, définir dans `.env` :

```bash
WORKSPACES_DIR=/home/pi/gitlab
```

Le dossier monté est accessible en lecture/écriture par l'agent : ne monter que ce qui est nécessaire.

## Mettre à jour la version d'OpenChamber

Deux façons de reconstruire l'image depuis une nouvelle version upstream :

- **Depuis GitHub** : onglet *Actions* → *Build image arm64* → *Run workflow* → indiquer le tag souhaité (ex. `v2.0.3`).
- **Via un commit** : changer `UPSTREAM_REF_DEFAULT` dans `.github/workflows/build-image.yml` puis pousser sur `main` — la build se déclenche automatiquement.

Ensuite, sur le Pi :

```bash
cd ~/openchamber
git pull
./scripts/update.sh
```

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

- **Le conteneur redémarre en boucle** : `docker compose logs openchamber` pour voir la cause (RAM insuffisante, volume mal monté, etc.).

## Contenu du repo

```text
.
├── .github/workflows/build-image.yml  # build arm64 upstream → GHCR
├── docker-compose.yml                 # déploiement sur le Pi
├── .env.example                       # modèle de configuration
├── scripts/update.sh                  # pull + recréation du conteneur
└── data/, workspaces/                 # créés au premier lancement (ignorés par git)
```

OpenChamber est un projet MIT indépendant de ce repo de déploiement.