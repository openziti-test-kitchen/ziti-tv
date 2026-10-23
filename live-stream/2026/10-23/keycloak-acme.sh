#!/usr/bin/env bash
# Builds Acme's identity provider: a Keycloak realm with two groups, three users, and the public client the
# tunnelers sign in through. Run after the kc-acme container is up.
set -euo pipefail
source "$(dirname "$0")/.env"
K="docker exec kc-acme /opt/keycloak/bin/kcadm.sh"

# kcadm runs inside the container, where dev mode also listens on plain http
$K config credentials --server http://localhost:8080 --realm master --user admin --password "$KC_PWD"

$K create realms -s realm=acme -s enabled=true

ENG=$($K create groups -r acme -s name=engineering -i)
FIN=$($K create groups -r acme -s name=finance -i)

# carol has no groups: she can still enroll, and gets no role attributes. dave is a throwaway for the opening
for u in alice:"$ENG" bob:"$FIN" carol: dave:"$ENG"; do
  name=${u%%:*}; group=${u#*:}
  id=$($K create users -r acme -i -s username="$name" -s enabled=true \
    -s email="$name@acme.example" -s emailVerified=true -s firstName="${name^}" -s lastName=Acme)
  $K set-password -r acme --username "$name" --new-password "$name-demo-pw"
  if [[ -n $group ]]; then
    $K update "users/$id/groups/$group" -r acme -s realm=acme -s userId="$id" -s groupId="$group" -n
  fi
done

# the tunnelers are public clients: no secret, PKCE, and they listen on localhost:20314 for the browser to come back
CID=$($K create clients -r acme -i \
  -s clientId=openziti -s publicClient=true -s standardFlowEnabled=true -s directAccessGrantsEnabled=false \
  -s 'redirectUris=["http://localhost:20314/auth/callback"]' \
  -s 'attributes={"pkce.code.challenge.method":"S256"}')

# the external JWT signer checks the access token's audience for "openziti"
$K create "clients/$CID/protocol-mappers/models" -r acme \
  -s name=openziti-audience -s protocol=openid-connect -s protocolMapper=oidc-audience-mapper \
  -s 'config={"included.client.audience":"openziti","access.token.claim":"true","id.token.claim":"false"}'

# "groups": ["engineering"], not ["/engineering"], so the names line up with #engineering in OpenZiti
$K create "clients/$CID/protocol-mappers/models" -r acme \
  -s name=groups -s protocol=openid-connect -s protocolMapper=oidc-group-membership-mapper \
  -s 'config={"claim.name":"groups","full.path":"false","access.token.claim":"true","id.token.claim":"true","userinfo.token.claim":"true"}'
