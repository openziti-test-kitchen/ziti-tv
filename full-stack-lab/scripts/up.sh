#!/usr/bin/env bash
# Bring up the HA controller cluster and join all nodes into one raft cluster.
# Idempotent: re-running only adds nodes that are not already members.
#
# Usage: scripts/up.sh
set -euo pipefail

# Windows/Git-Bash note: we do NOT set MSYS_NO_PATHCONV (it breaks docker cp host paths).
# Instead, in-container absolute paths use a double leading slash (//usr/local/bin/ziti),
# which MSYS leaves alone and Linux/macOS collapse to a single slash.
ZITI="//usr/local/bin/ziti"

cd "$(dirname "$0")/.."

# Load .env so node names/ports match the compose file.
set -a
# shellcheck disable=SC1091
source .env
set +a

PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
CTRL_F="compose/controllers.yml"
RTR_F="compose/routers.yml"
COMPOSE="docker compose -p ${PROJECT} -f ${CTRL_F}"
COMPOSE_ALL="docker compose -p ${PROJECT} -f ${CTRL_F} -f ${RTR_F}"
LEADER_CTR="${PROJECT}-ziti-controller1-1"

echo "==> Starting controller cluster"
$COMPOSE up -d

echo "==> Waiting for node 1 to be healthy"
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$LEADER_CTR" 2>/dev/null || echo starting)" = "healthy" ]; do
  sleep 2
done

# Wait for nodes 2 and 3 to be healthy before adding them as voters.
for ctr in "${PROJECT}-ziti-controller2-1" "${PROJECT}-ziti-controller3-1"; do
  echo "==> Waiting for $ctr to be healthy"
  until [ "$(docker inspect -f '{{.State.Health.Status}}' "$ctr" 2>/dev/null || echo starting)" = "healthy" ]; do
    sleep 2
  done
done

# Add nodes 2 and 3 to the raft cluster (run against the leader). The add is
# idempotent in practice: if the node is already a member the controller returns
# an error we can safely ignore.
add_member() {
  local addr="$1"
  echo "==> Adding $addr to the cluster"
  docker exec "$LEADER_CTR" $ZITI agent cluster add "$addr" || \
    echo "    (already a member or add not needed: $addr)"
}

add_member "tls:${ZITI_CTRL2_ADVERTISED_ADDRESS}:${ZITI_CTRL2_ADVERTISED_PORT}"
add_member "tls:${ZITI_CTRL3_ADVERTISED_ADDRESS}:${ZITI_CTRL3_ADVERTISED_PORT}"

echo "==> Cluster members:"
docker exec "$LEADER_CTR" $ZITI agent cluster list

# --- routers --------------------------------------------------------------
# Mint each router's enrollment token only if it is not already staged, so re-running
# up.sh does not delete+recreate (and thus un-enroll) a router that is already online.
mint_if_needed() {
  local name="$1"; shift
  if [ -f "tokens/${name}.env" ]; then
    echo "==> Token for ${name} already staged, skipping mint"
  else
    scripts/mint-router-token.sh "${name}" "$@"
  fi
}

echo "==> Provisioning routers"
mint_if_needed public-er-1   --tunneler-enabled
mint_if_needed transit-router
mint_if_needed vpc1-er       --tunneler-enabled
mint_if_needed vpc2-er       --tunneler-enabled
mint_if_needed corp-er       --tunneler-enabled
mint_if_needed home-er       --tunneler-enabled

echo "==> Starting routers"
$COMPOSE_ALL up -d

echo "==> Edge routers:"
docker exec "$LEADER_CTR" $ZITI edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y
docker exec "$LEADER_CTR" $ZITI edge list edge-routers
