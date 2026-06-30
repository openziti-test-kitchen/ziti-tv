#!/usr/bin/env bash
# START a previously-stopped lab. The raft cluster reforms automatically and routers/tunnelers
# reconnect, no re-enrollment needed (state was preserved by scripts/stop.sh).
# Run: bash scripts/start.sh
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source scripts/lib-compose.sh

echo "==> Starting the ${PROJECT} stack"
docker compose -p "${PROJECT}" "${ZO_FILES[@]}" start

echo "==> Waiting for the controller leader to be healthy"
LEADER_CTR="${PROJECT}-ziti-controller1-1"
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$LEADER_CTR" 2>/dev/null || echo starting)" = "healthy" ]; do
  sleep 2
done

# After a cold start, services need their HOSTS re-bound against the ready control plane:
#  - router-hosted services (ssh on corp-er) need the hosting router bounced,
#  - tunneler-hosted services + clients (proxy/tproxy) race the controller and do not self-heal.
# Bounce the host router first, then the tunnelers. Safe if a container is absent.
echo "==> Re-binding hosts against the ready control plane"
for c in corp-er echo-host echo-host-2 echo-client roamer; do
  docker restart "${PROJECT}-${c}-1" >/dev/null 2>&1 && echo "    restarted ${PROJECT}-${c}-1" || true
done

echo "==> Up. Give hosts/clients ~15s to re-bind, then: bash scripts/status.sh"
