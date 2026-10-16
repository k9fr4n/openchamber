#!/bin/sh
# Surcouche OpenChamber : demarre le forwarder de l'UI codebase-memory
# (0.0.0.0:9748 -> 127.0.0.1:9749, cf. cbm-ui-forward.py) puis l'entrypoint
# standard. L'UI cbm n'ecoute que sur localhost sans option d'adresse :
# sans ce pont, ni Traefik ni un port publie ne peuvent l'atteindre.
#
# Le daemon CBM (proprietaire de l'UI :9749) s'arrete des que la derniere
# session cliente se termine : sans session persistante, l'UI tombe (502
# Traefik) et chaque nouveau client doit relancer le daemon. Le "holder"
# ci-dessous maintient donc une session factice permanente (stdin ouvert
# sur /dev/null, aucune requete) pour garder daemon + UI en vie.
# Boucle de supervision : relance le holder s'il meurt (ex. crash daemon
# laissant des locks obsolètes, cas vu le 2026-10-16). Nettoyage des locks
# uniquement ici au demarrage (aucun CBM ne tourne encore a ce stade) :
# le /tmp du conteneur est frais a chaque recreation.
set -eu
python3 /usr/local/bin/cbm-ui-forward.py &
rm -f /tmp/cbm-daemon-*/cbm-*.sock /tmp/cbm-daemon-*/cbm-*.anc \
    /tmp/cbm-daemon-*/*.identity \
    /tmp/cbm-daemon-*/cbm-*.lock \
    /tmp/cbm-daemon-*/cbm-*.rw /tmp/cbm-daemon-*/cbm-*.turn || true
( while :; do
    tail -f /dev/null | /usr/local/bin/codebase-memory-mcp >> /tmp/cbm-holder.log 2>&1
    sleep 5
  done ) &
exec sh /home/openchamber/openchamber-entrypoint.sh "$@"
