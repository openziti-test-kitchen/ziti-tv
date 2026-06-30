# Interop matrix: layered zero-trust feature provisioning

These four scripts sit ON TOP of the bare interop matrix (see `docs/interop-matrix.md` and
`scripts/provision-interop.sh`). The bare matrix is every SDK dialing every SDK over Ziti, rendered as two
7x7 grids. Each layer below changes that grid in a way you can see: cells flip grey (denied), rows go
auth-denied, terminators self-heal, and circuits move onto different paths.

All four follow the exact repo convention from `scripts/provision-posture.sh`:

- full lab is compose project `zo`, controller container `zo-ziti-controller1-1`
- `ziti` lives at `/usr/local/bin/ziti` and is called with a DOUBLE leading slash (`//usr/local/bin/ziti`) so
  Git Bash does not mangle the path
- provisioning runs as an in-container heredoc script: `tr -d '\r'` then `docker cp` in, `docker exec sh
  //tmp/x.sh`, then `docker cp` the log out (docker exec stdout is swallowed in the sandbox, and `ziti` writes
  to stderr)
- every script is idempotent (delete-then-create) and uses the `dcp` retry helper

Run nothing blindly. Each script prints what to observe and writes its log to `scratch/`.

## Order to run them

Run the bare matrix first, confirm all green, then layer in this order. Each layer is independently demoable
and each is reversible.

1. `scripts/provision-interop.sh` (prerequisite, already in the repo): builds the 14 services, the server and
   client identities, and the `dial-interop` + `bind-<code>` policies. Render the grid: all cells green.
2. `scripts/provision-interop-posture.sh` (Layer 1, posture).
3. `scripts/provision-interop-authpolicy.sh` (Layer 2, auth policies).
4. `scripts/provision-interop-health.sh` (Layer 3, health checks).
5. `scripts/provision-interop-linkgroups.sh` (Layer 4, pathing).

Layers 1 and 2 are independent of each other (posture is the room key, auth policy is the front door) and can
be shown in either order. Layers 3 and 4 are about routing and are best shown after 1 and 2 so the audience
already understands the grid.

## What to look for in the matrix after each layer

### Layer 1: posture (`provision-interop-posture.sh`)

Splits client identities into `#clients.trusted` and `#clients.posture`, re-points the original `dial-interop`
at the trusted camp, and adds `dial-interop-posture` which requires ALL `#posture.matrix` checks to pass. It
creates one posture check of EACH type: `os` (Linux), `process` (a required binary), `mac` (allowlist),
`domain` (Windows domain).

Look for: the posture client ROWS (default `py` and `js`) go GREY across the whole grid, because the Linux lab
containers cannot satisfy the mac/domain/Windows-process checks. Trusted rows stay green. Flip a check so it
passes (for example add the device MAC to the allowlist) and re-run the matrix to watch that row come back.
Posture is evaluated per-dial, so the change shows up on the next dial.

### Layer 2: auth policies (`provision-interop-authpolicy.sh`)

Creates `ap-default` (cert only), `ap-mfa` (cert + required TOTP), `ap-updb` (cert + password allowed), and
assigns `ap-mfa` to one client (default `swift`) and `ap-updb` to another (default `cs`).

Look for: the `ap-mfa` client (default `icli-swift`) shows a whole AUTH-DENIED row, a state distinct from
posture-grey, because it cannot obtain an API session at all until TOTP is enrolled. This affects every
service, even ones it is otherwise fully authorized to dial. The `ap-updb` client still works over cert
(password is merely permitted). Restore the row by enrolling TOTP on that client or moving it back to
`ap-default`.

### Layer 3: health checks (`provision-interop-health.sh`)

Honest split. FULLY SCRIPTED: a tunneler-hosted variant `healthz.<code>` (default `go`) with a `host.v1`
config carrying an `httpCheck` against `/healthz` plus a `portCheck`. DOCUMENTED ONLY: the SDK
terminator-health path for the native interop servers, because there is no `ziti edge` CLI to attach a health
check to an already-bound SDK terminator.

Look for: `ziti edge list terminators` shows how many terminators each service has. Bring up a sibling server
(`isrv-<code>-b`) and a service goes from one to two terminators (HA). For the scripted `healthz.<code>`
variant, break `/healthz` and watch its terminator leave the pool, then return when it recovers. With a healthy
twin present the grid stays green during the failover, then a column goes red only when no healthy terminator
remains.

### Layer 4: pathing (`provision-interop-linkgroups.sh`)

Honest split. FULLY SCRIPTED: cost-based steering via `ziti fabric update link <id> --static-cost` with
before/after `ziti fabric list circuits`. DOCUMENTED ONLY: the real router link-group config keys, which live
in each router yml and require a router restart this script will not perform.

Look for: capture `ziti fabric list circuits` for an active cell, raise the cost on the link that path uses,
re-dial the cell to force a fresh circuit, then compare. The circuit moves to the alternate path. Reset with
`RESTORE=1 ./scripts/provision-interop-linkgroups.sh`. Link groups are the structural, permanent version of the
same idea.

## Fully scripted vs documented-only (be honest)

| Layer | Script | Fully scripted | Documented only |
|---|---|---|---|
| 1 posture | `provision-interop-posture.sh` | All of it: the trusted/posture split, the second dial policy, all four posture-check types | nothing |
| 2 auth policy | `provision-interop-authpolicy.sh` | All of it: the three auth policies and both identity assignments | TOTP enrollment itself is a client-side flow (`ziti edge enroll-mfa` + verify), not done here |
| 3 health | `provision-interop-health.sh` | The tunneler-hosted `healthz.<code>` variant with `host.v1` httpCheck + portCheck, and `ziti edge list terminators` | the SECOND-terminator HA (a compose/container change to add `isrv-<code>-b`) and SDK terminator-health reporting (an SDK-side hosting option, no CLI) |
| 4 pathing | `provision-interop-linkgroups.sh` | Cost-based steering with `--static-cost` and before/after `ziti fabric list circuits` | the true router link-group config keys (`link.listeners[].groups` / `link.dialers[].groups`), which need router yml edits + restart |

## Flags and config keys, with confidence

Confirmed against the openziti/ziti source (the `ziti/cmd/edge` and `ziti/cmd/fabric` command files) and the
OpenZiti router config reference:

- auth-policy: `--primary-cert-allowed`, `--primary-updb-allowed`, `--secondary-req-totp` (verified in
  `ziti/cmd/edge/create_authpolicy.go`)
- posture checks: `os <name> --os`, `process <name> <os> <absolutePath>`, `mac <name> -m`,
  `domain <name> -d` (verified in `ziti/cmd/edge/create_posture_check.go`)
- fabric link steering: `ziti fabric update link <id> --static-cost <uint32>` and `--down <bool>` (verified in
  `ziti/cmd/fabric/update_link.go`); `ziti fabric list links|circuits|terminators`
- link groups (production, documented not scripted): `link.listeners[].groups` and `link.dialers[].groups` in
  router yml, absent membership defaults to the `default` group, and a link only forms when a dialer and
  listener share at least one group (verified in the router xlink_transport dialer/listener config and the
  router configuration reference)

Lower confidence, flagged in the script comments:

- the `host.v1` `httpChecks` / `portChecks` JSON shape in `provision-interop-health.sh` follows the documented
  host.v1 health-check schema, but the exact action wording was not re-verified field-by-field against the
  pinned controller version. Confirm against the host.v1 config schema for the lab's controller before relying
  on it in a recorded demo.
