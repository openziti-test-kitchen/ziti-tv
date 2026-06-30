# Addendum 03: built state (supersedes stale names in complicated.plan.md)

Captures what is actually deployed. Where this conflicts with `complicated.plan.md` section 4 (old cloud/router
names), this wins.

## Naming (actual)

- Site networks: `internet`, `vpc1`, `vpc2`, `home`, `corp`, plus `ziti` (control-plane network).
- The plan's `aws-vpc` / `azure-vnet` / `gcp-vpc` are renamed to `vpc1` / `vpc2` (and `home` / `corp`).

## Controllers

- 3-node raft cluster: `ziti-controller1` (leader), `ziti-controller2`, `ziti-controller3` (voters).
- Ports: 1280 / 1282 / 1283 on the host. ZAC at `https://localhost:<port>/zac`.
- Join is explicit `ziti agent cluster add` against the leader, scripted in `scripts/up.sh` (idempotent).

## Router roster (all enrolled OTT, online)

| Router | Site nets (besides ziti) | Tunneler | Mode | Host port |
|---|---|---|---|---|
| public-er-1 | internet, home | yes | host | 3022 |
| transit-router | internet | no | none | 3023 |
| vpc1-er | internet, vpc1 | yes | host | 3024 |
| vpc2-er | vpc1, vpc2 | yes | host | 3025 |
| corp-er | internet, corp | yes | host | 3026 |
| home-er | home | yes | host | 3027 |

- Fabric currently a FULL MESH (15 links up) because all routers share the `ziti` network and link freely over it.
- Path shaping to force `home -> internet -> vpc1 -> vpc2` is NOT done yet (per addendum_02, no guaranteed paths
  required for now). When done it will use link cost / link policies and/or splitting control vs data adjacency.

## Build order progress (against addendum_01 revised order)

- [x] 1. Skeleton repo, `.env` with `ZITI_VERSION`, (tooling container not yet added; admin ops run via the
      controller container directly for now)
- [x] 2. PKI + controllers (self-bootstrapped PKI, verified)
- [x] 3. 3-node raft cluster + ZAC on all nodes  (HAProxy front door NOT yet)
- [x] 4. Emulated site networks + per-router placement
- [x] 5. Router roster online. Path-shaping TOOLING built (`scripts/demo-path.sh`, link static-cost);
      the specific forced long-path topology is still optional (per addendum_02, not required).
- [x] 6. Services + dial + enrollment + posture: OTT/UPDB/CA enrollment, host.v1/intercept.v1, bind/dial +
      ERP/SERP, OS-posture deny AND MFA-posture deny, dial-by-name. Remaining: x509, full TOTP enroll, CA verify run live.
- [~] 7. SDK echo edges scaffolded (`sdk/`, Go+Python complete); k3d + ziti-host scaffolded (`k8s/`, not run, no k3d).
- [~] 8. Host edges documented (`docs/edges-host.md`, needs your laptop); MFA posture done; ZDEW/macOS = doc only.
- [~] 9. Observability built (`compose/observability.yml` + `observability/`), needs metrics enabled + run on PowerShell/WSL.
- [x] 10. Examples + docs + diagrams + CLI tour + a 7-module video-script curriculum.
- [~] 11. Add-ons: chaos built (`scripts/demo-chaos.sh`), backup (`scripts/backup-restore.sh`); zrok still deferred.

## Operational gotchas learned (Windows / Git-Bash + tcp daemon)

- Container stdout is swallowed in the agent sandbox. Capture by writing a file in-container then `docker cp` it
  out and reading it. (In a real terminal, `docker exec -it` shows output normally.)
- Git Bash (MSYS) rewrites leading-slash args before docker sees them. In-container absolute paths use a double
  leading slash (`//usr/local/bin/ziti`, `//tmp/x.sh`); `docker cp` host paths use relative form.
- `ziti` is at `/usr/local/bin/ziti` (not on the default `docker exec` PATH) and writes most output to stderr.
- `docker cp` over the tcp daemon occasionally flakes; `scripts/mint-router-token.sh` retries it.
- Router enrollment JWTs expire (default 180m). If the stack is paused past that before a router enrolls, re-mint
  the token AND wipe that router's volume (stale config pins the old token), then bring it back up.
- The long-lived controller container keeps `/tmp/<name>.jwt` between mints; mint now deletes it first so a stale
  token is never copied out.

## Files added since addendum_02

