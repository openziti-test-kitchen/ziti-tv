# Creates everything ZAB needs on the OpenZiti side. Safe to rerun: it deletes what it made, then makes it again.
# Run from this directory: bash setup.sh
set -euo pipefail
cd "$(dirname "$0")"
set -a; source .env; set +a

ZAB="${ZAB:-zab}"
mkdir -p zab

ziti edge login "$ZITI_CTRL" -u "$ZITI_USER" -p "$ZITI_PASSWORD" -y >/dev/null

# ZAB's own identity: finds the controllers and manages the zab config type. It carries no user traffic.
cat > zab/config.yml <<YAML
identity:
  key: ./zab.key
  cert: ./zab.cert
  ca: ./zab.ca
endpointFile: ./endpoints.yml
socketFile: ./zab.sock
cloudflare:
  teamDomain: ${CF_TEAM_DOMAIN}
  audTags:
    - ${CF_AUD}
  tunnelTokenFile: ./tunnel.token
identityClaim: email
pool:
  idleWindow: 30m
  grace: 5m
dialTimeout: 10s
logLevel: info
YAML
ziti edge delete identity zab >/dev/null 2>&1 || true
rm -f zab/zab.key zab/zab.cert zab/zab.ca zab/endpoints.yml
ziti edge create identity zab --admin -o zab/zab.jwt >/dev/null
"$ZAB" --config zab/config.yml enroll zab/zab.jwt
"$ZAB" --config zab/config.yml agent register-configs

# trust Cloudflare Access JWTs, and match their email claim to an identity's external id.
# A signer the auth policy still names cannot be deleted, so release it first.
ziti edge update auth-policy default --primary-ext-jwt-allowed-signers '' >/dev/null 2>&1 || true
ziti edge delete ext-jwt-signer cloudflare-access >/dev/null 2>&1 || true
signer=$(ziti edge create ext-jwt-signer cloudflare-access "https://${CF_TEAM_DOMAIN}" \
  --jwks-endpoint "https://${CF_TEAM_DOMAIN}/cdn-cgi/access/certs" \
  --audience "$CF_AUD" --claims-property email | tail -1)
ziti edge update auth-policy default --primary-ext-jwt-allowed --primary-ext-jwt-allowed-signers "$signer"

# three people. alice is in eng and fin, bob only eng, carol in nothing
for who in "$ALICE" "$BOB" "$CAROL"; do ziti edge delete identity "$who" >/dev/null 2>&1 || true; done
ziti edge create identity "$ALICE" --external-id "$ALICE" -a eng,fin >/dev/null
ziti edge create identity "$BOB" --external-id "$BOB" -a eng >/dev/null
ziti edge create identity "$CAROL" --external-id "$CAROL" >/dev/null

# two apps on one hostname: / is the wiki, /ledger is the ledger
for svc in wiki ledger; do
  ziti edge delete service-policies "$svc-dial" "$svc-bind" >/dev/null 2>&1 || true
  ziti edge delete service "$svc" >/dev/null 2>&1 || true
  ziti edge delete configs "$svc.host" "$svc.zab-v1.0.0" >/dev/null 2>&1 || true
done
"$ZAB" --config zab/config.yml agent service set wiki --route "$ZAB_HOST"
"$ZAB" --config zab/config.yml agent service set ledger --route "$ZAB_HOST/ledger" --strip-path-prefix
ziti edge create config wiki.host host.v1 \
  "{\"protocol\":\"tcp\",\"address\":\"127.0.0.1\",\"port\":${WIKI_PORT}}" >/dev/null
ziti edge create config ledger.host host.v1 \
  "{\"protocol\":\"tcp\",\"address\":\"127.0.0.1\",\"port\":${LEDGER_PORT}}" >/dev/null
# --configs replaces the list, so name both
ziti edge update service wiki --configs wiki.zab-v1.0.0,wiki.host
ziti edge update service ledger --configs ledger.zab-v1.0.0,ledger.host

# only the router hosts. Bind for '#all' would let every person see both services
ziti edge create service-policy wiki-bind Bind --service-roles '@wiki' --identity-roles "@${ZITI_ROUTER}" >/dev/null
ziti edge create service-policy ledger-bind Bind --service-roles '@ledger' --identity-roles "@${ZITI_ROUTER}" >/dev/null
ziti edge create service-policy wiki-dial Dial --service-roles '@wiki' --identity-roles '#eng' >/dev/null
ziti edge create service-policy ledger-dial Dial --service-roles '@ledger' --identity-roles '#fin' >/dev/null

ziti edge policy-advisor identities -q "$ALICE"
