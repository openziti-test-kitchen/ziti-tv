# Backlog

Tracked, not-yet-done work. The lab and the 7-module series plus the polyglot interop matrix (5 languages live)
are built and verified; this is what is left.

## Next up (top 3, highest payoff-to-effort, all mostly built)

1. Lock the interop green grid (run it for real, commit the artifact). The "any language talks to any language"
   claim is smoke-proven 5x5 but never rendered/committed, and only echo was verified live (not http).
   - First step: `bash scripts/provision-interop.sh && docker compose -p zo -f compose/interop.yml up -d &&
     bash scripts/interop-matrix.sh`, then open `results/interop.html` and commit it.
   - Confirm the http matrix too (currently only echo is verified live).

2. Observability, taken live (Prometheus + Grafana + one dashboard). Compose + configs exist; needs the Ziti
   controller metrics handler enabled and a real run. "See the overlay" (circuits, links, latency, sessions) is
   one of the most compelling things to put on screen.
   - First step: enable the controller `metrics`/`prometheus` handler (snippet in `observability/README.md`),
     then `docker compose -p zo -f compose/controllers.yml -f compose/observability.yml up -d prometheus grafana`,
     then build one Grafana panel set (active circuits, link latency, edge sessions, raft leader).

3. HAProxy front door wired with the real cert (`learning.openziti.local`). Built but never brought up, and it is
   the missing piece for the multi-machine / LAN story and a clean HA episode.
   - First step: issue a `learning.openziti.local` server cert from the shared controller CA, add it as
     `alt_server_certs` on each controller web listener (plan in `docs/controller-internals.md`), then
     `docker compose -p zo -f compose/controllers.yml -f compose/haproxy.yml up -d haproxy` and add
     `127.0.0.1 learning.openziti.local` to the host hosts file.
   - Watch out: controllers regenerate config on boot unless `ZITI_BOOTSTRAP_CONFIG=false`, so the alt-cert edit
     must survive a restart.

Bigger fish after those: Module 7 / Kubernetes run on a real k3d + helm (a whole scaffolded module never
executed), and CA verify + autoca end-to-end (completes the enrollment story). C# stays parked.

## Parked

### C# SDK interop (cs) - PARKED
- Symptom: the `zo-sdk-cs` image builds and the program follows the contract, but at runtime the OpenZiti.NET
  native context fails to load the enrolled identity JSON: `RESULT fail echo cs->go configuration-not-found`
  (client) and the cs server never serves. Both echo and http, both roles.
- Effort so far: a long fix attempt (~3h) did not converge. Not a blocker, the matrix is proven on go, py, js,
  java, c (5x5 green) plus the Swift macOS host edge.
- Where it lives: `sdk/csharp/` (builds), referenced in `compose/interop.yml`, `scripts/interop-matrix.sh`,
  `results/SMOKE.md`, `lessons/interop.md`.
- Next approach to try (fresh, not via the looping agent): confirm exactly what OpenZiti.NET expects for identity
  load on linux-x64, the enrolled JSON path/format, whether `new ZitiContext(path)` needs the native ziti config
  init first, whether `LD_LIBRARY_PATH`/native `.so` is actually found at runtime, and whether the identity must
  be a keystore/ID file rather than the raw enrolled JSON the other SDKs accept. Validate with one cs client
  dialing a go server before touching anything else.

## Interop matrix follow-ups

- Run the full grid in a normal Docker shell and commit `results/interop-echo.md` / `interop-http.md` /
  `interop.html` (the harness renders them; only hand-run smoke exists so far).
- http matrix: only echo was smoke-verified live, confirm the http 5x5 too.
- Swift: build/run the macOS path on a real Mac and add it as a host-edge row (it cannot be a Linux container).
- Health-check failover (interop.e) and link-group pathing (interop.f) are partly scripted, partly documented
  (`scripts/INTEROP-LAYERS.md`), turn the documented parts into real scripted demos:
  - second server per service (HA terminators) wired into `compose/interop.yml`.
  - real router link `groups` config is now implemented in `scripts/provision-linkgroups.sh` (edits
    `link.dialers/listeners.groups` + restart); verify it sticks across a router reboot in your env
    (may need ZITI_BOOTSTRAP_CONFIG=false so the router keeps the edited config).

## Features built-but-not-run-live (make them verified)

- HAProxy front door: `compose/haproxy.yml` + `haproxy/haproxy.cfg` exist, never brought up; needs the
  `learning.openziti.local` alt-cert (`alt_server_certs`) step executed on the controllers.
- Observability: `compose/observability.yml` + `observability/` exist; needs Ziti controller metrics enabled and
  a real run (Prometheus targets + a Grafana dashboard).
- CA verify + autoca end-to-end (`scripts/finish-ca.sh` is guided), run the verification + a fleet auto-enroll.
- Full MFA/TOTP enroll-then-succeed (only the deny is verified).
- UPDB login, revocation, path-shaping reroute, leader-failover: scripts exist, run them live to confirm.

## OpenZiti features not yet touched

- x509 third-party client-cert auth; OIDC/SSO via `ext-jwt-signer`; zrok (public sharing).
- Posture types beyond OS + MFA: process, process-multi, MAC, domain (created in scripts, not demoed live).
- Terminator strategies (weighted/ha/random), service encryption toggle, identity app-data/external-id.
- Kubernetes (`k8s/`) run on a real k3d + helm (scaffolded, never executed here).
- Live host edges: Windows ZDEW and macOS Desktop Edge (documented in `docs/edges-host.md`, needs your machines).

## Done since first backlog

