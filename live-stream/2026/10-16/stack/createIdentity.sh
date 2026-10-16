#!/bin/sh
# Does what the Appetizer's web form does: asks it for an identity named <name>, downloads the one-time enrollment
# token, and enrolls it. The identity file lands in ZITI_DEMO_DIR (default ~/.ziti-demo) as local_<name>.json.
#
#   ./createIdentity.sh ziggy
set -e
name=${1:?usage: ./createIdentity.sh <name>}
cd "$(dirname "$0")"
port=$(sed -n 's/^APPETIZER_PORT=//p' .env)
dir=$(sed -n 's/^ZITI_DEMO_DIR=//p' .env)
app="http://127.0.0.1:${port:-18000}"
out="${dir:-$HOME/.ziti-demo}/local_${name}.json"
mkdir -p "$(dirname "$out")"

token=$(curl -s -d "name=${name}" "$app/add-me-to-openziti" | grep -o 'download-token?token=[A-Za-z0-9._-]*' | cut -d= -f2)
if [ -z "$token" ]; then
  echo "the Appetizer at $app returned no enrollment token: is it up?" >&2
  exit 1
fi

# enroll inside the quickstart container, which has the ziti CLI. The key is generated there and written to $out.
curl -s "$app/download-token?token=$token" | docker compose exec -T quickstart sh -c \
  'cat > /tmp/e.jwt && ziti edge enroll /tmp/e.jwt -o /tmp/e.json >/dev/null && cat /tmp/e.json; rm -f /tmp/e.*' \
  > "$out"
if [ ! -s "$out" ]; then
  echo "enrollment failed: $out is empty" >&2
  exit 1
fi
chmod 600 "$out"
echo "wrote $out"
