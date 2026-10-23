#!/usr/bin/env bash
# The OpenZiti side of the episode: the external JWT signer, the auth policy new identities land in, two services,
# and one dial policy per IdP group. Run after `ziti edge login`. `./ziti-setup.sh clean` removes all of it.
set -euo pipefail
source "$(dirname "$0")/.env"
Z=$DEMO_DIR/bin/ziti

if [[ ${1:-} == clean ]]; then
  for p in engineering-dial finance-dial acme-host-bind; do $Z edge delete service-policy "$p" || true; done
  for s in eng-wiki finance-ledger; do
    $Z edge delete service "$s" || true
    $Z edge delete config "$s.intercept" || true
    $Z edge delete config "$s.host" || true
  done
  for i in acme-host alice bob carol; do $Z edge delete identity "$i" || true; done
  # the policy references the signer, so it goes first
  $Z edge delete auth-policy idp-users || true
  $Z edge delete ext-jwt-signer acme-idp || true
  exit 0
fi

IDP=https://addbyurl-idp.$DOMAIN:$KC_PORT/realms/acme

# 1. the signer: trust Keycloak's tokens, and let them create identities
SIGNER_ID=$($Z edge create ext-jwt-signer acme-idp "$IDP" \
  --jwks-endpoint "$IDP/protocol/openid-connect/certs" \
  --audience openziti \
  --claims-property email \
  --external-auth-url "$IDP" \
  --client-id openziti --scopes openid --scopes profile --scopes email \
  --enroll-to-token --enroll-to-cert \
  --enroll-name-claims-selector preferred_username \
  --enroll-attr-claims-selector groups)

# 2. the auth policy every new identity lands in. The signer and the policy point at each other, so: signer, policy,
#    then link them.
POLICY_ID=$($Z edge create auth-policy idp-users \
  --primary-cert-allowed \
  --primary-ext-jwt-allowed --primary-ext-jwt-allowed-signers "$SIGNER_ID")
$Z edge update ext-jwt-signer acme-idp --enroll-auth-policy "$POLICY_ID"

# 3. two services, one per IdP group, each a whoami container on this machine
for svc in eng-wiki:9781 finance-ledger:9782; do
  name=${svc%%:*}; port=${svc##*:}
  $Z edge create config "$name.intercept" intercept.v1 \
    "{\"protocols\":[\"tcp\"],\"addresses\":[\"$name.acme.ziti\"],\"portRanges\":[{\"low\":80,\"high\":80}]}"
  $Z edge create config "$name.host" host.v1 \
    "{\"protocol\":\"tcp\",\"address\":\"127.0.0.1\",\"port\":$port}"
  $Z edge create service "$name" --configs "$name.intercept,$name.host"
done

# 4. dial policies written against the IdP's group names
$Z edge create service-policy engineering-dial Dial --identity-roles '#engineering' --service-roles '@eng-wiki'
$Z edge create service-policy finance-dial Dial --identity-roles '#finance' --service-roles '@finance-ledger'

# 5. a host identity on this machine that serves both
$Z edge create identity acme-host --role-attributes host -o "$DEMO_DIR/acme-host.jwt"
$Z edge create service-policy acme-host-bind Bind --identity-roles '#host' --service-roles '@eng-wiki,@finance-ledger'
