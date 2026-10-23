#!/usr/bin/env bash
# Makes the quickstart controller present the Let's Encrypt certificate on its client API. Run with the controller
# stopped. Keeps the untouched quickstart output as ctrl.yaml.orig and always patches from it, so it is safe to rerun.
set -euo pipefail
source "$(dirname "$0")/.env"
QS=$DEMO_DIR/qs
CTRL=$QS/instance-1/ctrl.yaml
[[ -f $CTRL.orig ]] || cp "$CTRL" "$CTRL.orig"
cp "$CTRL.orig" "$CTRL"

# the CA bundle clients download: the private root plus the Let's Encrypt roots
curl -fsSL -o "$DEMO_DIR/le/isrgrootx1.pem" https://letsencrypt.org/certs/isrgrootx1.pem
curl -fsSL -o "$DEMO_DIR/le/isrg-root-x2.pem" https://letsencrypt.org/certs/isrg-root-x2.pem
cat "$QS/pki/root-ca/certs/root-ca.cert" "$DEMO_DIR/le/isrgrootx1.pem" "$DEMO_DIR/le/isrg-root-x2.pem" \
  > "$QS/web-ca-bundle.pem"

# 1. edge.api.address and the web bindPoint address become the name only the public certificate claims. The control
#    plane's advertiseAddress keeps addbyurl-ctrl.
# 2. alt_server_certs replaces the commented-out example in the web listener's identity.
# 3. the web listener's ca, indented six spaces, gets the bundle. The controller's own ca, indented two, stays.
ALT="      alt_server_certs:\n"
ALT+="        - server_cert: \"$DEMO_DIR/le/fullchain.pem\"\n"
ALT+="          server_key:  \"$DEMO_DIR/le/privkey.pem\""
sed -E -i \
  -e "s#^(\s+)address: addbyurl-ctrl\.#\1address: addbyurl.#" \
  -e "s#^      ca: .*#      ca:          \"$QS/web-ca-bundle.pem\"#" \
  -e "s#^      \#alt_server_certs:#$ALT#" \
  "$CTRL"

diff "$CTRL.orig" "$CTRL" || true
