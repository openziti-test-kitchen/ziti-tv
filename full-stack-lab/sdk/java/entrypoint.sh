#!/bin/sh
# Dispatch: entrypoint.sh APP ROLE  ->  java -jar app.jar APP ROLE
set -e
exec java -jar /app/app.jar "$@"
