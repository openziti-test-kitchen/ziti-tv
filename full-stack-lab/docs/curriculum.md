# "What the fuck even is OpenZiti" - video curriculum

A graduated series built on this repo. Each episode is 4-10 minutes, adds exactly ONE concept, and ends with
something working on screen. The "overkill" full stack is the module finale, not the intro.

## Guiding principles

- One new idea per video. If a viewer can't say the takeaway in a sentence, the video is too big.
- Always end on something running. Show, then explain, not the reverse.
- Progressive disclosure: do NOT show the 3-node cluster, 6-router mesh, or fake clouds until Module 3. They are
  noise to a beginner and the reason the current lab is too much for episode 1.
- Every episode maps to a script already in this repo, so the demo is copy-pasteable and reproducible.
- Use a real terminal with `docker exec -it ...` (clean output). The sandbox quirks in addendum_03 do not apply.

## What to cut/trim for teaching (vs the overkill lab)

The lab is deliberately maximal. For the series, start from a MINIMAL slice and grow:

| Lab has | Beginner needs | When to introduce |
|---|---|---|
| 3 controllers (raft) | 1 controller | Module 3 (HA episode) |
| 6 routers, full mesh | 1 router | Module 2 (fabric); 2nd router for links |
| 5 emulated cloud networks | none (flat) | Module 3 (multi-site) |
| 3 services, 2 hosting patterns | 1 service (echo) | echo in module 1; ssh/router-host in module 2 |
| posture, UPDB, CA, ott | OTT only | OTT in module 1; the rest in module 2 |
| transit-router, link cost | skip | Module 2/3 only if time |

Built: the `lessons/` track + a minimal stack. `compose/lesson-min.yml` (1 controller + 1 router, project `zomin`)
and `compose/lesson-echo.yml` (echo backend + tunnelers) let Module 1 run end-to-end on two-plus-a-bit containers.
Bring up with `scripts/lesson-up.sh` then `scripts/lesson-echo.sh`. The overkill `zo` stack stays for Modules 2-3.
Full shooting scripts are in `lessons/module1.md`, `module2.md`, `module3.md`.

## Module 1 - "What even is it" (concept + first contact)

### module-1.a. The problem (5 min, no code)
- Hook: "Every service you run has open ports. Attackers scan for them. VPNs give whole-network access. This is dumb."
- Show: a diagram. App with an open port getting scanned vs an app with NO open ports.
- Takeaway: OpenZiti is a zero-trust overlay network; services become "dark" (no inbound ports) and are reached
  only by authorized identities.
- Cut: anything technical. Pure mental model.

### module-1.b. The five words you need (6 min, diagram-driven)
- Hook: "Five nouns and you can read any OpenZiti doc."
- Show: controller, router, identity, service, policy, on one diagram (use `docs/architecture.md` shapes).
- Takeaway: controller = brain/config; router = carries traffic; identity = who you are; service = what you reach;
  policy = who may reach what.
- Cut: configs, enrollment types, posture. Just the nouns.

### module-1.c. Hello overlay (7 min)
- Hook: "Let's make one exist."
- Do: bring up 1 controller + 1 router (lesson-min). `ziti edge login`. Open ZAC at `/zac`.
- Takeaway: a running controller + an enrolled router IS an overlay, even with nothing on it yet.
- Cut: HA, multiple routers. One of each.

### module-1.d. Your first dark service (8 min) - the money shot
- Hook: "A web server with zero open ports that you can still reach."
- Do: the echo (whoami) demo - host it, dial it (`scripts/provision-echo.sh`, `compose/echo-demo.yml`, then
  `curl localhost:8080`). Show `docker ps` proving no published port on the backend.
- Takeaway: traffic went app -> tunneler -> router -> tunneler -> app, all mTLS, no open inbound port anywhere.
- This is the episode that makes people get it. Spend the most polish here.

