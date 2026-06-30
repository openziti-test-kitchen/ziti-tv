#!/usr/bin/env bash
# Gracefully STOP the whole lab without destroying anything. State (PKI, identities, services,
# enrollments) is preserved in volumes; bring it back instantly with scripts/start.sh.
# Run: bash scripts/stop.sh
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source scripts/lib-compose.sh

echo "==> Stopping the ${PROJECT} stack (state preserved)"
docker compose -p "${PROJECT}" "${ZO_FILES[@]}" stop

# Also stop the lesson stack if it happens to be up.
if docker ps -q --filter "name=${LESSON_PROJECT}-" | grep -q .; then
  echo "==> Stopping the ${LESSON_PROJECT} lesson stack"
  docker compose -p "${LESSON_PROJECT}" "${LESSON_FILES[@]}" stop
fi

echo "==> Stopped. Resume with: bash scripts/start.sh"
