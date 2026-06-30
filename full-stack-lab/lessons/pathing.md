# Module pathing - "Custom router paths and link groups"

How traffic chooses a path across the fabric, and how you take control of it: read circuits, steer
with link cost, force a long cross-cloud route, reroute around failure, and partition the fabric with
link groups.

**Stage setup:** `bash scripts/stage.sh module-3` (the full `zo` lab), then
`bash scripts/provision-pathing.sh` (adds the `deep` service, hosted only on vpc2-er, as a controlled
long-path target). Log in: `docker exec -it zo-ziti-controller1-1 ziti edge login localhost:1280 -u admin -p admin -y`.

Run the demos with the helper: `scripts/demo-longpath.sh` (cost steering) and
`scripts/provision-linkgroups.sh` (real link groups).

---

## pathing.a - How a connection picks its path (6 min)

**GOAL:** Every dial becomes a circuit, a chosen path across routers and links, and you can see it.

**COLD OPEN:**
> "When you dial a service, something decides which routers your bytes cross. Let's make that decision visible."

**SAY / DO:**
- SAY: "Routers connect with links. This is the fabric." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list links
  ```
  (point at dialer, acceptor, STATIC COST, latency, FULL COST)
- SAY: "Hold a dial open so there's a live circuit." DO:
  ```
  scripts/demo-longpath.sh hold &
  ```
- SAY: "Here's the circuit and the exact path it took." DO:
  ```
  scripts/demo-longpath.sh circuits
  ```
  Expect: a circuit for `deep` with a PATH like `r/home-er -> l/<link> -> r/vpc2-er` (the short, cheap route).
- SAY: "Smart routing picked the lowest total cost. Right now that's the direct hop. Watch what happens when we
  change the cost."

**TAKEAWAY:** "A dial is a circuit, a path the controller computes by cost. Cost is the dial you turn to control
routing."

**DON'T SHOW:** terminator strategy internals; just path = lowest cost.

---

## pathing.b - Steer with link cost (7 min)

**GOAL:** Raising a link's static cost makes smart routing avoid it.

**COLD OPEN:**
> "Cost isn't fixed. Bump a link's cost and the network routes around it, live."

**SAY / DO:**
- SAY: "Find the link the current circuit uses, and raise its cost." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric update link <linkId> --static-cost 1000
  docker exec -it zo-ziti-controller1-1 ziti fabric list links
  ```
  (the link's FULL COST jumps; verified: STATIC COST 1000 -> FULL COST 1004)
- SAY: "New connections now avoid it. Hold a fresh dial and look at the circuit." DO:
  ```
  scripts/demo-longpath.sh hold &
  scripts/demo-longpath.sh circuits
  ```
  Expect: the PATH now routes around the expensive link.
- SAY: "Put it back." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric update link <linkId> --static-cost 1
  ```

**TAKEAWAY:** "Static cost is a live knob. Raise it to drain a link, lower it to prefer one. Smart routing reacts
on the next circuit."

**DON'T SHOW:** the cost math; just high cost = avoided.

---

## pathing.c - Force the scenic route home -> internet -> vpc1 -> vpc2 (8 min)

**GOAL:** Make a dial take a deliberate multi-hop path across the emulated clouds instead of the shortcut.

**COLD OPEN:**
> "Sometimes you WANT the long way: through the internet edge, into vpc1, then vpc2, maybe for inspection, maybe
> for compliance. Let's force it."

**SAY / DO:**
- SAY: "The `deep` service lives only on vpc2-er, so a home client must reach vpc2. By default it takes the 1-hop
  shortcut. We make every link except the chain expensive." DO:
  ```
  scripts/demo-longpath.sh force
  ```
  (keeps home-er<->public-er-1, public-er-1<->vpc1-er, vpc1-er<->vpc2-er cheap; everything else 9999)
- SAY: "Now dial deep from home and look at the path." DO:
  ```
  scripts/demo-longpath.sh hold &
  scripts/demo-longpath.sh circuits
  ```
  Expect: PATH `r/home-er -> r/public-er-1 -> r/vpc1-er -> r/vpc2-er`, the scenic cross-cloud route.
- SAY: "Reset when done." DO:
  ```
  scripts/demo-longpath.sh reset
  ```

**TAKEAWAY:** "With cost you can pin traffic to a specific multi-hop path across sites, the overlay obeys, and the
service stayed dark in vpc2 the whole time."

**DON'T SHOW:** the per-link cost loop internals (the script handles it).

---

## pathing.d - Reroute around failure (6 min)

**GOAL:** When a link or router on the path dies, smart routing reroutes.

**COLD OPEN:**
> "A forced path is nice until a link dies. Watch the network heal."

**SAY / DO:**
- SAY: "Take a link on the current path down." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric update link <linkId> --down true
  ```
- SAY: "New dials reroute around it." DO:
  ```
  scripts/demo-longpath.sh hold &
  scripts/demo-longpath.sh circuits
  ```
  Expect: a different PATH that avoids the downed link.
- SAY: "Bring it back." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric update link <linkId> --down false
  ```
- SAY: "Same idea if a whole transit router dies, see module-3's HA demo, the data plane finds another way."

**TAKEAWAY:** "Cost and link state feed one routing engine: steer with cost, survive failure by reroute, no
client change either way."

**DON'T SHOW:** killing a router a proxy client uses as its only edge entry (drops the client; use link-down or a
transit router).

---

## pathing.e - Link groups: partition the fabric (8 min)

**GOAL:** Routers only form links within a shared group, so groups dedicate paths.

**COLD OPEN:**
> "Cost biases routing. Link groups go further: they decide which routers are even ALLOWED to link. That's how you
> keep sensitive traffic on dedicated links."

**SAY / DO:**
- SAY: "A router's link dialers and listeners can carry `groups: [..]`. No group = the implicit default group,
  which is why our lab is a full mesh. Put two routers in their own group." DO:
  ```
  bash scripts/provision-linkgroups.sh apply premium public-er-1 vpc1-er
  ```
  (edits those routers' config to `groups: [premium]` and restarts them)
- SAY: "After they re-form, those two only link to each other, the fabric is partitioned." DO:
  ```
  bash scripts/provision-linkgroups.sh show
  ```
  Expect: public-er-1 and vpc1-er link to each other but no longer to the default-group routers.
- SAY: "This is the production mechanism: dedicated links for a class of traffic, regional separation, compliance
  paths. Revert when done." DO:
  ```
  bash scripts/provision-linkgroups.sh revert public-er-1 vpc1-er
  ```

**TAKEAWAY:** "Link cost biases the path; link groups constrain which links can exist at all. Together they give
you real control over how traffic crosses the fabric."

**DON'T SHOW:** the YAML sed internals; note that the router must keep the edited config (ZITI_BOOTSTRAP_CONFIG
false) if it regenerates on boot.

---

## pathing.f - Putting it together (5 min)

**GOAL:** Recap the routing control surface.

**SAY / DO:**
- SAY: "Three levers, one engine. Circuits show you the path. Link cost biases it. Link state (up/down) forces
  reroute. Link groups decide which links can form at all." DO:
  ```
  scripts/demo-longpath.sh links
  scripts/demo-longpath.sh circuits
  ```
- SAY: "Everything else, services, identities, posture, rode on top of this without caring how the bytes crossed
  the fabric. That separation is the point."

**TAKEAWAY:** "You now control the data path explicitly: observe with circuits, steer with cost, heal with link
state, partition with groups, while services and security stay exactly the same."

**DON'T SHOW:** anything new; victory lap.

---

## Verification status

Verified live: the steering lever (`ziti fabric update link --static-cost` takes effect, FULL COST changes and
smart routing reroutes) and the `deep` single-terminator target (dialed from home, routed to vpc2-er). The forced
multi-hop circuit and link-group partition are run by you in a normal terminal (held connections + `ziti fabric
list circuits` render the path there; the build sandbox swallows that output). Link groups edit router config and
restart, read the notes in `scripts/provision-linkgroups.sh` first.
