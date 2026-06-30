#!/usr/bin/env bash
# Stand up the Kubernetes dark-service demo against the EXISTING `zo` controller lab.
#
# What this does, in order:
#   1. Create a k3d cluster joined to the controller's docker network (zo-ctrl) so pods can reach
#      ziti-controller1/2/3 on the client API port 1280.
#   2. Add the OpenZiti helm repo.
#   3. Install a tunneler-enabled ziti-router (k8s-er) enrolled to the existing controller.
#   4. Deploy the dark whoami app (ClusterIP only, no ingress).
#   5. Install ziti-host to bind whoami onto the overlay as a hosted Ziti service.
#
# The controller-side objects (router enrollment JWT, host identity, service, policies) are minted
# with the `ziti` CLI against the running lab. This script does NOT mint them for you: it expects
# the JWT files to exist and tells you the exact commands if they do not. Keep logic in this
# script (repo convention), supply secrets/run-IDs as args/env.
#
# Usage:
#   k8s/setup.sh                          # uses defaults / env vars below
#   ROUTER_JWT=tokens/k8s-er.jwt k8s/setup.sh
#   k8s/setup.sh tokens/k8s-er.jwt        # router JWT as positional arg
#
# Prereqs you must install yourself: docker, k3d, kubectl, helm, and the ziti CLI (for minting).
# NOTE: this scaffold has NOT been run or verified in this environment. Read README.md first.
set -euo pipefail

cd "$(dirname "$0")/.."

# ---- knobs (override via env) -----------------------------------------------------------------
CLUSTER_NAME="${CLUSTER_NAME:-ziti}"
DOCKER_NETWORK="${DOCKER_NETWORK:-zo-ctrl}"
ZITI_NAMESPACE="${ZITI_NAMESPACE:-ziti}"
CTRL_ENDPOINT="${CTRL_ENDPOINT:-ziti-controller1:1280}"
ROUTER_NAME="${ROUTER_NAME:-k8s-er}"
HOST_IDENTITY_NAME="${HOST_IDENTITY_NAME:-k8s-host}"

# Router enrollment JWT: positional arg wins, then ROUTER_JWT env, then the conventional path.
ROUTER_JWT="${1:-${ROUTER_JWT:-tokens/${ROUTER_NAME}.jwt}}"
# ziti-host identity enrollment JWT.
HOST_JWT="${HOST_JWT:-tokens/${HOST_IDENTITY_NAME}.jwt}"

HERE="k8s"
MANIFESTS="${HERE}/manifests"

say() { printf '\n==> %s\n' "$*"; }

# ---- 0. sanity ---------------------------------------------------------------------------------
for bin in docker k3d kubectl helm; do
  command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: '$bin' not found on PATH" >&2; exit 1; }
done

if ! docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
  echo "ERROR: docker network '$DOCKER_NETWORK' not found. Bring up the controller lab first." >&2
  echo "       (the routers compose file references network ${DOCKER_NETWORK})" >&2
  exit 1
fi

# ---- manual minting reminder (controller-side objects) ----------------------------------------
if [[ ! -f "$ROUTER_JWT" ]]; then
  cat >&2 <<EOF

MANUAL STEP REQUIRED: router enrollment JWT not found at '$ROUTER_JWT'.

Mint it against the running controller lab, then re-run this script:

  scripts/mint-router-token.sh ${ROUTER_NAME} --tunneler-enabled
  # or directly:
  # ziti edge create edge-router ${ROUTER_NAME} --tunneler-enabled -o ${ROUTER_JWT}

EOF
  exit 1
fi

if [[ ! -f "$HOST_JWT" ]]; then
  cat >&2 <<EOF

MANUAL STEP REQUIRED: ziti-host identity JWT not found at '$HOST_JWT'.

Provision the hosted service + identity on the controller (mirror scripts/provision-echo.sh, but
point host.v1 at the k8s ClusterIP). At minimum:

  ziti edge create config k8s-whoami.host.v1 host.v1 \\
    '{"protocol":"tcp","address":"whoami.default.svc.cluster.local","port":80}'
  ziti edge create config k8s-whoami.intercept.v1 intercept.v1 \\
    '{"protocols":["tcp"],"addresses":["whoami.ziti"],"portRanges":[{"low":80,"high":80}]}'
  ziti edge create service k8s-whoami --configs k8s-whoami.intercept.v1,k8s-whoami.host.v1
  ziti edge create identity ${HOST_IDENTITY_NAME} -a k8s.servers -o ${HOST_JWT}
  ziti edge create service-policy k8s-whoami-bind Bind \\
    --identity-roles '#k8s.servers' --service-roles '@k8s-whoami'
  # plus a Dial policy + edge-router policies so a client identity can dial whoami.ziti

Then re-run this script.

EOF
  exit 1
fi

# ---- 1. k3d cluster on the controller network -------------------------------------------------
if k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER_NAME"; then
  say "k3d cluster '${CLUSTER_NAME}' already exists, reusing it"
else
  say "Creating k3d cluster '${CLUSTER_NAME}' on docker network '${DOCKER_NETWORK}'"
  # Joining the controller network lets pods resolve/reach ziti-controller1/2/3 over the overlay
  # control channel. No host port mapping is needed: nothing about whoami is exposed to the host.
  k3d cluster create "$CLUSTER_NAME" --network "$DOCKER_NETWORK" --wait
fi

kubectl cluster-info

# ---- 2. helm repo -----------------------------------------------------------------------------
say "Adding/updating the OpenZiti helm repo"
helm repo add openziti https://openziti.github.io/helm-charts/ 2>/dev/null || true
helm repo update openziti

# ---- 3. ziti-router enrolled to the existing controller ---------------------------------------
say "Installing ziti-router '${ROUTER_NAME}' (enrolled to ${CTRL_ENDPOINT})"
helm upgrade --install ziti-router openziti/ziti-router \
  --namespace "$ZITI_NAMESPACE" --create-namespace \
  -f "${MANIFESTS}/ziti-router-values.yaml" \
  --set "ctrl.endpoint=${CTRL_ENDPOINT}" \
  --set-file "enrollmentJwt=${ROUTER_JWT}"

# ---- 4. the dark app --------------------------------------------------------------------------
say "Deploying the dark whoami app (ClusterIP only, no ingress)"
kubectl apply -f "${MANIFESTS}/whoami.yaml"
kubectl -n default rollout status deploy/whoami --timeout=120s

# ---- 5. ziti-host binds whoami onto the overlay -----------------------------------------------
say "Installing ziti-host to bind whoami onto the overlay"
helm upgrade --install ziti-host openziti/ziti-host \
  --namespace "$ZITI_NAMESPACE" --create-namespace \
  -f "${MANIFESTS}/ziti-host-values.yaml" \
  --set-file "zitiEnrollment=${HOST_JWT}"

say "Done. whoami is dark in the cluster and hosted on the overlay as service 'k8s-whoami'."
cat <<EOF

Verify from the rest of the lab (no ingress, overlay only):
  - whoami has no NodePort/Ingress:   kubectl -n default get svc,ingress
  - ziti pods are up:                 kubectl -n ${ZITI_NAMESPACE} get pods
  - the edge router enrolled:         (on the lab) ziti edge list edge-routers
  - dial it from a client identity that can reach whoami.ziti:80 over Ziti.
EOF
