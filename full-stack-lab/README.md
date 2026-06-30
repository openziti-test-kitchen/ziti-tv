# Full-stack OpenZiti lab

A comprehensive, deliberately maximal OpenZiti deployment for learning: HA controller cluster, many routers across
emulated clouds, Kubernetes, every enrollment method, multi-OS edges, a polyglot SDK interop matrix, custom
pathing, and a large catalog of examples. See `complicated.plan.md` and the `addendum_*.md` files for the full
plan and decisions.

(The docker compose project is namespaced `zo` internally. That is just a short, collision-proof prefix for
containers/volumes/networks, not the lab's name.)

This README tracks what actually works today. It grows as pieces land.

## Status

Working now:

- 3-node HA (raft) controller cluster (`ziti-controller1/2/3`), one leader, two voters.
- Admin CLI login.
- Full router roster, all OTT-enrolled and online, fully meshed (15 fabric links up):
  - `public-er-1` (internet edge, tunneler host)
  - `transit-router` (internet, transit-only, no tunneler)
  - `vpc1-er` (vpc1 edge, tunneler host)
  - `vpc2-er` (vpc2 edge, tunneler host, will host services)
  - `corp-er` (corp edge, tunneler host)
  - `home-er` (home edge)
- Emulated site networks: `internet`, `vpc1`, `vpc2`, `home`, `corp` (plus the `ziti` control network).
- One-command, idempotent bring-up via `scripts/up.sh`.
- Two working services over the overlay (both dialed from one client identity, role-attribute driven):
  - `echo` (HTTP whoami in vpc2), hosted by a dedicated `ziti-tunnel` identity. Dial: `curl localhost:8080`.
  - `ssh` (sshd in corp), hosted by the **corp-er router itself** (router-hosted pattern). Dial: port 2222.
- Live circuit visualization (`ziti fabric list circuits` shows the path, e.g. `home-er -> link -> corp-er`).
- Multiple enrollment methods: OTT (routers + echo/ssh identities), UPDB (`alice`), and a 3rd-party CA
  (`thirdparty-ca`) registered for ottca + autoca, generated with `ziti pki`.
- Helper scripts: `scripts/demo-up.sh` (whole lab), `scripts/status.sh` (overlay snapshot).

Also built (see `addendum_03.md` for verification status):
- Dial-by-name (`roamer` tproxy client dials `http://echo.ziti`), MFA-gated service (deny without MFA),
  HA hosting + host/leader failover (`scripts/demo-chaos.sh`), path shaping (`scripts/demo-path.sh`),
  UPDB login, revocation, CA verify/auto-enroll (guided), DB snapshot (`scripts/backup-restore.sh`).
- Scaffolded: `sdk/` (polyglot echo, Go+Python complete), `k8s/` (dark service, needs k3d/helm),
  HAProxy front door (`compose/haproxy.yml`), observability (`compose/observability.yml`), host edges
  (`docs/edges-host.md`).

The whole lab + advanced demos: `bash scripts/demo-up.sh`. Teaching path: start with
**`docs/overview.md`** (what you'll do/learn/see across the 7 modules), then the per-video scripts in `lessons/`.
Launch any module with `bash scripts/stage.sh module-N`.

Docs: `docs/overview.md` (the learning journey), `docs/architecture.md` (diagrams), `docs/cli-tour.md` (every
command), `docs/controller-internals.md`, `docs/curriculum.md`, `docs/edges-host.md`,
`docs/interop-matrix.md` (polyglot SDK interop matrix + posture/auth/health/pathing layers).

Outstanding work is tracked in `backlog.md` (C# SDK interop is parked there with a repro and next steps).

## Echo demo (first hosted service + dial)

```
bash scripts/provision-echo.sh                                   # configs, service, identities, policies
docker compose -p zo -f compose/echo-demo.yml up -d              # backend + host tunneler + client tunneler
docker exec zo-echo-client-1 curl -s http://localhost:8080       # dial it -> whoami response
```

What it proves: `echo-backend` (traefik/whoami) sits in `vpc2` with **no published port** (dark). It is reachable
only over the Ziti overlay: `echo-client` (proxy mode, :8080) -> edge router -> fabric -> `echo-host` ->
`echo-backend:80`. Identities `echo-host` (#echo.servers, Bind) and `echo-client` (#echo.clients, Dial) gate access
via service policies.

## Prerequisites

- Docker (Engine 29+ tested) with Compose v2.
- Bash. On Windows use Git Bash; the scripts set `MSYS_NO_PATHCONV` so they behave.
- Pinned versions live in `.env` (default `ZITI_VERSION=2.0.0`). Copy `.env.example` to `.env` to customize.

## Quickstart

```
cp .env.example .env        # first time only
bash scripts/up.sh
```

`up.sh` will:

1. start the controller cluster and wait for node 1 to be healthy,
2. join nodes 2 and 3 into the raft cluster (idempotent),
3. mint the `public-er-1` enrollment token (only if not already staged),
4. start the router(s),
5. print the cluster members and edge-router list.

## Accessing things

- ZAC (admin console), per controller node (no separate container, it ships in the image):
  - node 1: `https://localhost:1280/zac`
  - node 2: `https://localhost:1282/zac`
  - node 3: `https://localhost:1283/zac`
  - Login with the controller admin (`admin` / value of `ZITI_PWD`, default `admin`).
- Controller client/management API: `localhost:1280` (and `:1282`, `:1283`).
- Router `public-er-1`: `localhost:3022`.

## Running ziti CLI commands

`ziti` lives inside the controller container at `/usr/local/bin/ziti`. From your own terminal:

```
docker exec -it zo-ziti-controller1-1 ziti agent cluster list
docker exec -it zo-ziti-controller1-1 ziti edge login localhost:1280 -u admin -p admin -y
docker exec -it zo-ziti-controller1-1 ziti edge list edge-routers
```

The `-it` flags matter for interactive output in a real terminal.

## Provisioning more routers

```
scripts/mint-router-token.sh <router-name> [extra ziti create flags...]
# then add the service to compose/routers.yml and bring it up
```

## Lifecycle (start / stop / teardown)

```
bash scripts/demo-up.sh     # build/bring up the whole lab (idempotent)
bash scripts/stop.sh        # stop everything, KEEP all state (fast pause)
bash scripts/start.sh       # resume; re-binds hosts/clients against the ready control plane
bash scripts/down.sh        # remove containers + networks, keep volumes
bash scripts/down.sh -v     # full clean slate: also wipe volumes + staged tokens
bash scripts/status.sh      # snapshot of cluster, routers, links, services, circuits
```

Notes:
- `stop`/`start` preserve everything (PKI, identities, services, enrollments). On a cold
  `start` the controller comes up first, then `start.sh` bounces the service hosts and tunnelers
  so their listeners/terminators re-bind, give clients ~15s to settle.
- After `down -v` rebuild from scratch with `scripts/demo-up.sh` (tokens are re-minted).

## Layout

- `.env`, `.env.example` - versions, names, ports.
- `compose/controllers.yml` - the 3-node HA cluster.
- `compose/routers.yml` - routers (currently `public-er-1`).
- `scripts/up.sh` - one-command bring-up + cluster join + router provisioning.
- `scripts/mint-router-token.sh` - mint/stage a router enrollment JWT.
- `docs/controller-internals.md` - observed PKI layout, ZAC location, front-door cert plan.
- `tokens/` - generated enrollment tokens (gitignore-worthy).
- `scratch/` - throwaway working files.

## Windows / Git Bash gotchas (learned the hard way)

- Git Bash rewrites leading-slash arguments (e.g. `/usr/local/bin/ziti`) into Windows paths before Docker sees
  them. The scripts disable this with `MSYS_NO_PATHCONV=1`. If running ad-hoc, prefix in-container script paths
  with a double slash (`sh //tmp/x.sh`).
- `ziti` is not on the default `docker exec` PATH; call it by full path `/usr/local/bin/ziti`.
- `ziti` writes most output to stderr; capture both streams when scripting.
