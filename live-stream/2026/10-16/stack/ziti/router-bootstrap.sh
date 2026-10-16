#!/bin/sh
# Brings up the edge router for the docker compose stack. Enrollment happens on
# first run and is skipped afterwards, so the stack can be stopped and started
# without recreating the router.
set -e

ZITI_HOME="${ZITI_HOME:-/ziti}"
ROUTER_DIR="${ZITI_HOME}/router"
# the mounted config is read only, and a running router writes its data model
# alongside its config file, so work from a copy
ROUTER_CONFIG_SRC="${ROUTER_CONFIG_SRC:-/etc/ziti/router.yaml}"
ROUTER_CONFIG="${ROUTER_DIR}/router.yaml"
ROUTER_ENROLL_CONFIG="${ROUTER_DIR}/router-enroll.yaml"
ROUTER_NAME="${ROUTER_NAME:-compose-router}"
CTRL="${ZITI_CTRL:-https://quickstart:1280}"
CA="${ZITI_HOME}/pki/root-ca/certs/root-ca.cert"

echo "waiting for the controller at ${CTRL}"
until [ -f "${CA}" ] && ziti edge login "${CTRL}" \
  -u "${ZITI_USER}" -p "${ZITI_PWD}" -y --ca "${CA}" >/dev/null 2>&1; do
  sleep 2
done
echo "logged in to ${CTRL}"

# A quickstart started with --no-router creates no edge router policies at all,
# because normally its own integrated router comes with them. Without these two a
# dial fails with NO_EDGE_ROUTERS_AVAILABLE.
ziti edge create edge-router-policy all-endpoints \
  --edge-router-roles '#all' --identity-roles '#all' >/dev/null 2>&1 || true
ziti edge create service-edge-router-policy all-services \
  --service-roles '#all' --edge-router-roles '#all' >/dev/null 2>&1 || true

mkdir -p "${ROUTER_DIR}"
# ROUTER_PORT moves both edge listeners off 3022, so this stack can run next to another one
sed "s/:3022/:${ROUTER_PORT:-3022}/g" "${ROUTER_CONFIG_SRC}" > "${ROUTER_CONFIG}"

if [ ! -f "${ROUTER_DIR}/router.cert" ]; then
  # the transport section names certificates that enrollment is about to create,
  # so enroll with a copy that stops before it
  sed '/^transport:/,$d' "${ROUTER_CONFIG}" > "${ROUTER_ENROLL_CONFIG}"

  echo "enrolling edge router ${ROUTER_NAME}"
  ziti edge delete edge-router "${ROUTER_NAME}" >/dev/null 2>&1 || true
  ziti edge create edge-router "${ROUTER_NAME}" \
    -o "${ROUTER_DIR}/router.jwt" --tunneler-enabled=false
  ziti router enroll "${ROUTER_ENROLL_CONFIG}" --jwt "${ROUTER_DIR}/router.jwt"
else
  echo "edge router already enrolled, reusing ${ROUTER_DIR}"
fi

echo "starting the edge router (tls and wss share port ${ROUTER_PORT:-3022}, split by ALPN)"
exec ziti router run "${ROUTER_CONFIG}"
