#!/bin/sh
# Dispatch on APP ROLE arguments.
#   $1  APP  = echo | http
#   $2  ROLE = server | client
set -e

APP="${1:-echo}"
ROLE="${2:-server}"

case "${APP}-${ROLE}" in
    echo-server)  exec /usr/local/bin/echo_server ;;
    echo-client)  exec /usr/local/bin/echo_client ;;
    http-server)  exec /usr/local/bin/http_server ;;
    http-client)  exec /usr/local/bin/http_client ;;
    *)
        echo "Usage: <image> <APP> <ROLE>"
        echo "  APP  : echo | http"
        echo "  ROLE : server | client"
        exit 1
        ;;
esac
