#!/usr/bin/env bash
# Layer 2 (interop-matrix Section 6): auth policies on the matrix.
#
# Auth policy is the FRONT DOOR: it decides whether an identity can AUTHENTICATE at all and which
# methods are allowed (cert, updb/password, ext-jwt) and whether MFA/TOTP is mandatory. This is a
# DIFFERENT gate from posture/service-policy (the room key, Layer 1). The matrix shows both.
#
# Creates three auth policies:
#   ap-default  cert only                  (the normal interop posture)
#   ap-mfa      cert + REQUIRED TOTP       (cannot get an API session until TOTP is enrolled)
#   ap-updb     cert + password allowed    (username/password auth permitted alongside cert)
#
# Then assigns:
#   ap-mfa  -> icli-<AP_MFA_CODE>   (default swift)
#   ap-updb -> icli-<AP_UPDB_CODE>  (default cs)
#
# WHAT TO OBSERVE: the ap-mfa client cannot obtain an API session at all until it enrolls TOTP
# (ziti edge enroll-mfa + verify), so its ENTIRE ROW is "auth-denied" in the matrix, a distinct
# state from posture-grey, even for services it is otherwise fully authorized to dial. The ap-updb
# client behaves normally over cert here (password is merely PERMITTED), demonstrating that auth
# method is policy-controlled per identity. Move ap-mfa back to ap-default and the row returns.
#
# FLAGS USED (confirmed against openziti/ziti ziti/cmd/edge/create_authpolicy.go):
#   --primary-cert-allowed        bool   allow x509 client-cert primary auth
#   --primary-updb-allowed        bool   allow username/password (updb) primary auth
#   --secondary-req-totp          bool   require TOTP as a secondary factor (mandatory MFA)
# (Other available flags not needed here: --primary-cert-expired-allowed, --primary-ext-jwt-allowed,
#  --primary-ext-jwt-allowed-signers, --primary-updb-min-length, --primary-updb-req-special,
#  --primary-updb-req-numbers, --primary-updb-req-mixed-case, --primary-updb-max-attempts,
#  --primary-updb-lockout-min, --secondary-req-ext-jwt-signer.)
# Assignment uses `ziti edge update identity <name> --auth-policy <idOrName>`.
#
# Idempotent (delete-then-create). Same in-container heredoc pattern as provision-posture.sh
# (ziti at //usr/local/bin/ziti, output captured via a log + docker cp).
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p scratch

LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"

# Which interop clients get the non-default policies.
AP_MFA_CODE="${AP_MFA_CODE:-swift}"
AP_UPDB_CODE="${AP_UPDB_CODE:-cs}"

dcp() {
  local i
  for i in 1 2 3 4 5; do
    docker cp "$@" && return 0
    sleep 1
  done
  echo "ERROR: docker cp failed after retries: $*" >&2
  return 1
}

cat > scratch/provision-interop-authpolicy.gen.sh <<PROV
#!/bin/sh
Z=//usr/local/bin/ziti
AP_MFA_CODE="${AP_MFA_CODE}"
AP_UPDB_CODE="${AP_UPDB_CODE}"
{
  \$Z edge login localhost:1280 -u admin -p "\${ZITI_PWD:-admin}" -y

  # Before deleting an auth policy, move any identity off it back onto the built-in "Default"
  # policy, otherwise the delete is refused (an auth policy in use cannot be removed).
  \$Z edge update identity "icli-\$AP_MFA_CODE"  --auth-policy Default || true
  \$Z edge update identity "icli-\$AP_UPDB_CODE" --auth-policy Default || true

  # Clean slate (delete-then-create).
  \$Z edge delete auth-policy ap-default || true
  \$Z edge delete auth-policy ap-mfa     || true
  \$Z edge delete auth-policy ap-updb    || true

  # ap-default: cert only. The baseline every interop identity uses implicitly.
  \$Z edge create auth-policy ap-default \
    --primary-cert-allowed

  # ap-mfa: cert primary + REQUIRED TOTP secondary. No API session without TOTP enrolled.
  \$Z edge create auth-policy ap-mfa \
    --primary-cert-allowed \
    --secondary-req-totp

  # ap-updb: cert primary + username/password permitted. Shows password auth alongside cert.
  \$Z edge create auth-policy ap-updb \
    --primary-cert-allowed \
    --primary-updb-allowed

  # Assign the non-default policies to two client identities.
  \$Z edge update identity "icli-\$AP_MFA_CODE"  --auth-policy ap-mfa
  \$Z edge update identity "icli-\$AP_UPDB_CODE" --auth-policy ap-updb

  echo "== auth policies =="
  \$Z edge list auth-policies 'name contains "ap-"'
  echo "== assigned client identities (note authPolicy column) =="
  \$Z edge list identities "name=\"icli-\$AP_MFA_CODE\" or name=\"icli-\$AP_UPDB_CODE\""
} > //tmp/provision-interop-authpolicy.log 2>&1
PROV

tr -d '\r' < scratch/provision-interop-authpolicy.gen.sh > scratch/provision-interop-authpolicy.sh

echo "==> Layering auth policies on the interop matrix (${LEADER_CTR})"
echo "    ap-mfa  -> icli-${AP_MFA_CODE}  (this row should go auth-denied until TOTP is enrolled)"
echo "    ap-updb -> icli-${AP_UPDB_CODE} (password auth permitted; cert still works)"
dcp scratch/provision-interop-authpolicy.sh "${LEADER_CTR}:/tmp/provision-interop-authpolicy.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-interop-authpolicy.sh
dcp "${LEADER_CTR}:/tmp/provision-interop-authpolicy.log" scratch/provision-interop-authpolicy.log
cat scratch/provision-interop-authpolicy.log

echo "==> Done. Re-run the matrix: icli-${AP_MFA_CODE} should be a fully auth-denied row."
echo "    To restore it, enroll TOTP on that client, or: ziti edge update identity icli-${AP_MFA_CODE} --auth-policy ap-default"
