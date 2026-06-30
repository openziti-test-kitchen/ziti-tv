#!/usr/bin/env bash
# TEAR DOWN the lab: remove containers and networks. With -v / --volumes it also deletes the
# volumes (PKI, controller DB, enrolled identities) and the staged tokens, a full clean slate
# that the next scripts/demo-up.sh rebuilds from scratch.
#
# Usage:
#   bash scripts/down.sh              # remove containers + networks, KEEP state (volumes)
#   bash scripts/down.sh --volumes    # also wipe volumes + tokens (clean slate)
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source scripts/lib-compose.sh

VOLS=""
case "${1:-}" in
  -v|--volumes) VOLS="-v" ;;
  "") ;;
  *) echo "usage: down.sh [--volumes]" >&2; exit 1 ;;
esac

echo "==> Tearing down the ${PROJECT} stack ${VOLS:+(with volumes)}"
docker compose -p "${PROJECT}" "${ZO_FILES[@]}" down ${VOLS} --remove-orphans

echo "==> Tearing down the ${LESSON_PROJECT} lesson stack ${VOLS:+(with volumes)}"
docker compose -p "${LESSON_PROJECT}" "${LESSON_FILES[@]}" down ${VOLS} --remove-orphans 2>/dev/null || true

if [ -n "$VOLS" ]; then
  echo "==> Clearing staged tokens (they reference the now-deleted controller DB)"
  rm -f tokens/*.jwt tokens/*.env
  echo "==> Clean slate. Rebuild with: bash scripts/demo-up.sh"
else
  echo "==> Down. Volumes kept; bring back with: bash scripts/demo-up.sh (or scripts/start.sh if only stopped)"
fi
