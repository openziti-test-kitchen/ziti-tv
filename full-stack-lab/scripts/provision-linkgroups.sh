#!/usr/bin/env bash
# REAL router link groups (the production mechanism for custom pathing).
#
# A router's link dialers and listeners can each carry `groups: [..]`. A dialer only forms a
# link to a listener when they SHARE a group; with no groups set, every router is in the
# implicit "default" group (which is why this lab is a full mesh). Put two routers in their own
# group and they will only link to each other, partitioning the fabric, which is how you keep
# sensitive flows on dedicated links or steer regions.
#
# This edits the chosen routers' /ziti-router/config.yml (backing it up first) to add a group,
# then restarts them. `revert` restores the backups and restarts.
#
# Usage:
#   scripts/provision-linkgroups.sh apply  [group] [routers...]   # default: premium public-er-1 vpc1-er
#   scripts/provision-linkgroups.sh revert [routers...]
#   scripts/provision-linkgroups.sh show
#
# IMPORTANT (verify in your env): the stock router image may regenerate config.yml on boot when
# ZITI_BOOTSTRAP_CONFIG=true, which would drop this edit. If groups do not stick after restart,
# run those routers with ZITI_BOOTSTRAP_CONFIG=false (a compose override) so the edited config is
# kept. This script backs up and reverts, so it is safe to try. Not live-verified in the build
# sandbox (router-config surgery + restart).
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
CTR="${PROJECT}-ziti-controller1-1"
Z="//usr/local/bin/ziti"

case "${1:?usage: provision-linkgroups.sh apply|revert|show}" in
  apply)
    group="${2:-premium}"; shift 2 2>/dev/null || shift $#
    routers=("$@"); [ ${#routers[@]} -eq 0 ] && routers=(public-er-1 vpc1-er)
    for r in "${routers[@]}"; do
      c="${PROJECT}-${r}-1"
      echo "==> ${r}: backup config, inject group '${group}', restart"
      # Back up once, then append `groups: [<group>]` after each transport binding line.
      docker exec "$c" sh -c "cp -n //ziti-router/config.yml //ziti-router/config.yml.bak; \
        sed -i -E '/- binding: +transport/a\\        groups: [${group}]' //ziti-router/config.yml"
      docker restart "$c" >/dev/null && echo "   restarted ${c}"
    done
    echo "==> Give links ~20s to re-form, then: scripts/provision-linkgroups.sh show"
    echo "    Routers in '${group}' will only link to each other (and others lose links to them)." ;;
  revert)
    shift; routers=("$@"); [ ${#routers[@]} -eq 0 ] && routers=(public-er-1 vpc1-er)
    for r in "${routers[@]}"; do
      c="${PROJECT}-${r}-1"
      docker exec "$c" sh -c "[ -f //ziti-router/config.yml.bak ] && cp //ziti-router/config.yml.bak //ziti-router/config.yml || true"
      docker restart "$c" >/dev/null && echo "==> reverted + restarted ${c}"
    done ;;
  show)
    docker exec "$CTR" $Z edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y >/dev/null 2>&1 || true
    docker exec "$CTR" $Z fabric list links ;;
  *) echo "unknown action" >&2; exit 1 ;;
esac
