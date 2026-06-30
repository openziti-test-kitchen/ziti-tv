#!/usr/bin/env bash
# Layer 4 (interop-matrix Section 8): customized pathing.
#
# HONEST SCOPE -- read this before running:
#   The PRODUCTION way to constrain pathing is router LINK GROUPS, which are a ROUTER CONFIG FILE
#   setting, not a controller CLI call. Confirmed against openziti/ziti (router xlink_transport
#   dialer/listener config) the real keys for 2.0.x live under `link:` in each router's yml:
#
#       link:
#         listeners:
#           - binding: transport
#             bind: tls:0.0.0.0:6000
#             advertise: tls:router-a:6000
#             groups:
#               - premium            # <-- listener group membership
#         dialers:
#           - binding: transport
#             groups:
#               - premium            # <-- dialer group membership
#
#   Rule (from the docs): a dialer only dials a listener that shares at least one group; with no
#   `groups` key the endpoint is in the `default` group. So you tag the high-grade link's two ends
#   `premium` and the long-haul ends `budget`, and links only form within a shared group. That
#   requires editing router yml + restarting routers, which this script does NOT do (it will not
#   touch router config files).
#
#   What this script DOES, fully scripted, is the demonstrable APPROXIMATION of steering: it uses
#   `ziti fabric update link <id> --static-cost` (and optionally `--down`) to make smart routing
#   prefer one path over another, and shows before/after `ziti fabric list circuits`. This proves
#   the steering EFFECT (circuits move) using only the CLI, while the block comment above documents
#   the true link-group config keys as the production approach.
#
# WHAT TO OBSERVE:
#   - BEFORE: `ziti fabric list circuits` for an active matrix dial shows the smart-routed path.
#   - We raise the static cost on the link the path currently uses (or take it --down), so smart
#     routing reroutes. AFTER: `ziti fabric list circuits` shows the circuit on the other path.
#   - Restore the cost (or bring the link up) and paths return. This is cost-based steering; link
#     groups are the structural version that makes the constraint permanent and policy-driven.
#
# FLAGS USED (confirmed against openziti/ziti ziti/cmd/fabric/update_link.go):
#   ziti fabric update link <idOrName> --static-cost <uint32>   set static cost (default 0)
#   ziti fabric update link <idOrName> --down <bool>            set link up/down
#   ziti fabric list links | circuits                           inspect fabric state
#
# Idempotent in effect (it sets an absolute cost, re-runnable). Same in-container heredoc pattern
# as provision-posture.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p scratch

LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"

# Cost to apply to the steered link. High enough that smart routing avoids it when an alternative
# exists. Override with STEER_COST. Set RESTORE=1 to reset the cost back to 0 instead.
STEER_COST="${STEER_COST:-1000}"
RESTORE="${RESTORE:-0}"
# Optionally target a specific link id; default steers the first link the controller lists.
LINK_ID="${LINK_ID:-}"

dcp() {
  local i
  for i in 1 2 3 4 5; do
    docker cp "$@" && return 0
    sleep 1
  done
  echo "ERROR: docker cp failed after retries: $*" >&2
  return 1
}

cat > scratch/provision-interop-linkgroups.gen.sh <<PROV
#!/bin/sh
Z=//usr/local/bin/ziti
STEER_COST="${STEER_COST}"
RESTORE="${RESTORE}"
LINK_ID="${LINK_ID}"
{
  \$Z edge login localhost:1280 -u admin -p "\${ZITI_PWD:-admin}" -y

  echo "== BEFORE: links =="
  \$Z fabric list links
  echo "== BEFORE: circuits =="
  \$Z fabric list circuits

  # Pick the target link: explicit LINK_ID, else the first id the controller reports.
  TARGET="\$LINK_ID"
  if [ -z "\$TARGET" ]; then
    TARGET=\$(\$Z fabric list links | awk 'NR>1 && \$2 ~ /[a-zA-Z0-9]/ {print \$2; exit}')
  fi
  echo "== target link: \${TARGET:-<none found>} =="

  if [ -n "\$TARGET" ]; then
    if [ "\$RESTORE" = "1" ]; then
      echo "== restoring link \$TARGET to static-cost 0 and up =="
      \$Z fabric update link "\$TARGET" --static-cost 0
      \$Z fabric update link "\$TARGET" --down false
    else
      echo "== steering: raising static-cost on link \$TARGET to \$STEER_COST =="
      \$Z fabric update link "\$TARGET" --static-cost "\$STEER_COST"
    fi
  else
    echo "NOTE: no fabric links present (need >=2 routers with a link between them to steer)."
  fi

  echo "== AFTER: links =="
  \$Z fabric list links
  echo "== AFTER: circuits (re-dial a matrix cell to force a new circuit, then re-check) =="
  \$Z fabric list circuits
} > //tmp/provision-interop-linkgroups.log 2>&1
PROV

tr -d '\r' < scratch/provision-interop-linkgroups.gen.sh > scratch/provision-interop-linkgroups.sh

echo "==> Steering interop fabric paths via static-cost (${LEADER_CTR})"
if [ "$RESTORE" = "1" ]; then
  echo "    RESTORE=1: resetting the target link cost to 0 / up"
else
  echo "    raising static-cost to ${STEER_COST} on the target link to force a reroute"
fi
dcp scratch/provision-interop-linkgroups.sh "${LEADER_CTR}:/tmp/provision-interop-linkgroups.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-interop-linkgroups.sh
dcp "${LEADER_CTR}:/tmp/provision-interop-linkgroups.log" scratch/provision-interop-linkgroups.log
cat scratch/provision-interop-linkgroups.log

cat <<'NOTE'
==> Done.
    SCRIPTED: cost-based steering via `ziti fabric update link <id> --static-cost`. Re-dial a
    matrix cell AFTER the cost change so a fresh circuit is computed, then compare
    `ziti fabric list circuits` before vs after to SEE the path move.

    PRODUCTION (documented, not scripted here): link groups in each router yml under `link:`
    listeners[].groups and dialers[].groups (shared group required for a link to form; absent =>
    `default` group). That is the structural, permanent way to express "this traffic must take
    that path"; this script only demonstrates the steering effect with cost so no router config
    files are modified. To reset: RESTORE=1 ./scripts/provision-interop-linkgroups.sh
NOTE
