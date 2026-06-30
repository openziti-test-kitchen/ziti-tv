#!/usr/bin/env bash
# Provision the first hosted service: an HTTP "echo" (traefik/whoami) hosted in vpc2 and
# dialed from home. Creates configs, the service, two identities (host + client) with OTT
# enrollment JWTs, and the bind/dial + edge-router policies. Idempotent (deletes first).
#
# Produces tokens/echo-host.{jwt,env} and tokens/echo-client.{jwt,env}.
#
# Conventions (see addendum_03): in-container abs paths use //, ziti at /usr/local/bin/ziti,
# output to stderr, capture via a log file + docker cp (with retry).
set -euo pipefail

cd "$(dirname "$0")/.."

LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
mkdir -p tokens scratch

dcp() {
  local i
  for i in 1 2 3 4 5; do
    docker cp "$@" && return 0
    sleep 1
  done
  echo "ERROR: docker cp failed after retries: $*" >&2
  return 1
}

# In-container provisioning script (quoted heredoc: nothing expands on the host).
cat > scratch/provision-echo.gen.sh <<'PROV'
#!/bin/sh
Z=//usr/local/bin/ziti
{
  $Z edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y

  # Clean slate so this is re-runnable.
  $Z edge delete service echo || true
  $Z edge delete config echo.host.v1 || true
  $Z edge delete config echo.intercept.v1 || true
  $Z edge delete identity echo-host || true
  $Z edge delete identity echo-client || true
  $Z edge delete service-policy echo-bind || true
  $Z edge delete service-policy echo-dial || true
  $Z edge delete edge-router-policy erp-all || true
  $Z edge delete service-edge-router-policy serp-all || true

  # Configs: where the host forwards to, and what the client intercepts.
  $Z edge create config echo.host.v1 host.v1 \
    '{"protocol":"tcp","address":"echo-backend","port":80}'
  $Z edge create config echo.intercept.v1 intercept.v1 \
    '{"protocols":["tcp"],"addresses":["echo.ziti"],"portRanges":[{"low":80,"high":80}]}'

  # Service binds both configs.
  $Z edge create service echo --configs echo.intercept.v1,echo.host.v1

  # Identities (OTT). Attributes drive the policies below.
  $Z edge create identity echo-host   -a echo.servers -o //tmp/echo-host.jwt
  $Z edge create identity echo-client -a echo.clients -o //tmp/echo-client.jwt

  # Service policies: servers may Bind, clients may Dial.
  $Z edge create service-policy echo-bind Bind \
    --identity-roles '#echo.servers' --service-roles '@echo'
  $Z edge create service-policy echo-dial Dial \
    --identity-roles '#echo.clients' --service-roles '@echo'

  # Allow all identities to use all edge routers, and all services over all edge routers.
  $Z edge create edge-router-policy erp-all \
    --identity-roles '#all' --edge-router-roles '#all'
  $Z edge create service-edge-router-policy serp-all \
    --service-roles '#all' --edge-router-roles '#all'

  echo "== identities =="
  $Z edge list identities
  echo "== service =="
  $Z edge list services
} > //tmp/provision-echo.log 2>&1
PROV

tr -d '\r' < scratch/provision-echo.gen.sh > scratch/provision-echo.sh

echo "==> Provisioning echo service on ${LEADER_CTR}"
dcp scratch/provision-echo.sh "${LEADER_CTR}:/tmp/provision-echo.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-echo.sh

echo "==> Retrieving enrollment JWTs"
dcp "${LEADER_CTR}:/tmp/echo-host.jwt"   tokens/echo-host.jwt
dcp "${LEADER_CTR}:/tmp/echo-client.jwt" tokens/echo-client.jwt
printf 'ZITI_ENROLL_TOKEN=%s\n' "$(cat tokens/echo-host.jwt)"   > tokens/echo-host.env
printf 'ZITI_ENROLL_TOKEN=%s\n' "$(cat tokens/echo-client.jwt)" > tokens/echo-client.env

echo "==> Done. Provisioning log:"
dcp "${LEADER_CTR}:/tmp/provision-echo.log" scratch/provision-echo.log
cat scratch/provision-echo.log
