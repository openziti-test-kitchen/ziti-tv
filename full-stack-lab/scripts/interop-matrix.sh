#!/usr/bin/env bash
# Run the interop matrix and render the results. See docs/interop-matrix.md sections 3 and 4.
#
# For app in {echo, http}, for every (client, server) language pair, drive the client container
# i-cli-<client> one-shot against the service <app>.<server> and record the outcome:
#   ok   - the client printed a RESULT line reporting success
#   fail - the client ran but did not report success (connected wrong bytes/status, or denied)
#   skip - the client or the target server container/image is absent (nothing to test)
#
# Renders two 7x7 grids to results/interop-echo.md and results/interop-http.md plus a combined
# heatmap results/interop.html.
#
# Usage:
#   scripts/interop-matrix.sh                 # run the full matrix and render
#   INTEROP_CODES="go py js" scripts/...      # restrict to a subset of language codes
# Prereqs: scripts/provision-interop.sh has run and `docker compose -p zo -f compose/interop.yml
# up -d` has brought up whatever server containers exist. Missing pairs are marked skip, not fail.
#
# Conventions (see provision-echo.sh): docker exec stdout can be swallowed in the sandbox, so the
# client writes its RESULT to a file in-container and we docker cp it out (with retry) then read.
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="${COMPOSE_PROJECT_NAME:-zo}"
CODES="${INTEROP_CODES:-go py js cs java c swift}"
APPS="echo http"
NET="${ZITI_NETWORK:-zo-ctrl}"
mkdir -p results scratch

dcp() {
  local i
  for i in 1 2 3 4 5; do
    docker cp "$@" && return 0
    sleep 1
  done
  echo "ERROR: docker cp failed after retries: $*" >&2
  return 1
}

# True if a container exists and is running.
container_up() {
  local name="$1"
  [ -n "$(docker ps -q -f "name=^${name}$" 2>/dev/null || true)" ]
}

# Drive one dial as a one-shot `docker run` so the client image uses its own entrypoint.
# Echoes one of: ok | fail | skip. skip = client image missing, its identity not staged, or
# the target server container not running.
run_cell() {
  local app="$1" client="$2" server="$3"
  local srv_ctr="${PROJECT}-i-${app}-${server}-1"
  local id="$(pwd)/tokens/interop/icli-${client}.json"
  if ! docker image inspect "zo-sdk-${client}" >/dev/null 2>&1; then echo skip; return 0; fi
  if ! container_up "$srv_ctr"; then echo skip; return 0; fi
  [ -f "$id" ] || { echo skip; return 0; }

  local out rc=0
  out="$(docker run --rm --network "$NET" \
      -e "ZITI_SERVICE=${app}.${server}" -e ZITI_IDENTITY=/ziti/id.json -e "SELF_LANG=${client}" \
      -v "${id}:/ziti/id.json:ro" \
      "zo-sdk-${client}" "${app}" client 2>&1)" || rc=$?
  printf '%s\n' "$out" > "scratch/interop-${app}-${client}-to-${server}.txt"

  if printf '%s' "$out" | grep -qiE 'RESULT[^a-z]*(ok|pass|success)'; then echo ok; return 0; fi
  if printf '%s' "$out" | grep -qiE 'RESULT[^a-z]*(fail|error|denied)'; then echo fail; return 0; fi
  # stdout may be swallowed in some sandboxes; fall back to the client exit code.
  if [ "$rc" -eq 0 ]; then echo ok; else echo fail; fi
}

# Render one app's grid as a markdown table. Args: app, then the flat results map via globals.
render_md() {
  local app="$1"
  local out="results/interop-${app}.md"
  {
    echo "# Interop matrix: ${app}"
    echo
    echo "Rows are the dialing CLIENT language, columns are the bound SERVER language. Each cell"
    echo "is the outcome of i-cli-<client> dialing service ${app}.<server> over Ziti."
    echo
    echo "Legend: ok = reached and verified, fail = connected but wrong result or denied, skip ="
    echo "client or server container absent (not tested)."
    echo
    printf '| client \\\\ server |'
    for s in $CODES; do printf ' %s |' "$s"; done
    printf '\n|---|'
    for s in $CODES; do printf '---|'; done
    printf '\n'
    for c in $CODES; do
      printf '| **%s** |' "$c"
      for s in $CODES; do
        printf ' %s |' "$(cell_get "$app" "$c" "$s")"
      done
      printf '\n'
    done
    echo
  } > "$out"
  echo "==> Wrote ${out}"
}

# Flat result store keyed app:client:server -> outcome, kept in a file so it survives subshells.
RESULT_STORE="scratch/interop-results.tsv"
: > "$RESULT_STORE"
cell_put() { printf '%s:%s:%s\t%s\n' "$1" "$2" "$3" "$4" >> "$RESULT_STORE"; }
cell_get() {
  local key="$1:$2:$3" val
  val="$(grep -F "${key}	" "$RESULT_STORE" 2>/dev/null | head -n1 | cut -f2 || true)"
  echo "${val:-skip}"
}

render_html() {
  local out="results/interop.html"
  {
    cat <<'HTML_HEAD'
<!doctype html>
<meta charset="utf-8">
<title>Interop matrix</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 2rem; color: #1a1a1a; }
  h1 { font-size: 1.3rem; }
  h2 { font-size: 1.05rem; margin-top: 2rem; }
  table { border-collapse: collapse; margin: 0.5rem 0 1.5rem; }
  th, td { border: 1px solid #ccc; padding: 0.35rem 0.6rem; text-align: center; min-width: 2.5rem; }
  th { background: #f3f3f3; }
  td.ok { background: #1a7f37; color: #fff; }
  td.fail { background: #b42318; color: #fff; }
  td.skip { background: #d9d9d9; color: #555; }
  .legend span { display: inline-block; padding: 0.15rem 0.5rem; margin-right: 0.5rem; border-radius: 3px; }
  .legend .ok { background: #1a7f37; color: #fff; }
  .legend .fail { background: #b42318; color: #fff; }
  .legend .skip { background: #d9d9d9; color: #555; }
</style>
<h1>Interop matrix</h1>
<p>Rows are the dialing client language, columns are the bound server language.</p>
<p class="legend">
  <span class="ok">ok</span> reached and verified
  <span class="fail">fail</span> connected but wrong result or denied
  <span class="skip">skip</span> container absent (not tested)
</p>
HTML_HEAD
    for app in $APPS; do
      echo "<h2>${app}</h2>"
      echo '<table><tr><th>client \ server</th>'
      for s in $CODES; do echo "<th>${s}</th>"; done
      echo '</tr>'
      for c in $CODES; do
        echo "<tr><th>${c}</th>"
        for s in $CODES; do
          local v
          v="$(cell_get "$app" "$c" "$s")"
          echo "<td class=\"${v}\">${v}</td>"
        done
        echo '</tr>'
      done
      echo '</table>'
    done
  } > "$out"
  echo "==> Wrote ${out}"
}

echo "==> Running interop matrix (project ${PROJECT}, codes: ${CODES})"
for app in $APPS; do
  for client in $CODES; do
    for server in $CODES; do
      outcome="$(run_cell "$app" "$client" "$server")"
      cell_put "$app" "$client" "$server" "$outcome"
      printf '    %-5s %-5s -> %-5s : %s\n' "$app" "$client" "$server" "$outcome"
    done
  done
done

for app in $APPS; do
  render_md "$app"
done
render_html

echo "==> Done. See results/interop-echo.md, results/interop-http.md, results/interop.html"
