# Addendum 01: locked decisions

## Decisions

### D1. Single host default, blocks must be relocatable (A1, A2)

- Default: one host runs everything.
- Any block (controller node, router, a whole "cloud") must move to another host with minimal edits.
- No hard-coded container IPs. Peers addressed by advertised host:port from `.env`.
- Each movable block: own compose overlay + own `.env` fragment.
- Router links use advertised addresses so a moved router re-forms links without topology edits.

### D2. Version from `.env`, default latest release (A3)

- `ZITI_VERSION` in `.env`, default resolves to latest GitHub release.
- Controller, router, quickstart tooling, ZAC images all key off it.

### D3. Clear pathing is the centerpiece (A4)

- Target flow: `home -> internet -> vpc1 -> vpc2`, home user dials a service in vpc2.
- Redundant legs at each hop so paths fail over.
- Show the actual circuit per dial: `ziti fabric list circuits`, terminators, link costs, rendered path diagram.
- Force a specific path via link cost / terminator weighting.
- Mesh must guarantee 2+ distinct end-to-end paths for the target flow.

### D4. Router runtime variety (A5)

- Every enrollment method.
- Routers with tunneler and without (pure fabric/transit).
- `run-host` hosting.
- Shared netns: `--network container:<name>` (router + app share a netns), plus other container network modes.
- Documented as a router-shape matrix.

### D5. macOS works, LAN-dev reachability (A6, A7)

- macOS edge must actually work. No screenshots needed.
- Controllers and routers reachable from every LAN machine, including controller not publicly accessible (lan dev).
- Host-port publishing is yours to handle.

### D6. Kubernetes = k3d (A8)

- k3d + ziti-host. Webhook/sidecar injection documented as a bonus.

### D7. Many examples (A9)

- A large catalog of small, copy-pasteable examples: SSH, web server, multi-hop path, database, dark-service proof,
  MFA-gated service, k8s app, more.

### D8. ZAC on all controllers, HAProxy front door (A10)

- ZAC on all three controller nodes.
- HAProxy fronts the deployment under one hostname.
- To iterate: route the routers through the same front door (one entry for client API, ZAC, router ingress).

### D9. Dedicated tooling container (A11)

- Tooling/jump container based on `openziti/quickstart:latest`.
- All CLI tours and admin scripts run inside it.
- Host-side PowerShell wrappers just exec into it.

### D10. Extras (A12)

- BrowZer: dropped.
- zrok: deferred.
- SDK: one echo client/server, identical across languages, Go first.
- Chaos monkey: deferred, opt-in, dormant by default. Kills routers, slows them, degrades links.

## Build order (supersedes plan section 13 on conflict)

1. Skeleton repo, `.env` with `ZITI_VERSION`, tooling container from `openziti/quickstart`.
2. PKI + single controller, verify from tooling container.
3. 3-node raft cluster + HAProxy front door + ZAC on all three nodes.
4. Emulated networks (internet, vpc1, vpc2, home, corp), carve-and-move overlays per block.
5. Router mesh for clear pathing: 2+ paths for `home -> internet -> vpc1 -> vpc2`, plus router-shape matrix.
6. Enrollment methods + identities + policies + first service. First dial with circuit shown.
7. Linux + SDK echo edges, then k3d + ziti-host. k8s dial.
8. macOS edge over LAN + Windows ZDEW + MFA posture. LAN-dev reachability.
9. Observability (Prom/Grafana) + circuit/path visualization.
10. Examples + docs + diagrams + CLI tour.
11. Add-ons: chaos monkey, zrok.

## Open questions

### Q13. Front-door hostname

HAProxy front-end hostname. What string?

**Answer:**
use: learning.openziti.local

### Q14. SDK languages for the echo app

Go plus which others?

**Answer:**
all the fucking languages you dolt. c, csharp, python, java, go, javascript, swift

### Q15. Number of guaranteed end-to-end paths

Two or three independent `home -> internet -> vpc1 -> vpc2` paths?

**Answer:**
none for now

### Q16. LAN reachability

Are all your machines (Windows, Mac, Linux) on one flat LAN subnet that can reach a published port on the Docker
host directly, or is there a router/VLAN in between?

**Answer:**
assume yes