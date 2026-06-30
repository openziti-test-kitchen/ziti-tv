#!/usr/bin/env bash
# Chaos / resilience demos that are SAFE to run against the live lab (they restore state).
#
#   scripts/demo-chaos.sh kill-host     # stop one echo binder; echo still works via the other
#   scripts/demo-chaos.sh restore-host
#   scripts/demo-chaos.sh kill-leader   # stop the raft leader; cluster re-elects, data plane lives
#   scripts/demo-chaos.sh restore-leader
#
# Note: do NOT kill a router that a proxy-mode client uses as its edge entry, that drops the
# client until it reconnects. Host failover and leader failover are the clean stories.
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
ZITI="//usr/local/bin/ziti"

dial() {
  docker exec "${PROJECT}-echo-client-1" sh -c 'curl -s -o //dev/null -w "  echo http_code=%{http_code}\n" http://localhost:8080 | tee //tmp/cd.txt'
  docker cp "${PROJECT}-echo-client-1:/tmp/cd.txt" scratch/cd.txt >/dev/null 2>&1 || true
  cat scratch/cd.txt 2>/dev/null || true
}

case "${1:?usage: demo-chaos.sh kill-host|restore-host|kill-leader|restore-leader}" in
  kill-host)
    echo "==> Stopping echo-host (echo-host-2 still binds echo)"
    docker stop "${PROJECT}-echo-host-1"
    echo "==> Dialing echo (should still work via echo-host-2):"
    sleep 3; dial ;;
  restore-host)
    docker start "${PROJECT}-echo-host-1" ;;
  kill-leader)
    echo "==> Finding + stopping the raft leader"
    docker stop "${PROJECT}-ziti-controller1-1"
    echo "==> Cluster from another node:"
    docker exec "${PROJECT}-ziti-controller2-1" $ZITI agent cluster list || true
    echo "==> Data-plane dial still works:"
    sleep 3; dial ;;
  restore-leader)
    docker start "${PROJECT}-ziti-controller1-1" ;;
  *) echo "unknown action" >&2; exit 1 ;;
esac
