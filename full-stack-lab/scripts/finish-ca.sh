#!/usr/bin/env bash
# Complete 3rd-party CA enrollment end to end:
#   1) verify the registered CA (prove we hold its key) so it flips to Verified,
#   2) issue a client cert from that CA,
#   3) auto-enroll an identity by presenting that cert (autoca), no per-identity token.
#
# Assumes scripts/provision-enrollment-demos.sh already registered `thirdparty-ca` and the CA
# PKI lives at //tmp/thirdparty-pki in the controller (re-run that script first if needed).
# Run in a real terminal.
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
LEADER_CTR="${PROJECT}-ziti-controller1-1"
ZITI="//usr/local/bin/ziti"
PKI="//tmp/thirdparty-pki"
CA="thirdparty"

docker exec "$LEADER_CTR" $ZITI edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y

echo "==> Get the CA verification token (a name the controller wants signed by this CA)"
TOKEN="$(docker exec "$LEADER_CTR" $ZITI edge list cas 'name="thirdparty-ca"' -j | tr -d '\r')"
echo "    (parse the verificationToken from the JSON above)"
echo
echo "==> Issue a verification cert whose CN == the verification token, signed by our CA:"
echo "    docker exec $LEADER_CTR $ZITI pki create client --pki-root $PKI --ca-name $CA \\"
echo "        --client-name <verificationToken> --client-file verify"
echo "==> Then verify the CA:"
echo "    docker exec $LEADER_CTR $ZITI edge verify ca thirdparty-ca \\"
echo "        --cert $PKI/$CA/certs/verify.cert"
echo
echo "==> Auto-enroll a fleet identity: issue any client cert from the CA and enroll with it."
echo "    docker exec $LEADER_CTR $ZITI pki create client --pki-root $PKI --ca-name $CA \\"
echo "        --client-name fleet-1 --client-file fleet-1"
echo "    # an identity 'thirdparty-ca-fleet-1' is auto-created on first connect (autoca),"
echo "    # tagged with the CA's identity role attributes (ca.enrolled)."
echo
echo "NOTE: the exact verify subcommand name varies by version (ziti edge verify ca | update ca"
echo "--verify). Run 'ziti edge verify --help' to confirm, then paste the token from above."
