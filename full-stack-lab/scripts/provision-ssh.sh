#!/usr/bin/env bash
# Provision SSH-over-Ziti, hosted by the corp-er router identity (router-hosted pattern).
# Adds #ssh.clients to the existing echo-client so one identity dials multiple services.
# Idempotent (deletes first).
set -euo pipefail
cd "$(dirname "$0")/.."

LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
mkdir -p scratch

dcp() { local i; for i in 1 2 3 4 5; do docker cp "$@" && return 0; sleep 1; done; return 1; }

cat > scratch/provision-ssh.gen.sh <<'PROV'
#!/bin/sh
Z=//usr/local/bin/ziti
{
  $Z edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y

  $Z edge delete service ssh || true
  $Z edge delete config ssh.host.v1 || true
  $Z edge delete config ssh.intercept.v1 || true
  $Z edge delete service-policy ssh-bind || true
  $Z edge delete service-policy ssh-dial || true

  # sshd in corp listens on 2222 (linuxserver image).
  $Z edge create config ssh.host.v1 host.v1 \
    '{"protocol":"tcp","address":"ssh-backend","port":2222}'
  $Z edge create config ssh.intercept.v1 intercept.v1 \
    '{"protocols":["tcp"],"addresses":["ssh.ziti"],"portRanges":[{"low":22,"high":22}]}'

  $Z edge create service ssh --configs ssh.intercept.v1,ssh.host.v1

  # Hosted by the corp-er ROUTER identity (referenced by name with @).
  $Z edge create service-policy ssh-bind Bind \
    --identity-roles '@corp-er' --service-roles '@ssh'
  # Dialable by anything tagged #ssh.clients.
  $Z edge create service-policy ssh-dial Dial \
    --identity-roles '#ssh.clients' --service-roles '@ssh'

  # Let the existing echo-client also dial ssh (one identity, many services).
  $Z edge update identity echo-client -a echo.clients,ssh.clients

  echo "== services =="
  $Z edge list services
  echo "== ssh terminators (after host comes up) =="
  $Z edge list terminators 'service.name="ssh"'
} > //tmp/provision-ssh.log 2>&1
PROV

tr -d '\r' < scratch/provision-ssh.gen.sh > scratch/provision-ssh.sh
dcp scratch/provision-ssh.sh "${LEADER_CTR}:/tmp/provision-ssh.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-ssh.sh
dcp "${LEADER_CTR}:/tmp/provision-ssh.log" scratch/provision-ssh.log
cat scratch/provision-ssh.log
