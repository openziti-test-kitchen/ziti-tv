# OpenZiti, end to end: the learning journey

This is the map of the whole series: what you'll **do**, what you'll **learn**, and what you'll **see** on
screen, module by module. It is the learner-facing companion to the shooting scripts in `lessons/` and the planning
notes in `docs/curriculum.md`.

## The one-sentence pitch

OpenZiti is a zero-trust overlay network: your services have **no open ports** (they're "dark") and are reachable
only by cryptographic **identities** you explicitly allow. This series takes you from "what even is that" to a
deliberately over-engineered multi-cloud deployment.

## Before you start

- You need Docker. Everything runs in containers; nothing touches your machine except published ports.
- Two stacks: a tiny one for Module 1 (one controller + one router) and the full "overkill" lab for Modules 2-6.
  Kubernetes (Module 7) runs its own cluster.
- Start any module with one command: `bash scripts/stage.sh module-N` (it sets up exactly what that module needs
  and prints the first thing to run). `bash scripts/stage.sh list` shows the map; `... down` tears it all down.
- You do not have to go in order. Modules 2-6 share one cumulative lab, so you can jump straight to any of them.

## The journey

### Module 1 - What even is it
- **Do:** stand up the smallest possible overlay (1 controller + 1 router), then host a web app and reach it.
- **Learn:** the five nouns (controller, router, identity, service, policy); what "dark service" and
  "zero trust" actually mean; OTT enrollment; how config + policy grant access.
- **See:** a `whoami` web server with **no published port** that you still load over the overlay, the "aha".

### Module 2 - How it actually works
- **Do:** add a second router; watch a live circuit; host SSH two different ways; get denied by a posture check.
- **Learn:** the fabric (routers + links + circuits), smart routing, tunneler-hosted vs router-hosted services,
  posture checks, the full enrollment menu.
- **See:** `ziti fabric list circuits` printing the actual path your bytes took; an SSH banner over the overlay;
  the same client allowed to one service and **denied** another by device posture.

### Module 3 - Scaling it up (the overkill)
- **Do:** run a 3-node HA controller cluster; kill the leader; route across emulated "clouds"; bring up everything.
- **Learn:** raft clustering and control-plane HA; multi-site topology; how the data plane survives a controller loss.
- **See:** leadership re-electing after you kill a node while traffic keeps flowing; a cross-site circuit whose
  path crosses home -> internet -> vpc -> vpc, with every backend still dark.

### Module 4 - Real edges
- **Do:** dial a service by name (`http://echo.ziti`); enroll your real laptop; run an app that speaks Ziti with
  no tunneler at all.
- **Learn:** transparent name-based access (intercepts + DNS), Desktop Edge / ziti-edge-tunnel on a real OS, and
  app-embedded SDKs.
- **See:** `curl http://echo.ziti` working with nothing but Ziti; the same dark service reached from your own
  machine; an SDK echo app with zero listening ports.

### Module 5 - Advanced auth
- **Do:** log in with a username/password identity; get denied without MFA; register your own CA; revoke an identity.
- **Learn:** that identity is the foundation (introduced back in Module 1) and these are the advanced ways to
  prove it: UPDB, MFA/TOTP, bring-your-own-CA fleets, instant revocation.
- **See:** an MFA-gated service refusing a client that hasn't enrolled a second factor; an identity's access
  vanishing the instant it's revoked.

### Module 6 - Production concerns
- **Do:** wire up Prometheus + Grafana; kill hosts and the leader to prove resilience; shape traffic with link
  cost; snapshot the controller database.
- **Learn:** observability (circuits, links, latency, sessions), service-level + control-plane HA, deliberate
  routing, and backup/restore.
- **See:** dashboards of the overlay; a service staying up at HTTP 200 while you kill one of its hosts; a circuit
  rerouting after you raise a link's cost.

### Module 7 - Kubernetes
- **Do:** run a k3d cluster, put a router in a pod, and host a k8s Service over Ziti.
- **Learn:** how Ziti reaches into Kubernetes without an Ingress or NodePort.
- **See:** a `whoami` pod with a ClusterIP-only Service, no public exposure, reachable from the rest of the lab.

## What you'll be able to do after

Read any OpenZiti doc or demo without getting lost, stand up a controller + routers, publish a dark service,
enroll clients several ways, gate access by identity and posture, run it in HA across sites and into Kubernetes,
and embed it directly in an app. From here: zrok (public sharing), production hardening, and your own services.

## Where everything lives

- `lessons/module1.md` ... `module6.md` + `k8s/LESSON.md` - the per-video shooting scripts (each `module-N.x`).
- `lessons/README.md` - index + per-video verification status (live-verified vs scripted vs scaffold).
- `docs/curriculum.md` - the design rationale, what to cut/trim, production notes.
- `lessons/concepts.md` - the "why OpenZiti is different" explainer series: zero-trust principles, end-to-end
  encryption, the three planes, sessions & posture, the attachment spectrum, SPIFFE/PKI, terminators, typed
  configs, adaptive routing. Mostly conceptual with short read-only demos.
- `lessons/pathing.md` - custom router paths and link groups: read circuits, steer with link cost, force the
  home -> internet -> vpc1 -> vpc2 route, reroute on failure, partition the fabric with link groups. Stage:
  `bash scripts/stage.sh pathing`.
- `docs/interop-matrix.md` + `lessons/interop.md` - the polyglot interop matrix (every SDK x every SDK, echo +
  http) layered with posture, auth policies, health checks, and link-group pathing. BUILT: `sdk/<lang>/`,
  `compose/interop.yml`, `scripts/provision-interop*.sh`, `scripts/interop-matrix.sh`. Smoke-verified go/py/js/java
  + C interoperate live (`results/SMOKE.md`).
- `docs/architecture.md` - diagrams of the running topology.
- `docs/cli-tour.md` - every `ziti` command used, grouped by area.
- `scripts/` - one-command setup per module (`stage.sh`), lifecycle (`stop`/`start`/`down`), and each demo.
