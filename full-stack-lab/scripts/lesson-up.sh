#!/usr/bin/env bash
# Bring up the MINIMAL teaching stack: 1 controller + 1 router. Idempotent.
# Run: bash scripts/lesson-up.sh   (tear down: docker compose -p zomin -f compose/lesson-min.yml down -v)
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="zomin"
LEADER_CTR="zomin-ziti-controller-1"
COMPOSE="docker compose -p ${PROJECT} -f compose/lesson-min.yml"

echo "==> Starting the controller"
$COMPOSE up -d ziti-controller

echo "==> Waiting for the controller to be healthy"
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$LEADER_CTR" 2>/dev/null || echo starting)" = "healthy" ]; do
  sleep 2
done

# Healthy (ziti agent stats) can pass slightly before the auth subsystem accepts admin logins,
# which would 401 the mint. Wait for a real login to succeed.
echo "==> Waiting for admin login to be ready"
until docker exec "$LEADER_CTR" //usr/local/bin/ziti edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y >/dev/null 2>&1; do
  sleep 2
done

# Always mint fresh: the lesson stack is torn down/rebuilt often, and a stale token from a
# previous controller would fail to enroll. Minting deletes+recreates the edge-router, so a
# changed token makes compose recreate the router below.
echo "==> Minting the router enrollment token (fresh)"
LEADER_CTR="$LEADER_CTR" bash scripts/mint-router-token.sh lesson-router --tunneler-enabled

echo "==> Starting the router"
$COMPOSE up -d

echo "==> Done. Log in with:"
echo "    docker exec -it ${LEADER_CTR} ziti edge login localhost:1280 -u admin -p admin -y"
echo "    docker exec -it ${LEADER_CTR} ziti edge list edge-routers"
