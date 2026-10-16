#!/bin/sh
# Logs the ziti CLI inside the quickstart container in as admin, with ZITI_PWD from .env. Later
# `docker compose exec quickstart ziti ...` commands use this login until it expires.
#
#   ./login.sh
cd "$(dirname "$0")"
ZITI_PWD=$(sed -n 's/^ZITI_PWD=//p' .env)
CTRL_PORT=$(sed -n 's/^CTRL_PORT=//p' .env)
docker compose exec -T quickstart ziti edge login "https://quickstart.127.0.0.1.nip.io:${CTRL_PORT:-1280}" \
  -u admin -p "$ZITI_PWD" -y --ca /ziti/pki/root-ca/certs/root-ca.cert </dev/null
