#!/usr/bin/env bash
# Path shaping: smart routing picks the lowest-cost path. Raise a link's static cost and watch
# new circuits route around it. Run in a real terminal so you can read the tables.
#
# Usage:
#   scripts/demo-path.sh links                 # list links (copy a link ID)
#   scripts/demo-path.sh cost <linkId> <n>     # set static cost (e.g. 1000 to avoid it)
#   scripts/demo-path.sh circuits              # show active circuits + their PATH
#   scripts/demo-path.sh reset <linkId>        # static cost back to 1
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
LEADER_CTR="${PROJECT}-ziti-controller1-1"
ZITI="//usr/local/bin/ziti"
login() { docker exec "$LEADER_CTR" $ZITI edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y >/dev/null 2>&1 || true; }

case "${1:?usage: demo-path.sh links|cost|circuits|reset}" in
  links)    docker exec "$LEADER_CTR" $ZITI fabric list links ;;
  cost)     docker exec "$LEADER_CTR" $ZITI fabric update link "${2:?linkId}" --static-cost "${3:?cost}" ;;
  reset)    docker exec "$LEADER_CTR" $ZITI fabric update link "${2:?linkId}" --static-cost 1 ;;
  circuits) login; docker exec "$LEADER_CTR" $ZITI fabric list circuits ;;
  *) echo "unknown action" >&2; exit 1 ;;
esac

cat <<'TIP'

Tip: to SEE a reroute, hold a connection open while you inspect circuits, e.g.
  docker exec zo-echo-client-1 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2222; sleep 30' &
then `demo-path.sh circuits` before and after raising the cost on a link in the current PATH.
TIP
