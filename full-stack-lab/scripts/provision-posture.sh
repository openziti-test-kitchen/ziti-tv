#!/usr/bin/env bash
# Posture-check demo: a `winonly` service identical to echo but gated by a Windows-OS posture
# check. The Linux echo-client will be DENIED, proving posture gating (the echo service stays
# open for contrast). Idempotent (deletes first).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p scratch
LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
dcp() { local i; for i in 1 2 3 4 5; do docker cp "$@" && return 0; sleep 1; done; return 1; }

cat > scratch/provision-posture.gen.sh <<'PROV'
#!/bin/sh
Z=//usr/local/bin/ziti
{
  $Z edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y

  $Z edge delete service winonly || true
  $Z edge delete config winonly.host.v1 || true
  $Z edge delete service-policy winonly-bind || true
  $Z edge delete service-policy winonly-dial || true
  $Z edge delete posture-check pc-windows || true

  # Posture check: client OS must be Windows.
  $Z edge create posture-check os pc-windows --os Windows -a posture.windows

  # Same backend as echo, but a separate service so echo stays open for contrast.
  $Z edge create config winonly.host.v1 host.v1 \
    '{"protocol":"tcp","address":"echo-backend","port":80}'
  $Z edge create service winonly --configs winonly.host.v1

  # echo-host binds it (it is #echo.servers).
  $Z edge create service-policy winonly-bind Bind \
    --identity-roles '#echo.servers' --service-roles '@winonly'
  # Clients may dial ONLY if they pass the Windows posture check.
  $Z edge create service-policy winonly-dial Dial \
    --identity-roles '#echo.clients' --service-roles '@winonly' \
    --posture-check-roles '#posture.windows'

  echo "== posture checks =="
  $Z edge list posture-checks
  echo "== winonly policies =="
  $Z edge list service-policies 'name contains "winonly"'
} > //tmp/provision-posture.log 2>&1
PROV

tr -d '\r' < scratch/provision-posture.gen.sh > scratch/provision-posture.sh
dcp scratch/provision-posture.sh "${LEADER_CTR}:/tmp/provision-posture.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-posture.sh
dcp "${LEADER_CTR}:/tmp/provision-posture.log" scratch/provision-posture.log
echo "(see scratch/provision-posture.log)"
