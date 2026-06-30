#!/usr/bin/env bash
# Per-module launcher for the video series. Brings the lab to exactly the state a given Module
# needs and prints that module's first command. Handles the two stacks and their shared ports.
#
#   bash scripts/stage.sh module-1       # Module 1: minimal stack (1 controller + 1 router + echo)
#   bash scripts/stage.sh module-2       # Modules 2-6: the full `zo` lab (cumulative, all services)
#   bash scripts/stage.sh module-3.b     # a specific video; the .letter is ignored for setup
#                                        #   (a module's stack is shared across its videos)
#   bash scripts/stage.sh module-7       # Kubernetes (see k8s/)
#   bash scripts/stage.sh down [-v]      # tear down BOTH stacks (-v also wipes volumes + tokens)
#   bash scripts/stage.sh list           # show the map
#
# The minimal stack (project zomin) and the full stack (project zo) both use host ports
# 1280/3022, so only one runs at a time. This script stops the other one for you.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source scripts/lib-compose.sh

zo_created()  { [ -n "$(docker compose -p "${PROJECT}" "${ZO_FILES[@]}" ps -aq 2>/dev/null)" ]; }
zo_running()  { [ -n "$(docker ps -q --filter "name=${PROJECT}-ziti-controller1-1")" ]; }
min_running() { [ -n "$(docker ps -q --filter "name=${LESSON_PROJECT}-ziti-controller-1")" ]; }

stop_full() { echo "==> Stopping the full ${PROJECT} stack (frees ports)"; bash scripts/stop.sh >/dev/null 2>&1 || true; }
stop_min()  { echo "==> Tearing down the minimal ${LESSON_PROJECT} stack (frees ports)"; \
              docker compose -p "${LESSON_PROJECT}" "${LESSON_FILES[@]}" down -v >/dev/null 2>&1 || true; }

bring_full() {
  if zo_running; then echo "==> Full lab already running."; return; fi
  if zo_created; then echo "==> Resuming the full lab"; bash scripts/start.sh; else echo "==> Building the full lab"; bash scripts/demo-up.sh; fi
}

raw="${1:-list}"
# Normalize: drop a trailing .letter (module-3.b -> module-3) since a module's stack is shared.
target="${raw%%.*}"

case "$target" in
  module-1)
    zo_running && stop_full || true
    echo "==> Module 1: minimal stack"
    bash scripts/lesson-up.sh
    bash scripts/lesson-echo.sh
    cat <<'EOF'

Module 1 is ready. Start here:
  module-1.c hello overlay : docker exec -it zomin-ziti-controller-1 ziti edge list edge-routers
  module-1.d first service : docker exec zomin-echo-client-1 curl -s http://localhost:8080
EOF
    ;;
  module-2|module-3|module-4|module-5|module-6)
    min_running && stop_min || true
    bring_full
    cat <<EOF

${target} ready on the full lab (it is cumulative, every service/identity exists). Jump in:
  module-2.* fabric/ssh/posture : docker exec -it ${PROJECT}-ziti-controller1-1 ziti fabric list links
  module-3.* HA/multi-site      : docker exec -it ${PROJECT}-ziti-controller1-1 ziti agent cluster list
  module-4.* dial-by-name       : docker exec ${PROJECT}-roamer-1 curl -s http://echo.ziti
  module-5.* advanced auth      : docker exec ${PROJECT}-roamer-1 curl -s http://mfa-echo.ziti   # MFA-gated, denied
  module-6.* production         : bash scripts/status.sh   (observability: see observability/README.md)
See the matching lessons/moduleN.md for the full script.
EOF
    ;;
  module-7)
    echo "Module 7 (Kubernetes) runs in its own cluster. See k8s/README.md and run k8s/setup.sh"
    echo "(needs k3d + helm; not part of the zo/zomin docker stacks)."
    ;;
  pathing)
    min_running && stop_min || true
    bring_full
    echo "==> Provisioning the 'deep' long-path target (hosted only on vpc2-er)"
    bash scripts/provision-pathing.sh
    cat <<EOF

Custom-pathing module ready (see lessons/pathing.md). Try:
  scripts/demo-longpath.sh links                 # the fabric + link costs
  scripts/demo-longpath.sh hold &                # hold a deep.ziti dial from home
  scripts/demo-longpath.sh circuits              # the path it took
  scripts/demo-longpath.sh force                 # force home -> internet -> vpc1 -> vpc2
  scripts/provision-linkgroups.sh apply premium public-er-1 vpc1-er   # real link groups
EOF
    ;;
  down)
    bash scripts/down.sh "${2:-}" ;;
  list|*)
    cat <<EOF
Modules:
  module-1   -> minimal stack (zomin): 1 controller + 1 router + echo
  module-2   -> full lab (zo): fabric, ssh, posture, enrollment menu
  module-3   -> full lab: HA cluster, multi-site, the full monster
  module-4   -> full lab: dial-by-name, SDK, host edges
  module-5   -> full lab: advanced auth - UPDB, MFA, CA fleet, revocation
  module-6   -> full lab: observability, resilience, path shaping, backups
  module-7   -> Kubernetes (k8s/)
  pathing    -> full lab + the 'deep' long-path target (custom router paths / link groups)
  interop    -> see lessons/interop.md (provision-interop.sh + compose/interop.yml + interop-matrix.sh)
  down [-v]  -> tear down both stacks (-v also wipes volumes + tokens)

Usage: bash scripts/stage.sh module-3   (or module-3.b for a specific video)
Modules 2-6 share ONE cumulative lab; bring it up once and jump into any of them.
EOF
    ;;
esac
