#!/usr/bin/env bash
# Revocation demo: deleting an identity immediately revokes its access. We use a throwaway
# identity so the running demos are untouched.
#
# Usage: scripts/demo-revocation.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
LEADER_CTR="${PROJECT}-ziti-controller1-1"
ZITI="//usr/local/bin/ziti"

docker exec "$LEADER_CTR" $ZITI edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y

echo "==> Create a throwaway identity 'condemned' with a Dial role"
docker exec "$LEADER_CTR" sh -c "$ZITI edge delete identity condemned || true"
docker exec "$LEADER_CTR" $ZITI edge create identity condemned -a echo.clients -o //tmp/condemned.jwt
echo "==> It now appears and is authorized for echo:"
docker exec "$LEADER_CTR" $ZITI edge list identities 'name="condemned"'

echo "==> Revoke by deleting the identity (cert + sessions die immediately)"
docker exec "$LEADER_CTR" $ZITI edge delete identity condemned
echo "==> Gone:"
docker exec "$LEADER_CTR" $ZITI edge list identities 'name="condemned"'

echo "==> In production you can also revoke a specific cert with 'ziti edge create revocation'"
echo "    (by fingerprint) without deleting the identity."
