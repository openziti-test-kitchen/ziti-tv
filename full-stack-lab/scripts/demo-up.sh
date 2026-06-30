#!/usr/bin/env bash
# Bring the WHOLE lab up in order: controllers + cluster + routers, provision every service
# and enrollment/posture demo, THEN bring up backends and tunnelers last (so the client's
# proxy sees every service that exists). Idempotent. Run: bash scripts/demo-up.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
P="docker compose -p ${PROJECT}"

echo "############################################################"
echo "# 1) controllers + cluster + routers"
echo "############################################################"
bash scripts/up.sh

echo "############################################################"
echo "# 2) provision services, identities, policies, posture"
echo "############################################################"
[ -f tokens/echo-host.env ] || bash scripts/provision-echo.sh
bash scripts/provision-ssh.sh
bash scripts/provision-enrollment-demos.sh
bash scripts/provision-posture.sh
bash scripts/provision-mfa.sh

echo "############################################################"
echo "# 3) advanced identities (dial-by-name client + 2nd echo host)"
echo "############################################################"
bash scripts/mint-identity.sh roamer -a echo.clients,ssh.clients
bash scripts/mint-identity.sh echo-host-2 -a echo.servers

echo "############################################################"
echo "# 4) backends + tunnelers (client proxies echo+ssh+winonly, brought up last)"
echo "############################################################"
$P -f compose/ssh-demo.yml up -d
$P -f compose/echo-demo.yml up -d --force-recreate
$P -f compose/controllers.yml -f compose/routers.yml -f compose/echo-demo.yml -f compose/ssh-demo.yml -f compose/extras.yml up -d roamer echo-host-2

echo "############################################################"
echo "# up. try:"
echo "#   docker exec ${PROJECT}-echo-client-1 curl -s http://localhost:8080   # echo -> 200"
echo "#   docker exec ${PROJECT}-echo-client-1 curl -s http://localhost:8081   # winonly -> denied (posture)"
echo "#   docker exec ${PROJECT}-roamer-1 curl -s http://echo.ziti              # dial BY NAME -> 200"
echo "#   docker exec ${PROJECT}-roamer-1 curl -s http://mfa-echo.ziti          # MFA-gated -> denied"
echo "#   bash scripts/status.sh"
echo "#   optional: observability + haproxy (see observability/README.md, compose/haproxy.yml)"
echo "############################################################"