### module-1.e. Who are you? Identities & OTT enrollment (6 min)
- Hook: "How did that client earn the right to connect?"
- Do: `ziti edge create identity ... -o x.jwt`, enroll a tunneler, show the JWT is one-time.
- Takeaway: every participant has a cryptographic identity; enrollment swaps a one-time token for a client cert.
- Cut: UPDB, CA, x509 (that's module-2.c).

### module-1.f. Services, configs & policies (9 min)
- Hook: "Access is deny-by-default. Here's how you grant it."
- Do: walk `intercept.v1` / `host.v1`, `Bind` vs `Dial` service policies, role attributes (`#echo.clients`).
- Takeaway: a service ties config (where/how) to policy (who); attributes scale it without per-identity rules.
- Cut: posture-check-roles (tease it for module-2.b).

## Module 2 - "How it actually works" (mechanics)

### module-2.a. The fabric: routers, links, circuits (8 min)
- Do: add a 2nd router, show `ziti fabric list links` and a live `ziti fabric list circuits` with its PATH.
- Takeaway: routers mesh via links; each dial picks a circuit (a path) across them; smart routing chooses.

### module-2.b. Two ways to host a service (7 min)
- Do: contrast the tunneler-hosted echo with the router-hosted ssh (`scripts/provision-ssh.sh`). SSH over Ziti.
- Takeaway: a backend can be fronted by a dedicated tunneler OR by a router itself; same overlay, different edge.

### module-2.c. Access control with posture checks (7 min)
- Do: the `winonly` deny demo - same client gets echo but is denied a Windows-gated service on Linux.
- Takeaway: policies can require device posture (OS, process, MAC, domain, MFA), not just identity.

### module-2.d. Enrollment, the full menu (8 min)
- Do: OTT vs UPDB (`alice`) vs 3rd-party CA (`ziti pki` + `create ca --ottca --autoca`).
- Takeaway: identities can come from tokens, passwords, or your existing PKI/CA; pick per use case.

## Module 3 - "Scaling it up" (the overkill)

### module-3.a. High availability (7 min)
- Do: the 3-node raft cluster; `ziti agent cluster list`; kill the leader, watch re-election, traffic survives.
- Takeaway: the control plane is clustered; losing a controller does not drop the overlay.

### module-3.b. Many sites, long paths (9 min)
- Do: the emulated clouds (`zo-internet/vpc1/vpc2/home/corp`), routers per site, the cross-site dial + its circuit.
- Takeaway: one overlay spans "clouds"; the data path crosses sites while services stay dark everywhere.

### module-3.c. The full monster + where next (10 min)
- Do: bring up everything (`scripts/demo-up.sh`), `scripts/status.sh` tour. Point at k8s, Desktop Edge (Windows/
  macOS), SDKs, zrok as next steps.
- Takeaway: you now have the vocabulary to go anywhere in the OpenZiti world.

## Modules 4-7 (the expansion, full scripts in `lessons/`)

The intro arc above is Modules 1-3. The advanced material is written up as additional modules:

- Module 4 - real edges (`lessons/module4.md`): module-4.a dial by name (tproxy), module-4.b your actual laptop (Desktop
  Edge / ziti-edge-tunnel), module-4.c the SDK with no tunneler (`sdk/`).
- Module 5 - advanced auth (`lessons/module5.md`): module-5.a UPDB + MFA, module-5.b bring-your-own-CA fleet, module-5.c
  revocation.
- Module 6 - production (`lessons/module6.md`): module-6.a observability, module-6.b failure/resilience, module-6.c path shaping,
  module-6.d backups.
- Module 7 - Kubernetes (`k8s/LESSON.md`): a dark k8s service with no ingress.

See `lessons/README.md` for the per-episode verification-status legend (live-verified vs scripted vs
scaffold/needs-host).

## Trimming to a tighter series (~8 episodes)

If 13 is too many: merge module-1.a+module-1.b (concept+vocab), merge module-1.e into module-1.d (enroll while hosting), fold module-3.a (HA) into module-2.a
(resilience), and make Module 3 a single "the overkill tour" episode. Minimum viable arc that still lands the
point: module-1.a, module-1.c, module-1.d, module-1.f, module-2.a, module-2.c, module-3.c.

## Production notes

- Pre-bake state before recording where possible; enrollment + image pulls are dead air.
- The "no open ports" proof (`docker ps`, an `nmap` from outside) is the most persuasive 20 seconds in the series.
- Keep one consistent example (echo/whoami) across episodes so viewers track continuity.