- `compose/routers.yml` - full 6-router roster + site networks.
- `scripts/up.sh` - cluster bring-up + join + router token mint + router start (idempotent).
- `scripts/mint-router-token.sh` - mint/stage a router enrollment JWT (retry-hardened).
- `docs/controller-internals.md` - observed PKI layout, ZAC location, front-door cert plan.
- `tokens/` - generated tokens (gitignored). `.gitignore` added.
- `compose/echo-demo.yml` - first hosted service: whoami backend + host tunneler + client tunneler.
- `scripts/provision-echo.sh` - creates the echo configs/service/identities/policies and stages enroll JWTs.

## Session 2 additions ("go ham")

Built and verified:

- **SSH over Ziti, router-hosted.** sshd in corp (dark), service `ssh` bound by the `corp-er` ROUTER identity
  (`ssh-bind` -> `@corp-er`), dialed by `echo-client` (now `#echo.clients,#ssh.clients`). Verified: SSH banner
  `SSH-2.0-OpenSSH_10.2` returned over the overlay. Files: `compose/ssh-demo.yml`, `scripts/provision-ssh.sh`.
- **One client, many services.** `echo-client` proxies `echo:8080` and `ssh:2222` from a single identity using
  role attributes.
- **Live circuit captured.** `ziti fabric list circuits` during a held connection showed
  `r/home-er -> l/<link> -> r/corp-er` for ssh. Pathing visualization works.
- **More enrollment methods.** UPDB identity `alice` (`create identity --updb alice`); 3rd-party CA `thirdparty-ca`
  generated with `ziti pki` and registered `--ottca --autoca --auth` (flags [AOE], not yet Verified). Script:
  `scripts/provision-enrollment-demos.sh`.
- **Posture-based access control (deny demo).** Service `winonly` (same backend as echo) gated by an OS posture
  check `pc-windows` (`create posture-check os ... --os Windows`) referenced from `winonly-dial` via
  `--posture-check-roles`. Verified: the Linux `echo-client` gets HTTP 200 on `echo` but **connection reset
  (denied)** on `winonly`. Script: `scripts/provision-posture.sh`.
- **Tooling + docs.** `scripts/demo-up.sh` (whole-lab bring-up), `scripts/status.sh` (overlay snapshot),
  `docs/architecture.md` (mermaid diagrams), `docs/cli-tour.md` (command reference).

Known follow-ups: CA verification + autoca end-to-end (enroll a client cert signed by `thirdparty-ca`), complete
UPDB password set + login, MFA posture (TOTP), tproxy intercept client (dial `echo.ziti` by name), path shaping,
HAProxy front door, observability.

Note: the in-container provisioning logs sometimes capture only partial output (a docker-exec capture artifact in
this sandbox); the operations themselves complete. Verify state with `scripts/status.sh` or targeted `ziti edge
list` rather than trusting log length.

## Namespacing (session 3)

Everything is grouped under a single project so it cannot collide with other docker work:

- Project: `zo` (= ziti-overkill), set via `COMPOSE_PROJECT_NAME` in `.env`.
- Containers: `zo-<service>-1` (e.g. `zo-ziti-controller1-1`, `zo-echo-client-1`).
- Volumes: `zo_<name>`.
- Networks: `zo-ctrl` (control plane, was `ziti`), `zo-internet`, `zo-vpc1`, `zo-vpc2`, `zo-home`, `zo-corp`.

The ziti advertised addresses / aliases are unchanged (`ziti-controller1`, `public-er-1`, etc.) so enrollment and
raft are unaffected by the docker-level renaming. Scripts derive the project from `COMPOSE_PROJECT_NAME` (default
`zo`), so changing the namespace later is a one-line `.env` edit plus a rebuild.

Applied by full teardown + rebuild (state is reproducible via `scripts/demo-up.sh`); stale `tokens/*` were cleared
so all identities re-mint against the fresh controller DB. Also pruned unused networks: my old bare-named ones
(`ziti/internet/vpc1/vpc2/home/corp`, `compose_default`) and three stale foreign ones from other projects
(`repro4784-accept_default`, `repro4784-fix_default`, `upgrade_default`) that had 0 containers.

Rebuild verified end-to-end under `zo`: echo HTTP 200, winonly denied (posture), ssh banner over the overlay.

## Session 4 additions (teaching track)

