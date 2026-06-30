#!/usr/bin/env bash
# Layer 3 (interop-matrix Section 7): health checks and terminator self-healing.
#
# HONEST SCOPE -- read this before running:
#   The interop SDK servers bind their Ziti service DIRECTLY (no tunneler). With the SDK-bind
#   model, terminator health is reported by the SDK host itself (the sdk-hosting health-check
#   API), and there is no controller-side CLI to attach an httpCheck/portCheck to an SDK
#   terminator after the fact. So this script does two things, and is explicit about which is
#   which:
#
#   (A) FULLY SCRIPTED -- a tunneler-hosted health-checked variant of ONE service.
#       We create a host.v1 config WITH an httpCheck against a /healthz endpoint and a parallel
#       portCheck, bound the same way the rest of the lab binds host.v1 services. This is the
#       demonstrable, controller-visible health path: a failing /healthz drops that terminator and
#       `ziti edge list terminators` shows it leave the pool. This is the SAME mechanism used by
#       scripts/provision-posture.sh-style host.v1 services elsewhere in the lab.
#
#   (B) DOCUMENTED ONLY -- the SDK terminator-health path for the native interop servers.
#       For a true HA matrix you run TWO servers per service (isrv-<c> and an isrv-<c>-b sibling)
#       so each service has two terminators, and each SDK host reports its own health via the
#       SDK's hosting health-check options. We DO list the terminators so you can see one vs two
#       per service, and we document the exact SDK-side knobs, but we do not (and cannot from the
#       CLI) inject health state into an SDK terminator. See the SDK note at the bottom.
#
# WHAT TO OBSERVE:
#   - `ziti edge list terminators` shows how many terminators each service has. Bring up an
#     isrv-<c>-b sibling container (compose) and the count goes 1 -> 2 for that service: HA.
#   - For the scripted tunneler variant (healthz.<HEALTH_CODE>), point /healthz at a backend you
#     can break. When /healthz returns non-2xx the httpCheck marks the terminator unhealthy and it
#     leaves the pool; dials transparently use the healthy twin and the matrix stays green. Kill
#     both and the column goes red (no healthy terminator), proving the check gates traffic.
#
# Idempotent (delete-then-create). Same in-container heredoc pattern as provision-posture.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p scratch

LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"

# Which interop service to mirror as a tunneler-hosted, health-checked variant.
HEALTH_CODE="${HEALTH_CODE:-go}"
# Backend the tunneler dials, and where /healthz lives. Defaults mirror the lab echo backend.
HEALTH_BACKEND="${HEALTH_BACKEND:-echo-backend}"
HEALTH_PORT="${HEALTH_PORT:-80}"
HEALTHZ_PATH="${HEALTHZ_PATH:-/healthz}"

dcp() {
  local i
  for i in 1 2 3 4 5; do
    docker cp "$@" && return 0
    sleep 1
  done
  echo "ERROR: docker cp failed after retries: $*" >&2
  return 1
}

cat > scratch/provision-interop-health.gen.sh <<PROV
#!/bin/sh
Z=//usr/local/bin/ziti
HEALTH_CODE="${HEALTH_CODE}"
{
  \$Z edge login localhost:1280 -u admin -p "\${ZITI_PWD:-admin}" -y

  # ---- (A) FULLY SCRIPTED: tunneler-hosted, health-checked variant of one service ----
  SVC="healthz.\$HEALTH_CODE"
  \$Z edge delete service "\$SVC" || true
  \$Z edge delete config "\$SVC.host.v1" || true
  \$Z edge delete service-policy "\$SVC-bind" || true
  \$Z edge delete service-policy "\$SVC-dial" || true

  # host.v1 with BOTH an httpCheck (GET /healthz) and a portCheck. The tunneler that binds this
  # service runs these checks and reports terminator health to the controller. A failing check
  # makes the terminator unhealthy and removes it from the routable pool.
  \$Z edge create config "\$SVC.host.v1" host.v1 \
    '{"protocol":"tcp","address":"${HEALTH_BACKEND}","port":${HEALTH_PORT},"httpChecks":[{"url":"http://${HEALTH_BACKEND}:${HEALTH_PORT}${HEALTHZ_PATH}","method":"GET","expectStatus":200,"interval":"5s","timeout":"3s","actions":[{"trigger":"fail","action":"mark unhealthy"},{"trigger":"pass","action":"mark healthy"}]}],"portChecks":[{"address":"${HEALTH_BACKEND}:${HEALTH_PORT}","interval":"5s","timeout":"3s","actions":[{"trigger":"fail","action":"mark unhealthy"},{"trigger":"pass","action":"mark healthy"}]}]}'

  \$Z edge create service "\$SVC" --configs "\$SVC.host.v1" -a interop

  # Bind via a tunneler-capable identity. The interop server identities (#host.<c>) host this; if
  # you prefer a dedicated tunneler identity, retag accordingly. Dial open to all #clients.
  \$Z edge create service-policy "\$SVC-bind" Bind \
    --identity-roles "#host.\$HEALTH_CODE" --service-roles "@\$SVC"
  \$Z edge create service-policy "\$SVC-dial" Dial \
    --identity-roles '#clients' --service-roles "@\$SVC"

  echo "== health-checked service config =="
  \$Z edge list configs "name=\"\$SVC.host.v1\""
  echo "== terminators (count per interop service; HA = 2 per service) =="
  \$Z edge list terminators
} > //tmp/provision-interop-health.log 2>&1
PROV

tr -d '\r' < scratch/provision-interop-health.gen.sh > scratch/provision-interop-health.sh

echo "==> Layering health checks on the interop matrix (${LEADER_CTR})"
echo "    scripted variant: healthz.${HEALTH_CODE} (host.v1 httpCheck on ${HEALTHZ_PATH} + portCheck)"
dcp scratch/provision-interop-health.sh "${LEADER_CTR}:/tmp/provision-interop-health.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-interop-health.sh
dcp "${LEADER_CTR}:/tmp/provision-interop-health.log" scratch/provision-interop-health.log
cat scratch/provision-interop-health.log

cat <<'NOTE'
==> Done.
    SCRIPTED (A): healthz.<code> uses a host.v1 httpCheck against /healthz + a portCheck. A tunneler
    binding this service reports terminator health; break /healthz and watch the terminator leave
    `ziti edge list terminators`, then return when it recovers.

    DOCUMENTED ONLY (B) -- native SDK interop servers:
      * For true per-service HA, run a sibling server container isrv-<code>-b that ALSO binds
        echo.<code>/http.<code>. Each bind is its own terminator, so each service then has TWO.
        This is a compose/container change, not a controller CLI change.
      * SDK terminator health is reported by the hosting SDK via its listen/hosting health-check
        options (the sdk-golang ziti.ListenOptions health-check hooks and the equivalent in each
        SDK). There is no `ziti edge` CLI to attach a health check to an already-bound SDK
        terminator, so that piece is documented, not scripted.
      * Observe HA either way with: ziti edge list terminators
NOTE
