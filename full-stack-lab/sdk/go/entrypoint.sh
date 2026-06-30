#!/bin/sh
# Dispatch on APP (echo|http) ROLE (server|client). The four programs are
# prebuilt into /app; this just selects the right binary.
set -e

APP="$1"
ROLE="$2"

if [ -z "$APP" ] || [ -z "$ROLE" ]; then
	echo "usage: <APP: echo|http> <ROLE: server|client>" >&2
	exit 2
fi

BIN="/app/${APP}-${ROLE}"
if [ ! -x "$BIN" ]; then
	echo "unknown APP/ROLE combination: ${APP} ${ROLE}" >&2
	exit 2
fi

exec "$BIN"
