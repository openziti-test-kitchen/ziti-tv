#!/usr/bin/env bash
# Mint (or re-mint) an edge-router enrollment JWT on the controller and stage it for compose.
#
# Produces:
#   tokens/<name>.jwt   the raw enrollment JWT
#   tokens/<name>.env   ZITI_ENROLL_TOKEN=<jwt>  (consumed by compose env_file)
#
# Usage: scripts/mint-router-token.sh <router-name> [extra ziti create flags...]
# Example: scripts/mint-router-token.sh public-er-1 --tunneler-enabled
#
# Windows / Git-Bash conventions used here (do NOT set MSYS_NO_PATHCONV, it breaks docker cp):
#   - docker cp host sources use RELATIVE paths (MSYS leaves relative paths alone)
#   - in-container absolute paths use a DOUBLE leading slash (//tmp/x, //usr/local/bin/ziti),
#     which MSYS leaves alone and Linux/macOS collapse to a single slash
#   - in-container scripts are CR-stripped before copy
#   - ziti is at /usr/local/bin/ziti and writes to stderr, so we capture both streams
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="${1:?usage: mint-router-token.sh <router-name> [flags...]}"
shift || true
EXTRA_FLAGS="$*"

LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
mkdir -p tokens scratch

# Build the in-container script (LF endings) under scratch/ with a relative path.
GEN="scratch/mint-${NAME}.gen.sh"
LF="scratch/mint-${NAME}.sh"
cat > "$GEN" <<EOF
#!/bin/sh
Z=//usr/local/bin/ziti
NAME="${NAME}"
# Remove any stale JWT from a previous mint: the controller container is long-lived, so a
# leftover /tmp/<name>.jwt could otherwise be copied out instead of the freshly minted one.
rm -f //tmp/\$NAME.jwt
{
  \$Z edge login localhost:1280 -u admin -p "\${ZITI_PWD:-admin}" -y
  \$Z edge delete edge-router "\$NAME" || true
  \$Z edge create edge-router "\$NAME" ${EXTRA_FLAGS} -o //tmp/\$NAME.jwt
  ls -l //tmp/\$NAME.jwt
} > //tmp/mint.log 2>&1
EOF
tr -d '\r' < "$GEN" > "$LF"

# docker cp over the tcp daemon occasionally flakes ("Could not find the file ..."), so retry.
# Host paths here are RELATIVE so MSYS leaves them alone; container paths are literal /tmp/...
dcp() {
  local i
  for i in 1 2 3 4 5; do
    if docker cp "$@"; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: docker cp failed after retries: $*" >&2
  return 1
}

echo "==> Minting enrollment token for '${NAME}' on ${LEADER_CTR}"
dcp "$LF" "${LEADER_CTR}:/tmp/mint-${NAME}.sh"
docker exec "$LEADER_CTR" sh "//tmp/mint-${NAME}.sh"

echo "==> Retrieving JWT"
dcp "${LEADER_CTR}:/tmp/${NAME}.jwt" "tokens/${NAME}.jwt"
printf 'ZITI_ENROLL_TOKEN=%s\n' "$(cat "tokens/${NAME}.jwt")" > "tokens/${NAME}.env"

rm -f "$GEN" "$LF"
echo "==> Wrote tokens/${NAME}.jwt and tokens/${NAME}.env"
