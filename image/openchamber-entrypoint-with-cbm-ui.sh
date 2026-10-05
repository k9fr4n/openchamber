#!/bin/sh
# Surcouche OpenChamber : demarre le forwarder de l'UI codebase-memory
# (0.0.0.0:9748 -> 127.0.0.1:9749, cf. cbm-ui-forward.py) puis l'entrypoint
# standard. L'UI cbm n'ecoute que sur localhost sans option d'adresse :
# sans ce pont, ni Traefik ni un port publie ne peuvent l'atteindre.
set -eu
python3 /usr/local/bin/cbm-ui-forward.py &
exec sh /home/openchamber/openchamber-entrypoint.sh "$@"
