#!/usr/bin/env bash
# Controller database backup. Takes a bolt snapshot of the controller DB and copies it to
# backups/ on the host. Restore is a controller-side operation (documented below).
#
# Usage: scripts/backup-restore.sh snapshot
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
LEADER_CTR="${PROJECT}-ziti-controller1-1"
ZITI="//usr/local/bin/ziti"
mkdir -p backups scratch

case "${1:-snapshot}" in
  snapshot)
    echo "==> Taking a DB snapshot on the leader"
    # snapshot-db writes a timestamped copy of the bolt DB next to it (in raft/).
    docker exec "$LEADER_CTR" $ZITI agent controller snapshot-db
    echo "==> Newest snapshot:"
    snap="$(docker exec "$LEADER_CTR" sh -c 'ls -1t //ziti-controller/raft/ctrl-ha.db-* 2>/dev/null | head -1')"
    snap="$(printf '%s' "$snap" | tr -d '\r')"
    echo "    $snap"
    if [ -n "$snap" ]; then
      base="$(basename "$snap")"
      docker cp "${LEADER_CTR}:${snap}" "backups/${base}" && echo "==> Saved backups/${base}"
    fi
    echo
    echo "Restore: stop the controller, replace /ziti-controller/<bolt>.db with a snapshot file,"
    echo "and start it again. In an HA cluster prefer restoring on a fresh single node then"
    echo "re-adding peers."
    ;;
  *) echo "usage: backup-restore.sh snapshot" >&2; exit 1 ;;
esac
