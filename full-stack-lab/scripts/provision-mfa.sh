#!/usr/bin/env bash
# MFA posture demo: a service `mfa-echo` that requires the dialing identity to have completed
# client-side MFA (TOTP). Identities without MFA enrolled are DENIED. Full TOTP enrollment is a
# client-side flow (ziti edge enroll-mfa / verify-mfa); this proves the gate by denying a client
# that has not enrolled MFA. Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."
LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
dcp() { local i; for i in 1 2 3 4 5; do docker cp "$@" && return 0; sleep 1; done; return 1; }

cat > scratch/provision-mfa.gen.sh <<'PROV'
#!/bin/sh
Z=//usr/local/bin/ziti
{
  $Z edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y
  $Z edge delete service mfa-echo || true
  $Z edge delete config mfa-echo.host.v1 || true
  $Z edge delete config mfa-echo.intercept.v1 || true
  $Z edge delete service-policy mfa-echo-bind || true
  $Z edge delete service-policy mfa-echo-dial || true
  $Z edge delete posture-check pc-mfa || true

  $Z edge create posture-check mfa pc-mfa -a posture.mfa

  $Z edge create config mfa-echo.host.v1 host.v1 \
    '{"protocol":"tcp","address":"echo-backend","port":80}'
  $Z edge create config mfa-echo.intercept.v1 intercept.v1 \
    '{"protocols":["tcp"],"addresses":["mfa-echo.ziti"],"portRanges":[{"low":80,"high":80}]}'
  $Z edge create service mfa-echo --configs mfa-echo.intercept.v1,mfa-echo.host.v1

  $Z edge create service-policy mfa-echo-bind Bind \
    --identity-roles '#echo.servers' --service-roles '@mfa-echo'
  $Z edge create service-policy mfa-echo-dial Dial \
    --identity-roles '#echo.clients' --service-roles '@mfa-echo' \
    --posture-check-roles '#posture.mfa'

  echo "== mfa-echo dial policy (note posture check column) =="
  $Z edge list service-policies 'name="mfa-echo-dial"'
} > //tmp/provision-mfa.log 2>&1
PROV

tr -d '\r' < scratch/provision-mfa.gen.sh > scratch/provision-mfa.sh
dcp scratch/provision-mfa.sh "${LEADER_CTR}:/tmp/provision-mfa.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-mfa.sh
dcp "${LEADER_CTR}:/tmp/provision-mfa.log" scratch/provision-mfa.log
echo "(provisioned mfa-echo; an un-enrolled client dialing mfa-echo.ziti will be denied)"
