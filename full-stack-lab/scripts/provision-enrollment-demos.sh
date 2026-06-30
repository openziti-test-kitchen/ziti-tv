#!/usr/bin/env bash
# Demonstrate additional enrollment methods beyond OTT:
#   - UPDB (username/password) identity
#   - a 3rd-party CA generated with `ziti pki`, registered for ottca + autoca enrollment
# Also dumps posture-check syntax for the next step. Idempotent-ish (deletes first).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tokens scratch
LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
dcp() { local i; for i in 1 2 3 4 5; do docker cp "$@" && return 0; sleep 1; done; return 1; }

cat > scratch/provision-enroll.gen.sh <<'PROV'
#!/bin/sh
Z=//usr/local/bin/ziti
{
  $Z edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y

  echo "===== UPDB identity (username/password) ====="
  $Z edge delete identity alice || true
  # --updb creates a UPDB enrollment; the resulting JWT lets the user set a password.
  $Z edge create identity alice --updb alice -a echo.clients -o //tmp/alice.jwt
  $Z edge list identities 'name="alice"'

  echo "===== 3rd-party CA via ziti pki ====="
  rm -rf //tmp/thirdparty-pki
  $Z pki create ca --pki-root //tmp/thirdparty-pki --ca-name "ziti-overkill 3rd-party CA" --ca-file thirdparty
  $Z edge delete ca thirdparty-ca || true
  # Register the CA: usable for ottca (one-time-token + CA) and autoca (auto-enroll any cert it signs).
  $Z edge create ca thirdparty-ca //tmp/thirdparty-pki/thirdparty/certs/thirdparty.cert \
    --ottca --autoca --auth -a ca.enrolled
  $Z edge list cas

  echo "===== posture-check syntax (for next step) ====="
  $Z edge create posture-check -h
} > //tmp/provision-enroll.log 2>&1
PROV

tr -d '\r' < scratch/provision-enroll.gen.sh > scratch/provision-enroll.sh
dcp scratch/provision-enroll.sh "${LEADER_CTR}:/tmp/provision-enroll.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-enroll.sh
dcp "${LEADER_CTR}:/tmp/provision-enroll.log" scratch/provision-enroll.log
echo "(see scratch/provision-enroll.log)"
