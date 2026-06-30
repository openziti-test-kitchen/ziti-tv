#!/usr/bin/env bash
# Custom pathing demo: force a dial to take the scenic route home -> internet -> vpc1 -> vpc2
# instead of the direct shortcut, using link static cost. Works on the `deep` service (single
# terminator on vpc2-er, see scripts/provision-pathing.sh) dialed from a home client.
#
# The lab is a full mesh, so by default smart routing takes the 1-hop home-er -> vpc2-er link.
# We make every link EXCEPT the chain expensive, so the cheapest path becomes the 3-hop chain
# home-er -> public-er-1 -> vpc1-er -> vpc2-er. Reset puts every link back to cost 1.
#
# Usage (run in a real terminal so docker exec output shows):
#   scripts/demo-longpath.sh links       # show links + their cost
#   scripts/demo-longpath.sh force       # make non-chain links expensive (force the scenic route)
#   scripts/demo-longpath.sh circuits    # show active circuits + PATH (hold a dial first, below)
#   scripts/demo-longpath.sh reset       # all links back to cost 1
#   scripts/demo-longpath.sh hold        # hold a deep.ziti dial open ~40s from the roamer client
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
CTR="${PROJECT}-ziti-controller1-1"
Z="//usr/local/bin/ziti"

# The chain we want traffic to follow, as unordered router-name pairs.
chain_pair() {
  case "$1|$2" in
    "home-er|public-er-1"|"public-er-1|home-er") return 0 ;;
    "public-er-1|vpc1-er"|"vpc1-er|public-er-1") return 0 ;;
    "vpc1-er|vpc2-er"|"vpc2-er|vpc1-er")         return 0 ;;
  esac
  return 1
}

login() { docker exec "$CTR" $Z edge login localhost:1280 -u admin -p "${ZITI_PWD:-admin}" -y >/dev/null 2>&1 || true; }

# Emit "ID DIALER ACCEPTOR" per link by parsing the box-drawn table.
list_links_raw() {
  docker exec "$CTR" $Z fabric list links \
    | awk -F'│' 'NF>=4 && $2 ~ /[A-Za-z0-9]/ && $2 !~ /ID/ {gsub(/ /,"",$2);gsub(/^ +| +$/,"",$3);gsub(/^ +| +$/,"",$4);print $2"\t"$3"\t"$4}'
}

case "${1:?usage: demo-longpath.sh links|force|circuits|reset|hold}" in
  links)
    docker exec "$CTR" $Z fabric list links ;;
  force)
    echo "==> Making non-chain links expensive so the scenic route wins"
    list_links_raw | while IFS=$'\t' read -r id d a; do
      if chain_pair "$d" "$a"; then
        docker exec "$CTR" $Z fabric update link "$id" --static-cost 1 >/dev/null && echo "  keep cheap : $d <-> $a"
      else
        docker exec "$CTR" $Z fabric update link "$id" --static-cost 9999 >/dev/null && echo "  costly     : $d <-> $a"
      fi
    done
    echo "==> Now dial deep.ziti from a home client and inspect the circuit:"
    echo "    scripts/demo-longpath.sh hold &   then   scripts/demo-longpath.sh circuits" ;;
  reset)
    echo "==> Resetting every link to cost 1"
    list_links_raw | while IFS=$'\t' read -r id d a; do
      docker exec "$CTR" $Z fabric update link "$id" --static-cost 1 >/dev/null && echo "  reset      : $d <-> $a"
    done ;;
  circuits)
    login
    docker exec "$CTR" $Z fabric list circuits ;;
  hold)
    # hold a deep.ziti connection open from the roamer (home) client so a circuit exists
    docker exec "$PROJECT-roamer-1" bash -c 'exec 3<>/dev/tcp/deep.ziti/80; sleep 40' ;;
  *) echo "unknown action" >&2; exit 1 ;;
esac
