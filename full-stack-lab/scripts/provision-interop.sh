#!/usr/bin/env bash
# Provision the interop matrix model: every SDK as both echo+http server and as a client, with
# ONE Dial policy granting full NxN reach and a per-language Bind policy. See docs/interop-matrix.md
# sections 3 and 4. Idempotent (deletes first), mints + enrolls every identity, and stages the
# enrolled identity JSON onto the host under tokens/interop/<identity>.json.
#
# Per language code <c>:
#   services    echo.<c> (#interop #echo #srv.<c>) and http.<c> (#interop #http #srv.<c>)
#   server id   isrv-<c>  (#host.<c>)   binds echo.<c> + http.<c> via bind-<c>
#   client id   icli-<c>  (#clients)    dials everything via dial-interop
# Plus erp-all + serp-all so all identities use all routers and all services route everywhere.
#
# Conventions (see provision-echo.sh / addendum_03): in-container abs paths use //, ziti at
# /usr/local/bin/ziti, output to stderr, capture via a log file + docker cp (with retry). The
# in-container script enrolls each identity (ziti edge enroll <jwt> -o <json>) so we copy ready
# to use JSON out, not just JWTs.
set -euo pipefail

cd "$(dirname "$0")/.."

LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
CODES="${INTEROP_CODES:-go py js cs java c swift}"
mkdir -p tokens/interop scratch

dcp() {
  local i
  for i in 1 2 3 4 5; do
    docker cp "$@" && return 0
    sleep 1
  done
  echo "ERROR: docker cp failed after retries: $*" >&2
  return 1
}

# In-container provisioning script. CODES is expanded on the host into the heredoc so the
# in-container /bin/sh just iterates a fixed list.
cat > scratch/provision-interop.gen.sh <<PROV
#!/bin/sh
Z=//usr/local/bin/ziti
CODES="${CODES}"
{
  \$Z edge login localhost:1280 -u admin -p "\${ZITI_PWD:-admin}" -y

  # Clean slate so this is re-runnable (delete-then-create).
  \$Z edge delete service-policy dial-interop || true
  for c in \$CODES; do
    \$Z edge delete service "echo.\$c" || true
    \$Z edge delete service "http.\$c" || true
    \$Z edge delete identity "isrv-\$c" || true
    \$Z edge delete identity "icli-\$c" || true
    \$Z edge delete service-policy "bind-\$c" || true
  done

  # Services: one echo + one http per language, all #interop, role-tagged per app and per srv.
  for c in \$CODES; do
    \$Z edge create service "echo.\$c" -a "interop,echo,srv.\$c"
    \$Z edge create service "http.\$c" -a "interop,http,srv.\$c"
  done

  # Identities: a server (#host.<c>) and a client (#clients) per language. Mint OTT JWTs.
  for c in \$CODES; do
    \$Z edge create identity "isrv-\$c" -a "host.\$c" -o "//tmp/isrv-\$c.jwt"
    \$Z edge create identity "icli-\$c" -a clients   -o "//tmp/icli-\$c.jwt"
  done

  # ONE Dial policy: any #clients identity may dial any #interop service (full NxN reach).
  \$Z edge create service-policy dial-interop Dial \
    --identity-roles '#clients' --service-roles '#interop'

  # Per-language Bind policy: isrv-<c> (#host.<c>) binds only its own #srv.<c> services.
  for c in \$CODES; do
    \$Z edge create service-policy "bind-\$c" Bind \
      --identity-roles "#host.\$c" --service-roles "#srv.\$c"
  done

  # Ensure the lab-wide router policies exist (create only if missing, do not churn them).
  \$Z edge list edge-router-policies 'name="erp-all"' | grep -q erp-all \
    || \$Z edge create edge-router-policy erp-all --identity-roles '#all' --edge-router-roles '#all'
  \$Z edge list service-edge-router-policies 'name="serp-all"' | grep -q serp-all \
    || \$Z edge create service-edge-router-policy serp-all --service-roles '#all' --edge-router-roles '#all'

  # Enroll every identity to JSON in-container so we can copy ready-to-mount files out.
  for c in \$CODES; do
    \$Z edge enroll "//tmp/isrv-\$c.jwt" -o "//tmp/isrv-\$c.json"
    \$Z edge enroll "//tmp/icli-\$c.jwt" -o "//tmp/icli-\$c.json"
  done

  echo "== services =="
  \$Z edge list services 'name contains "."'
  echo "== service-policies =="
  \$Z edge list service-policies 'name contains "interop" or name contains "bind-"'
  echo "== identities =="
  \$Z edge list identities 'name contains "isrv-" or name contains "icli-"'
} > //tmp/provision-interop.log 2>&1
PROV

tr -d '\r' < scratch/provision-interop.gen.sh > scratch/provision-interop.sh

echo "==> Provisioning interop matrix model on ${LEADER_CTR} (codes: ${CODES})"
dcp scratch/provision-interop.sh "${LEADER_CTR}:/tmp/provision-interop.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-interop.sh

echo "==> Staging enrolled identity JSON to tokens/interop/"
# Tar all enrolled JSONs in-container and copy ONE archive out, then extract. This is robust
# across shells (a single docker cp of a relative-named archive) where 14 per-file container-path
# copies can be mangled by Git Bash path conversion.
docker exec "$LEADER_CTR" sh -c 'cd //tmp && tar czf interop-ids.tgz isrv-*.json icli-*.json'
dcp "${LEADER_CTR}:/tmp/interop-ids.tgz" scratch/interop-ids.tgz
tar xzf scratch/interop-ids.tgz -C tokens/interop

echo "==> Provisioning log:"
dcp "${LEADER_CTR}:/tmp/provision-interop.log" scratch/provision-interop.log
cat scratch/provision-interop.log

echo "==> Summary"
echo "    codes      : ${CODES}"
echo "    services   : echo.<c> + http.<c> per code (#interop)"
echo "    identities : isrv-<c> (#host.<c>), icli-<c> (#clients)"
echo "    policies   : dial-interop (#clients -> #interop), bind-<c> (#host.<c> -> #srv.<c>)"
echo "    staged     : $(ls tokens/interop/*.json 2>/dev/null | wc -l) identity JSON file(s) under tokens/interop/"
