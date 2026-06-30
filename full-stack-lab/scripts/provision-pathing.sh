#!/usr/bin/env bash
# Provision a CONTROLLED long-path target for the custom-pathing module: a service `deep` that is
# hosted by ONLY the vpc2-er router (a single terminator deep in vpc2), reachable by the existing
# clients. Because it has exactly one terminator, a dial from a home client must reach vpc2-er,
# which lets us demonstrate forcing the scenic route home -> internet -> vpc1 -> vpc2 with link
# cost. Idempotent (delete-then-create). Backed by the echo-backend whoami (already in vpc2).
set -euo pipefail
cd "$(dirname "$0")/.."
LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
dcp() { local i; for i in 1 2 3 4 5; do docker cp "$@" && return 0; sleep 1; done; return 1; }

cat > scratch/provision-pathing.gen.sh <<'PROV'
#!/bin/sh
Z=//usr/local/bin/ziti
{
  $Z edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y
  $Z edge delete service deep || true
  $Z edge delete config deep.host.v1 || true
  $Z edge delete config deep.intercept.v1 || true
  $Z edge delete service-policy deep-bind || true
  $Z edge delete service-policy deep-dial || true

  # Hosted only by the vpc2-er router -> exactly one terminator, deep in vpc2.
  $Z edge create config deep.host.v1 host.v1 \
    '{"protocol":"tcp","address":"echo-backend","port":80}'
  $Z edge create config deep.intercept.v1 intercept.v1 \
    '{"protocols":["tcp"],"addresses":["deep.ziti"],"portRanges":[{"low":80,"high":80}]}'
  $Z edge create service deep --configs deep.intercept.v1,deep.host.v1

  $Z edge create service-policy deep-bind Bind \
    --identity-roles '@vpc2-er' --service-roles '@deep'
  $Z edge create service-policy deep-dial Dial \
    --identity-roles '#echo.clients' --service-roles '@deep'

  echo "== deep terminators (expect one, on vpc2-er) =="
  $Z edge list terminators 'service.name="deep"'
} > //tmp/provision-pathing.log 2>&1
PROV

tr -d '\r' < scratch/provision-pathing.gen.sh > scratch/provision-pathing.sh
dcp scratch/provision-pathing.sh "${LEADER_CTR}:/tmp/provision-pathing.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-pathing.sh
dcp "${LEADER_CTR}:/tmp/provision-pathing.log" scratch/provision-pathing.log
echo "(provisioned service 'deep', hosted only on vpc2-er; dial deep.ziti from a home client)"
