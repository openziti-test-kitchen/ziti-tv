#!/usr/bin/env bash
# Mint (or re-mint) an OTT identity enrollment JWT and stage it for a tunneler container.
# Produces tokens/<name>.jwt and tokens/<name>.env (ZITI_ENROLL_TOKEN=...).
#
# Usage: scripts/mint-identity.sh <identity-name> [extra ziti create-identity flags...]
# Example: scripts/mint-identity.sh roamer -a echo.clients,ssh.clients
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:?usage: mint-identity.sh <name> [flags...]}"
shift || true
EXTRA="$*"
LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
mkdir -p tokens scratch
dcp() { local i; for i in 1 2 3 4 5; do docker cp "$@" && return 0; sleep 1; done; return 1; }

cat > "scratch/mint-id-${NAME}.gen.sh" <<EOF
#!/bin/sh
Z=//usr/local/bin/ziti
NAME="${NAME}"
rm -f //tmp/\$NAME.jwt
{
  \$Z edge login localhost:1280 -u admin -p "\${ZITI_PWD:-admin}" -y
  \$Z edge delete identity "\$NAME" || true
  \$Z edge create identity "\$NAME" ${EXTRA} -o //tmp/\$NAME.jwt
  ls -l //tmp/\$NAME.jwt
} > //tmp/mint-id.log 2>&1
EOF
tr -d '\r' < "scratch/mint-id-${NAME}.gen.sh" > "scratch/mint-id-${NAME}.sh"

echo "==> Minting identity '${NAME}' on ${LEADER_CTR}"
dcp "scratch/mint-id-${NAME}.sh" "${LEADER_CTR}:/tmp/mint-id-${NAME}.sh"
docker exec "$LEADER_CTR" sh "//tmp/mint-id-${NAME}.sh"
dcp "${LEADER_CTR}:/tmp/${NAME}.jwt" "tokens/${NAME}.jwt"
printf 'ZITI_ENROLL_TOKEN=%s\n' "$(cat "tokens/${NAME}.jwt")" > "tokens/${NAME}.env"
rm -f "scratch/mint-id-${NAME}.gen.sh" "scratch/mint-id-${NAME}.sh"
echo "==> Wrote tokens/${NAME}.jwt and tokens/${NAME}.env"
