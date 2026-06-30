# Module 3 - "Scaling it up" (the overkill)

**Stage setup:** `bash scripts/stage.sh module-3` (full lab). This is where the deliberately
over-engineered topology pays off.

---

## module-3.a - High availability (7 min)

**GOAL:** The control plane is clustered; losing a controller does not drop the overlay.

**COLD OPEN:**
> "One controller is a single point of failure. Real deployments cluster them. Let's build a three-node brain and
> then murder the leader."

**SAY / DO:**
- SAY: "Three controllers, one raft cluster. One leader, two voters." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti agent cluster list
  ```
  (point at LEADER true on one, VOTER true on all, CONNECTED true)
- SAY: "Watch a live dial keep working while I kill the leader." DO: start a held connection (echo), then:
  ```
  docker stop zo-ziti-controller1-1
  ```
- SAY: "Leadership moves on its own." DO:
  ```
  docker exec -it zo-ziti-controller2-1 ziti agent cluster list
  ```
  (a new LEADER; data plane traffic never dropped)
- SAY: "Bring it back, it rejoins as a voter." DO:
  ```
  docker start zo-ziti-controller1-1
  ```

**TAKEAWAY:** "The controllers are a raft cluster. Quorum survives a node loss, leadership re-elects automatically,
and existing connections don't care, the data plane is independent of any single controller."

**DON'T SHOW:** raft internals, exact quorum math beyond 'majority'.

---

## module-3.b - Many sites, long paths (9 min)

**GOAL:** One overlay spans "clouds"; the data path crosses sites while services stay dark everywhere.

**COLD OPEN:**
> "Real networks aren't flat. You've got a home machine, the public internet, a couple of cloud VPCs. Let's route
> across all of them, on one overlay."

**SAY / DO:**
- SAY: "These docker networks emulate sites: home, the internet, two VPCs, a corp datacenter." DO:
  ```
  docker network ls --format '{{.Name}}' | grep '^zo-'
  ```
- SAY: "A router lives in each site." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list edge-routers
  ```
  (public-er-1 internet, vpc1-er, vpc2-er, corp-er, home-er, transit-router)
- SAY: "When the home client dials a service hosted deep in a VPC, the circuit crosses sites, and you can see every
  hop." DO: hold a connection, then:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list circuits
  ```
  (read the multi-hop PATH aloud)
- SAY: "Every backend is still dark in its own site. The overlay is the only way across, and only for allowed
  identities."

**TAKEAWAY:** "OpenZiti is one logical overlay stretched across many networks. Traffic crosses sites through the
fabric; services never expose a port in any of them."

**DON'T SHOW:** the path-shaping/link-cost tuning (mention it's possible to pin routes).

---

## module-3.c - The full monster + where next (10 min)

**GOAL:** Tie it together and point at the wider OpenZiti world.

**COLD OPEN:**
> "Let's stand the whole thing up from nothing, one command, and then I'll show you where to go from here."

**SAY / DO:**
- SAY: "From an empty docker, the entire lab, cluster, routers, services, comes up with one script." DO:
  ```
  bash scripts/demo-up.sh
  ```
  (timelapse / cut the wait)
- SAY: "One snapshot shows everything we've learned in one screen." DO:
  ```
  bash scripts/status.sh
  ```
  (cluster, routers, links, services, identities, terminators, circuits)
- SAY: "We did this all in containers, but the same identities run as a desktop app on Windows and macOS, as a
  daemon on Linux, inside Kubernetes, or embedded directly in your app with an SDK, no tunneler at all."
- SAY: "And tools like zrok build on top of this to share things publicly in one command."

**TAKEAWAY:** "You now know the whole model, controller, routers, identities, services, policies, posture, HA, and
multi-site, and the vocabulary to follow any OpenZiti doc, demo, or deployment from here."

**DON'T SHOW:** anything new you won't explain. This is a victory lap, not a new topic.

---

## Where this series could go next (bonus episode ideas)

- Kubernetes: run a service inside k3d, reachable only over Ziti, no ingress.
- Desktop Edge for Windows/macOS: dial a lab service from your actual laptop.
- SDK: an app that joins the overlay with no tunneler at all.
- MFA/TOTP posture in depth. CA verification + auto-enroll a fleet. Path shaping / chaos (kill links, watch
  reroute).
