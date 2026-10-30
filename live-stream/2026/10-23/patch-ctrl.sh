#!/usr/bin/env bash
# Makes the quickstart controller present the Let's Encrypt certificate on its client API. Run with the controller
# stopped. Keeps the untouched quickstart output as ctrl.yaml.orig and always patches from it, so it is safe to rerun.
set -euo pipefail
source "$(dirname "$0")/.env"
QS=$DEMO_DIR/qs
CTRL=$QS/instance-1/ctrl.yaml
[[ -f $CTRL.orig ]] || cp "$CTRL" "$CTRL.orig"
cp "$CTRL.orig" "$CTRL"

# alt_server_certs replaces the commented-out example in the web listener's identity. edge.api.address, the bindPoint
# address, and the ca stay as the quickstart wrote them: the controller advertises addbyurl-ctrl, and the ca holds only
# the private root.
ALT="      alt_server_certs:\n"
ALT+="        - server_cert: \"$DEMO_DIR/le/fullchain.pem\"\n"
ALT+="          server_key:  \"$DEMO_DIR/le/privkey.pem\""
sed -E -i \
  -e "s#^      \#alt_server_certs:#$ALT#" \
  "$CTRL"

diff "$CTRL.orig" "$CTRL" || true
