---
name: Update OpenChamber
description: Mettre à jour OpenChamber et tous les outils épinglés de l'image (version upstream, docker CLI, yq, codebase-memory-mcp). Utilise ce skill dès que l'utilisateur parle de bump, mise à jour, update, nouvelle version, upgrade de l'image ou des outils — même sans mentionner de skill.
---

# Update OpenChamber

Bump de la version upstream OpenChamber et de tous les binaires épinglés dans
`image/versions.env`, puis push sur `main` (le push déclenche le rebuild
d'image via GitHub Actions).

## Fichiers sources

| Quoi | Fichier | Champ |
| --- | --- | --- |
| Version upstream (rebuild auto) | `.github/workflows/build-image.yml` | `workflow_dispatch.inputs.ref.default` + `UPSTREAM_REF_DEFAULT` (2 occurrences) |
| Exemple d'épingle | `.env.example` | commentaire + `OPENCHAMBER_IMAGE` |
| Exemple doc | `README.md` | section *Mettre à jour la version d'OpenChamber* |
| docker CLI | `image/versions.env` | `DOCKER_CLI_VERSION` + `DOCKER_CLI_SHA256_ARM64` |
| yq | `image/versions.env` | `YQ_VERSION` |
| codebase-memory-mcp | `image/versions.env` | `CBM_VERSION` + `CBM_SHA256_ARM64` + `CBM_SHA256_AMD64` |

Convention : `DOCKER_CLI_SHA256_AMD64` reste vide (seul l'arm64 du Pi est
vérifié) ; `CBM_*` garde les deux empreintes (fournies dans le checksums.txt
de la release).

## Workflow

1. **État de départ.** Vérifie `git status`, la branche (`main`) et l'identité
   (`git config user.name` / `user.email`, `git remote -v`). Ne commite jamais
   `.env` ni `.codebase-memory/*` (bruit d'index local : le restaurer avec
   `git checkout --` s'il est modifié).
2. **Versions latest.** Compare avec l'épinglé en place :
   - upstream : `gh api repos/openchamber/openchamber/tags -q '.[].name' | head -5`
   - yq : `gh api repos/mikefarah/yq/releases/latest -q '.tag_name'`
   - codebase-memory-mcp : `gh api repos/DeusData/codebase-memory-mcp/releases/latest -q '.tag_name'`
   - docker CLI : lister `https://download.docker.com/linux/static/stable/aarch64/`
     et prendre le plus grand `docker-X.Y.Z.tgz`.
3. **Empreintes.** Pour chaque version changée :
   - docker : `curl -sL <url-tgz-aarch64> | sha256sum` (et x86_64 si besoin).
   - CBM : empreintes `*-portable.tar.gz` dans le `checksums.txt` de la release.
   - yq : rien à calculer (le Dockerfile vérifie via `checksums-bsd` au build).
4. **Édite** uniquement les fichiers du tableau ci-dessus. Exemple de message
   historique : `chore: bump OpenChamber image to vX.Y.Z (cbm vA.B.C)`.
5. **Commit ciblé.** `git add` uniquement les fichiers édités, commit, puis
   `git push origin main`. Restaure `.codebase-memory/*` après le commit si
   l'auto-index l'a re-modifié, pour laisser un arbre propre.
6. **Vérifie** `git log --oneline -3` et `git status --short`.

## Exemples

**Exemple 1 :**
Input : "fait un bump de version"
Output : bump upstream vers le dernier tag (workflow + `.env.example` +
`README.md`), commit `chore: bump OpenChamber image to vX.Y.Z`, push sur `main`.

**Exemple 2 :**
Input : "update tout"
Output : en plus de l'upstream, bump `DOCKER_CLI_VERSION` + SHA arm64,
`YQ_VERSION` et `CBM_VERSION` + SHA si une release plus récente existe ;
un commit par outil ou un commit groupé selon la demande.
