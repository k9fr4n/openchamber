#!/usr/bin/env bash
# Déclare le serveur Playwright MCP distant dans la configuration OpenCode
# globale du conteneur (data/opencode/config/opencode.json), sans écraser
# les serveurs MCP déjà configurés (ex. codebase-memory-mcp).
#
# Usage (sur le Pi, depuis la racine du repo) :
#   ./scripts/setup-playwright-mcp.sh
#   docker compose up -d
#   docker compose exec openchamber opencode mcp list   # vérifier `playwright`
#
# Variables d'environnement :
#   PLAYWRIGHT_MCP_PORT : port du service `playwright-mcp` (défaut : 8931).
#   OPENCODE_JSON       : chemin du fichier à mettre à jour
#                         (défaut : data/opencode/config/opencode.json).
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PLAYWRIGHT_MCP_PORT:-8931}"
OPENCODE_JSON="${OPENCODE_JSON:-data/opencode/config/opencode.json}"

mkdir -p "$(dirname "$OPENCODE_JSON")"
[ -f "$OPENCODE_JSON" ] || echo '{}' > "$OPENCODE_JSON"

python3 - "$OPENCODE_JSON" "$PORT" <<'EOF'
import json, sys

path, port = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    try:
        cfg = json.load(f)
    except json.JSONDecodeError as e:
        print(f"ERREUR : {path} n'est pas du JSON valide : {e}", file=sys.stderr)
        sys.exit(1)

if not isinstance(cfg, dict):
    print(f"ERREUR : {path} ne contient pas un objet JSON.", file=sys.stderr)
    sys.exit(1)

url = f"http://playwright-mcp:{port}/mcp"
mcp = cfg.setdefault("mcp", {})
if not isinstance(mcp, dict):
    print("ERREUR : la clé `mcp` existe mais n'est pas un objet.", file=sys.stderr)
    sys.exit(1)

entry = mcp.get("playwright")
if entry == {"type": "remote", "url": url, "enabled": True}:
    print(f"Déjà configuré : playwright -> {url}")
else:
    mcp["playwright"] = {"type": "remote", "url": url, "enabled": True}
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"Configuré : playwright -> {url} (dans {path})")
EOF

python3 -m json.tool "$OPENCODE_JSON" > /dev/null
echo "OK : $OPENCODE_JSON est du JSON valide."
echo "Relance OpenChamber pour prise en compte : docker compose up -d"