- Namespaced everything under project `zo` (see above).
- Minimal teaching stack: `compose/lesson-min.yml` (1 controller + 1 router, project `zomin`, network
  `zomin-net`) via `scripts/lesson-up.sh`. Verified: router enrolls + online.
- Minimal echo demo on that stack: `compose/lesson-echo.yml` + `scripts/lesson-echo.sh` (reuses
  `provision-echo.sh` with `LEADER_CTR=zomin-ziti-controller-1`). Verified: dial returns whoami over the overlay.
- Fixed two lesson-stack bugs: router `env_file` is now optional (`required: false`) so the controller can start
  before the token exists; and `lesson-up.sh` waits for a real admin login (the healthcheck passes a moment before
  auth is ready, which was 401ing the mint).
- Curriculum + shooting scripts: `docs/curriculum.md`, `lessons/README.md`, `lessons/module1..3.md` (13 episodes).
  Module 1 runs entirely on the minimal stack; Modules 2-3 use the `zo` lab.

## Session 5 additions ("all of it")

Live-verified on the `zo` lab:
- Dial-by-name (tproxy): `roamer` client dials `http://echo.ziti` by name. Needed resolver pointed at the
  tunneler, baked `dns: [127.0.0.1, 127.0.0.11]` into `compose/extras.yml`.
- HA hosting: second binder `echo-host-2` -> `echo` now has multiple terminators; `scripts/demo-chaos.sh
  kill-host` proves failover (echo stays 200 with one host down).
- MFA posture: `scripts/provision-mfa.sh` gates `mfa-echo`; an un-enrolled client is denied (verified) while
  `echo` stays open.
- Controller DB snapshot: `ziti agent controller snapshot-db` works (`scripts/backup-restore.sh`).

Built + scripted (run in a real terminal; CLI verified to exist):
- `scripts/demo-updb.sh` (UPDB password + login), `scripts/demo-revocation.sh` (delete identity = instant
  revoke), `scripts/finish-ca.sh` (guided CA verify + autoca fleet enroll), `scripts/demo-path.sh` (link
  static-cost path shaping), `scripts/demo-chaos.sh` (host/leader failover), `scripts/mint-identity.sh`.

Built, not live-verified (need PowerShell/WSL or external pieces):
- HAProxy front door: `compose/haproxy.yml` + `haproxy/haproxy.cfg` (TCP passthrough across the 3 controllers).
  Needs `learning.openziti.local` as a controller cert SAN (alt_server_certs), steps documented.
- Observability: `compose/observability.yml` + `observability/` (Prometheus + Grafana). Needs Ziti metrics
  enabled in controller config (snippet in `observability/README.md`).