- Custom router paths / link groups module (`lessons/pathing.md`): `scripts/provision-pathing.sh` (the `deep`
  single-terminator long-path target), `scripts/demo-longpath.sh` (cost steering + forced
  home->internet->vpc1->vpc2 route + reroute), `scripts/provision-linkgroups.sh` (real router link groups via
  config + restart, with revert). Steering lever verified live (link cost change takes effect and reroutes); the
  forced multi-hop circuit and link-group partition are run in a normal terminal. Stage: `stage.sh pathing`.

## Original ambitions still open (addendum_01/02)

- The forced long path is now demonstrable on demand (above). Engineering it as the PERMANENT default topology
  (vs on-demand via demo-longpath.sh) is still optional.
- Carve-and-move a block to a second physical host (the portability showcase).
- Router-shape matrix (D4): shared-netns `--network container:`, run-host, tunneler on/off across modes.
- Chaos as a real module (degrade links, slow to a crawl), not just kill/restore.

## Polish

- Render `docs/architecture.md` mermaid diagrams to committed images.
- A single smoke-test that validates the whole lab in one shot.
- Decide whether to rename the generic word "episode" to "video" across the lessons (identifiers are already
  `module-N.<letter>`).

## OpenZiti concept coverage gaps

We have a lot of FEATURES demoed, but several core CONCEPTS are under-taught, the "why it is different" ideas a
viewer needs to actually understand zero trust. Ranked by how central they are.

1. End-to-end encryption (the big one). Ziti traffic is encrypted identity-to-identity, the routers and the fabric
   CANNOT read it; it is not TLS-terminated at a router. `encryptionRequired` is on by default and we never
   explain or show it. This is the headline zero-trust differentiator. Demo idea: capture traffic on a router and
   show it is opaque, contrast with a normal TLS proxy that can see plaintext.
2. The three planes and their independence. Control plane (controllers), data plane (routers/fabric), management
   API. We HA-demoed it but never framed that the data plane keeps carrying traffic with every controller down,
   and that management is itself just a (dark) service. Demo idea: kill all controllers, existing circuits live.
3. The session model. API session (authentication) vs per-service sessions (authorization), their lifecycle,
   timeouts, and continuous posture re-evaluation. We show deny/allow but not the machinery, why access can be
   revoked mid-connection.
4. The attachment spectrum and its security tradeoff. SDK (app-embedded, no local listener) vs tunneler
   (host/proxy/tproxy) vs router-hosted vs zrok/clientless. Why the SDK is the most secure (nothing listens, even
   on localhost). We use all of these but never lay out the spectrum and when to pick which.
5. Identity model: SPIFFE IDs and trust domains. Ziti 2.0 identities are SPIFFE IDs under a trust domain (we set
   `learning.openziti.local` and never explain it). Plus the PKI trust chain (root/intermediate/signing) and how
   enrollment bootstraps trust (the /.well-known anchor) and auto-renews certs.
6. Terminator strategies and service HA semantics. smartrouting vs weighted vs ha vs random, precedence, cost, and
   how multiple hosts of one service are chosen. We create multiple terminators but never teach the strategy that
   picks among them.
7. Config types as an extensible, versioned schema system. intercept.v1 / host.v1 are instances of registered
   config types; host.v2, allowedAddresses/allowedPortRanges (server-side authorization of what a host may
   proxy), wildcard/IP-range intercepts. The idea that services are typed and extensible.
8. Smart routing as adaptive, not static. Link latency probing, dynamic cost, periodic circuit re-evaluation
   (cycleSeconds, rerouteFraction). We taught static cost in the pathing module but not that routing adapts on its
   own to link quality.
9. Zero-trust principles, named explicitly. A short framing that maps the demos to the principles: default-deny,
   least privilege, microsegmentation, identity-based (not network-location), no inbound ports, continuous
   authorization. We SHOW these but never name them as a coherent model.
10. Events and usage metrics model. The events subsystem (sessions, circuits, usage) beyond Prometheus scraping,
    useful for billing/audit stories.

BUILT: concepts 1-9 above are now a module, `lessons/concepts.md` (concept.a five principles, concept.b E2EE,
concept.c three planes, concept.d sessions & posture, concept.e attachment spectrum, concept.f SPIFFE/PKI,
concept.g terminators & strategies, concept.h typed configs, concept.i adaptive routing). Concept 10
(events/usage) folds into the Observability item above.

### More concept gaps found (candidates for additional concept videos)

These are NOT yet covered anywhere and are worth their own explainers:

a. Underlay independence / outbound-only. Ziti endpoints make only OUTBOUND connections, so you never open an
   inbound port or change a firewall rule, and it traverses NAT/CGNAT. This is a massive operational selling point
   we never frame. Demo: a host behind NAT with no inbound rules still serving a dark service.
b. "How is this different from X?" A positioning video vs VPN, mTLS, service mesh, and SDP. Learners always ask
   this first; answering it head-on accelerates everything else.
c. The addressing model. A service can be reached by many intercept addresses (names, wildcards, IP ranges, port
   ranges), and addressable terminators let you reach a SPECIFIC instance. How naming/addressing works on the
   overlay, distinct from the typed-configs concept.
d. Federated / external auth. Authentication is pluggable: external JWT signers / OIDC (ext-jwt-signer) let you
   bring your own IdP, alongside cert, UPDB, and 3rd-party CA. We have the feature in the interop auth-policy
   script but never frame it as "auth is pluggable."
e. The honest overhead. What the overlay actually costs in latency/throughput and why it is worth it, a "no
   magic, here are the numbers" trust-builder.
f. Microsegmentation. Every service is its own micro-perimeter (vs a network segment); least privilege at the
   connection level. Partly implied by the principles video, but worth making explicit.
g. Failure-modes taxonomy. A systematic "what happens when each piece dies" (controller, router, host, link),
   beyond the three-planes video, so operators know the blast radius of each.
