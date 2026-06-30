#!/usr/bin/env bash
# Snapshot of the whole overlay: cluster, routers, links, services, identities, terminators.
# Run in a real terminal: bash scripts/status.sh
#
# Conventions: in-container abs paths use // (MSYS-safe); ziti is at /usr/local/bin/ziti.
set -euo pipefail
ZITI="//usr/local/bin/ziti"
LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"

dx() { docker exec "$LEADER_CTR" $ZITI "$@"; }

echo "############ raft cluster ############"
dx agent cluster list || true

echo "############ login ############"
dx edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y >/dev/null

echo "############ edge routers ############"
dx edge list edge-routers

echo "############ fabric links ############"
dx fabric list links

echo "############ services ############"
dx edge list services

echo "############ identities ############"
dx edge list identities

echo "############ terminators ############"
dx edge list terminators

echo "############ active circuits ############"
dx fabric list circuits