Scaffolds (subagents, not compiled/run):
- `sdk/` polyglot echo (Go + Python complete; C#, Java, JS, C, Swift marked `SCAFFOLD: verify API`).
- `k8s/` dark service with no ingress (k3d + helm; k3d/helm not installed here).

Docs/lessons: `lessons/module4..6.md`, `k8s/LESSON.md` (module 7), `docs/edges-host.md`. `demo-up.sh` now also
provisions MFA + brings up `roamer` and `echo-host-2`.

Honest gaps for later: full TOTP enrollment end-to-end, CA verification executed live, HAProxy alt-cert wiring
executed, observability metrics flowing, SDK non-Go compiled, k8s run on a real k3d.

## Session 6 additions (lifecycle scripts)

- `scripts/stop.sh` / `scripts/start.sh` / `scripts/down.sh` (+ `scripts/lib-compose.sh` for the shared file
  list). stop/start preserve all state; `down` removes containers+networks; `down -v` wipes volumes + tokens.
- Verified a full stop -> start cycle restores the lab (echo 200, winonly denied, ssh banner).
- Learning: on a cold `start`, the controller is ready before hosts/clients reconnect, and they do NOT self-heal
  their bindings. `start.sh` bounces the service HOST router (corp-er, router-hosted ssh) and the tunneler
  containers (echo-host, echo-host-2, echo-client, roamer) after the leader is healthy so terminators and proxy
  listeners re-bind. Router-hosted services specifically need their hosting router bounced (verified: ssh
  terminator only reappeared after `docker restart` of corp-er).

## Session 7 additions (per-stage / pick-up)

- `scripts/stage.sh module-N` brings the lab to exactly the state Module N needs and prints that module's first command.
  module 1 -> minimal `zomin` stack; module 2-module 6 -> the one cumulative `zo` lab (idempotent + additive, so any episode's
  commands work regardless of entry point); module 7 -> k8s. It stops the other stack first (shared host ports) and
  resumes-vs-rebuilds automatically. Each `lessons/moduleN.md` now starts with a "Stage setup" line.
- This is how learners pick up mid-series: `down.sh -v` for a clean slate, then `stage.sh module-N`.

## Session 8 additions (polyglot interop matrix)

Built the full interop matrix (per docs/interop-matrix.md) via parallel subagents, then integrated:
- 7 SDKs under `sdk/<lang>/` each with echo + http, server + client, a Dockerfile, README. Six Linux images build
  (go, py, js, cs, java, c); Swift is Apple-only by design (macOS host edge).
- Ziti model + harness: `scripts/provision-interop.sh` (14 services, 14 identities, dial + bind policies, enroll),
  `compose/interop.yml` (server containers; clients are docker-run one-shots), `scripts/interop-matrix.sh`
  (renders results/interop-*.md + interop.html heatmaps).
- Layer scripts: `scripts/provision-interop-posture.sh`, `-authpolicy.sh`, `-health.sh`, `-linkgroups.sh` +
  `scripts/INTEROP-LAYERS.md`. Video scripts: `lessons/interop.md` (interop.a-f).
- Reconciled two integration bugs from the parallel build: compose client containers used `sleep` against
  dispatching entrypoints (removed; clients are one-shot docker run) and the harness targeted bare service names
  instead of `zo-i-<app>-<server>-1` (fixed).

Live smoke (results/SMOKE.md): go/py/js/java/c interoperate both directions (a verified 5x5 green block). C's
cosmetic non-zero-exit bug was fixed by its subagent and verified live (exit 0, single `RESULT ok echo c->go
28ms`, the SDK fired a second ZITI_DISABLED event on shutdown that overwrote success). C# (cs) is PARKED: a long
fix attempt on the OpenZiti.NET native identity-load did not converge; the image builds and the code follows the
contract but live dialing fails (`configuration-not-found`). Decision (with the user): skip cs as a blocker, it is
a documented known gap. Swift is the macOS-only host edge. Sandbox caveats (bind-mount mangling, swallowed stdout)
meant the smoke used create + docker cp identity + start judged by exit code; the user's normal Docker shell runs
compose + the harness directly.

## Session 9 additions (custom pathing / link groups module)

A dedicated learning module for controlling the data path:
- `scripts/provision-pathing.sh` - service `deep`, hosted ONLY by the vpc2-er router (one terminator deep in
  vpc2), so a home client's dial must reach vpc2, a controlled long-path target. Verified: `deep` has one
  terminator on vpc2-er and roamer dials `deep.ziti` -> 200.
- `scripts/demo-longpath.sh` - links/circuits/force/reset/hold. `force` makes every non-chain link cost 9999 so
  the cheapest path becomes home-er -> public-er-1 -> vpc1-er -> vpc2-er. Steering lever verified live: setting a
  link `--static-cost 1000` changed FULL COST to 1004 (so smart routing reroutes); reset to 1.
- `scripts/provision-linkgroups.sh` - REAL router link groups (`link.dialers/listeners.groups`) via config edit +
  restart, with backup/revert. Honest caveat in-script: the router may regen config on boot unless
  ZITI_BOOTSTRAP_CONFIG=false. Not live-run (config surgery + restart).
- `lessons/pathing.md` (pathing.a-f), wired into `stage.sh pathing`, lessons/README, overview, backlog.

Mechanism (cost change + reroute, single-terminator target) verified live; the forced multi-hop circuit capture
and the link-group partition are run in a normal terminal (the sandbox swallows held-circuit output).

## Echo service object map (reference)

- configs: `echo.host.v1` (host.v1 -> echo-backend:80), `echo.intercept.v1` (intercept.v1 -> echo.ziti:80)
- service: `echo` (binds both configs)
- identities: `echo-host` (#echo.servers), `echo-client` (#echo.clients)
- policies: `echo-bind` (Bind #echo.servers @echo), `echo-dial` (Dial #echo.clients @echo),
  `erp-all` (#all -> #all), `serp-all` (#all -> #all)
- terminators: created on the routers the host SDK connects through (seen on vpc1-er/corp-er/home-er)
- client used `proxy` mode (:8080) for the first dial; tproxy/intercept (echo.ziti) is the next variant.
