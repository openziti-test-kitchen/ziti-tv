# Deletes everything setup.sh made, on the controller and in ./zab. Safe to rerun.
# Stop `zab run` first. Run from this directory: bash reset.sh, then bash setup.sh to start over.
set -uo pipefail
cd "$(dirname "$0")"
set -a; source .env; set +a

ziti edge login "$ZITI_CTRL" -u "$ZITI_USER" -p "$ZITI_PASSWORD" -y >/dev/null || exit 1

for svc in wiki ledger; do
  ziti edge delete service-policies "$svc-dial" "$svc-bind" >/dev/null 2>&1 || true
  ziti edge delete service "$svc" >/dev/null 2>&1 || true
  ziti edge delete configs "$svc.host" "$svc.zab-v1.0.0" >/dev/null 2>&1 || true
done
ziti edge delete config-type zab-v1.0.0 >/dev/null 2>&1 || true

for who in "$ALICE" "$BOB" "$CAROL" zab; do ziti edge delete identity "$who" >/dev/null 2>&1 || true; done

# the auth policy has to let go of the signer before the signer can be deleted
ziti edge update auth-policy default --primary-ext-jwt-allowed=false --primary-ext-jwt-allowed-signers '' \
  >/dev/null 2>&1 || true
ziti edge delete ext-jwt-signer cloudflare-access >/dev/null 2>&1 || true

# keep tunnel.token: it came from Cloudflare, not from setup.sh
rm -f zab/config.yml zab/zab.jwt zab/zab.key zab/zab.cert zab/zab.ca zab/endpoints.yml zab/zab.sock

echo "left on the controller:"
ziti edge list identities 'name contains "@" or name = "zab"' 2>/dev/null | tail -n +1
ziti edge list services 'name in ["wiki","ledger"]' 2>/dev/null
ziti edge list ext-jwt-signers 'name = "cloudflare-access"' 2>/dev/null
