#!/usr/bin/env bash
# Puts the demo back so you can run it again.
#   bash reset.sh       alice, bob, carol and dave are gone from OpenZiti, signed out of Keycloak, and alice is in
#                       engineering only again. The controller, Keycloak and the services stay up: rerun from step 7.
#   bash reset.sh all   everything this episode started is gone, except the Let's Encrypt copies in $DEMO_DIR/le.
#                       Rerun from step 3.
# Either way, Forget the identities in each Ziti Desktop Edge afterward.
set -uo pipefail
source "$(dirname "$0")/.env"
A=$DEMO_DIR
Z=$A/bin/ziti
K="docker exec kc-acme /opt/keycloak/bin/kcadm.sh"

if [[ ${1:-} == all ]]; then
  $Z edge login "addbyurl.$DOMAIN:$CTRL_PORT" -u admin -p "$ZITI_PWD" -y >/dev/null &&
    bash "$(dirname "$0")/ziti-setup.sh" clean
  for p in host router ctrl; do [[ -f $A/$p.pid ]] && kill "$(cat "$A/$p.pid")" 2>/dev/null; done
  docker rm -f kc-acme whoami-eng whoami-fin >/dev/null 2>&1
  find "$A" -mindepth 1 -maxdepth 1 ! -name le -exec rm -rf {} +
  echo "reset all: only $A/le is left"
  exit 0
fi

$Z edge login "addbyurl.$DOMAIN:$CTRL_PORT" -u admin -p "$ZITI_PWD" -y >/dev/null
for u in alice bob carol dave; do $Z edge delete identity "$u" 2>/dev/null || true; done

$K config credentials --server http://localhost:8080 --realm master --user admin --password "$KC_PWD" >/dev/null
FIN=$($K get groups -r acme -q search=finance --fields id --format csv --noquotes)
for u in alice bob carol dave; do
  id=$($K get users -r acme -q username="$u" -q exact=true --fields id --format csv --noquotes)
  # ends every Keycloak session, so the next sign-in asks for a password instead of reusing the browser's
  $K create "users/$id/logout" -r acme >/dev/null
done
ALICE=$($K get users -r acme -q username=alice -q exact=true --fields id --format csv --noquotes)
$K delete "users/$ALICE/groups/$FIN" -r acme 2>/dev/null || true

$Z edge list identities
echo "reset: rerun from step 7. Forget the identities in each Ziti Desktop Edge."
