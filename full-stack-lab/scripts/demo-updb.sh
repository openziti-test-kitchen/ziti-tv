#!/usr/bin/env bash
# UPDB (username/password) login demo. `alice` was created with `--updb alice`, which makes a
# UPDB enrollment. This sets her password by enrolling, then logs in as alice with it.
# Run in a real terminal (uses interactive-style output).
#
# Usage: scripts/demo-updb.sh [password]
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
LEADER_CTR="${PROJECT}-ziti-controller1-1"
ZITI="//usr/local/bin/ziti"
PW="${1:-alicePassw0rd!}"

echo "==> Admin re-creates alice with a fresh UPDB enrollment and captures the token"
docker exec "$LEADER_CTR" $ZITI edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y
docker exec "$LEADER_CTR" sh -c "$ZITI edge delete identity alice || true"
docker exec "$LEADER_CTR" $ZITI edge create identity alice --updb alice -a echo.clients -o //tmp/alice.jwt

echo "==> Complete the UPDB enrollment (sets alice's password)"
docker exec "$LEADER_CTR" $ZITI edge enroll --username alice --password "$PW" //tmp/alice.jwt

echo "==> Log in to the management API AS alice with username/password"
docker exec "$LEADER_CTR" $ZITI edge login localhost:1280 -u alice -p "$PW" -y

echo "==> alice is authenticated via UPDB. (Switch back: ziti edge login -u admin -p admin -y)"
