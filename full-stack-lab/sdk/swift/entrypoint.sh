#!/usr/bin/env sh
# Single entrypoint for the matrix image / macOS host edge.
# Usage: entrypoint.sh APP ROLE
#   APP  = echo | http
#   ROLE = server | client
#
# Maps APP+ROLE to the SwiftPM executable name and execs it. Env passed through:
#   ZITI_IDENTITY (default /ziti/id.json), ZITI_SERVICE, SELF_LANG=swift.
set -eu

APP="${1:-}"
ROLE="${2:-}"

case "${APP}.${ROLE}" in
  echo.server) EXE=EchoServer ;;
  echo.client) EXE=EchoClient ;;
  http.server) EXE=HttpServer ;;
  http.client) EXE=HttpClient ;;
  *)
    echo "usage: $0 <echo|http> <server|client>" >&2
    exit 2
    ;;
esac

# BINDIR is set by the Docker image; on macOS it defaults to the SwiftPM build dir.
BINDIR="${BINDIR:-./.build/release}"
exec "${BINDIR}/${EXE}"
