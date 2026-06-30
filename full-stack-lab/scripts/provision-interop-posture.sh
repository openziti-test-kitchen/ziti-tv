#!/usr/bin/env bash
# Layer 1 (interop-matrix Section 5): posture checks on the matrix.
#
# Splits the interop CLIENT identities into two camps and gates one camp behind a battery of
# posture checks so you can watch its rows flip grey:
#   - #clients.trusted  -> reach everything via the existing dial-interop policy
#   - #clients.posture  -> reach #interop only via dial-interop-posture, which requires
#                          ALL posture checks tagged #posture.matrix to pass
#
# It creates ONE posture check of EACH type so learners see the whole menu:
#   os       pc-os-linux       device OS must be Linux
#   process  pc-proc-ziti      a required binary must be present and running
#   mac      pc-mac-allow      device MAC must be on an allowlist
#   domain   pc-domain-win     device must be joined to a Windows domain
#
# WHAT TO OBSERVE: the Linux interop client containers cannot satisfy the mac/domain (and the
# Windows process path) checks, so every #clients.posture identity is DENIED on every #interop
# service. In the matrix those whole ROWS go grey (policy/posture denial), while the
# #clients.trusted rows stay green. Same code, same services: access decided by device state.
# Flip a posture check (e.g. add the real MAC to the allowlist) and re-run the matrix to watch a
# row come back. Posture is evaluated per-dial, so the change shows up on the next dial.
#
# Idempotent (delete-then-create). Builds on scripts/provision-interop.sh and matches the exact
# in-container heredoc pattern from scripts/provision-posture.sh (ziti at /usr/local/bin/ziti via
# a DOUBLE leading slash to dodge Git Bash path mangling, output to a log via docker cp).
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p scratch

LEADER_CTR="${LEADER_CTR:-${COMPOSE_PROJECT_NAME:-zo}-ziti-controller1-1}"
CODES="${INTEROP_CODES:-go py js cs java c swift}"

# Which client codes become "posture" clients (the rest stay "trusted"). Override with
# POSTURE_CODES="py js" etc. Default: tag py + js as posture so two rows go grey for contrast.
POSTURE_CODES="${POSTURE_CODES:-py js}"

# A required process for the process posture check. The Linux containers will not have this exact
# Windows binary, which is part of why posture clients are denied. Override if you want a check
# that actually passes on Linux (e.g. PROC_OS=Linux PROC_PATH=/bin/sh).
PROC_OS="${PROC_OS:-Windows}"
PROC_PATH="${PROC_PATH:-C:\\Program Files\\OpenZiti\\ziti.exe}"

# MAC allowlist + Windows domain that the lab devices will NOT match (the whole point).
MAC_ALLOW="${MAC_ALLOW:-aa:bb:cc:dd:ee:ff}"
WIN_DOMAIN="${WIN_DOMAIN:-corp.example.com}"

dcp() {
  local i
  for i in 1 2 3 4 5; do
    docker cp "$@" && return 0
    sleep 1
  done
  echo "ERROR: docker cp failed after retries: $*" >&2
  return 1
}

# CODES / POSTURE_CODES / the parameters are expanded on the host into the heredoc so the
# in-container /bin/sh only iterates fixed lists.
cat > scratch/provision-interop-posture.gen.sh <<PROV
#!/bin/sh
Z=//usr/local/bin/ziti
CODES="${CODES}"
POSTURE_CODES="${POSTURE_CODES}"
{
  \$Z edge login localhost:1280 -u admin -p "\${ZITI_PWD:-admin}" -y

  # Clean slate (delete-then-create).
  \$Z edge delete service-policy dial-interop-posture || true
  \$Z edge delete posture-check pc-os-linux  || true
  \$Z edge delete posture-check pc-proc-ziti || true
  \$Z edge delete posture-check pc-mac-allow || true
  \$Z edge delete posture-check pc-domain-win || true

  # Re-tag the chosen clients: split #clients into #clients.trusted and #clients.posture.
  # Every interop client keeps #clients (so the original dial-interop still applies to trusted
  # ones) but posture clients ALSO get #clients.posture; we then make the posture policy the only
  # one that lets them in by NOT relying on the broad #clients tag for them. To keep it simple and
  # observable we move posture clients fully onto #clients.posture and trusted ones onto
  # #clients.trusted, and re-point reach through the two policies below.
  for c in \$CODES; do
    case " \$POSTURE_CODES " in
      *" \$c "*)
        # posture client: ONLY #clients.posture (loses broad #clients reach)
        \$Z edge update identity "icli-\$c" -a "clients.posture" ;;
      *)
        # trusted client: ONLY #clients.trusted
        \$Z edge update identity "icli-\$c" -a "clients.trusted" ;;
    esac
  done

  # Re-point the ORIGINAL broad dial policy at the trusted camp so trusted clients keep full reach.
  # (dial-interop was created by provision-interop.sh with --identity-roles '#clients'.)
  \$Z edge update service-policy dial-interop --identity-roles '#clients.trusted'

  # One posture check of EACH type, all tagged #posture.matrix.
  # os: device OS must be Linux.
  \$Z edge create posture-check os pc-os-linux --os Linux -a posture.matrix
  # process: a required binary must be present/running (Windows path here, so Linux fails it).
  \$Z edge create posture-check process pc-proc-ziti "${PROC_OS}" "${PROC_PATH}" -a posture.matrix
  # mac: device MAC must be on the allowlist (lab devices are not).
  \$Z edge create posture-check mac pc-mac-allow -m "${MAC_ALLOW}" -a posture.matrix
  # domain: device must be joined to this Windows domain (lab Linux devices are not).
  \$Z edge create posture-check domain pc-domain-win -d "${WIN_DOMAIN}" -a posture.matrix

  # Second Dial policy: #clients.posture may dial #interop ONLY if ALL #posture.matrix checks pass.
  \$Z edge create service-policy dial-interop-posture Dial \
    --identity-roles '#clients.posture' --service-roles '#interop' \
    --posture-check-roles '#posture.matrix'

  echo "== posture checks (#posture.matrix) =="
  \$Z edge list posture-checks 'name contains "pc-"'
  echo "== dial policies (note posture check column on dial-interop-posture) =="
  \$Z edge list service-policies 'name contains "dial-interop"'
  echo "== client identity role attributes (trusted vs posture) =="
  \$Z edge list identities 'name contains "icli-"'
} > //tmp/provision-interop-posture.log 2>&1
PROV

tr -d '\r' < scratch/provision-interop-posture.gen.sh > scratch/provision-interop-posture.sh

echo "==> Layering posture checks on the interop matrix (${LEADER_CTR})"
echo "    posture clients: ${POSTURE_CODES}  (these rows should go grey)"
dcp scratch/provision-interop-posture.sh "${LEADER_CTR}:/tmp/provision-interop-posture.sh"
docker exec "$LEADER_CTR" sh //tmp/provision-interop-posture.sh
dcp "${LEADER_CTR}:/tmp/provision-interop-posture.log" scratch/provision-interop-posture.log
cat scratch/provision-interop-posture.log

echo "==> Done. Re-run the matrix harness and look for grey rows on: ${POSTURE_CODES}"
echo "    (trusted clients keep full reach via dial-interop; posture clients gate on #posture.matrix)"
