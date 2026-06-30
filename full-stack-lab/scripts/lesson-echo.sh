#!/usr/bin/env bash
# Provision the echo service on the minimal teaching stack (project zomin) and bring up its
# backend + tunnelers. Run after scripts/lesson-up.sh. Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="zomin"
LEADER_CTR="zomin-ziti-controller-1"

echo "==> Provisioning echo on the minimal controller"
# provision-echo.sh creates configs/service/identities/policies and stages the JWTs; point it
# at the zomin controller. It always deletes+recreates, so it is safe to re-run.
rm -f tokens/echo-host.env tokens/echo-client.env
LEADER_CTR="$LEADER_CTR" bash scripts/provision-echo.sh

echo "==> Starting backend + tunnelers"
docker compose -p "$PROJECT" -f compose/lesson-echo.yml up -d --force-recreate

echo "==> Dial test (give the tunnelers a few seconds, then):"
echo "    docker exec zomin-echo-client-1 curl -s http://localhost:8080"
