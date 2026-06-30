# Module concepts - "Why OpenZiti is different"

The mental-model series. Each of these is mostly explainer with a short demo on the existing lab, the "why it
works this way" ideas a viewer needs before the feature modules click. Shoot these early (right after Module 1)
or as standalone explainers.

**Stage setup:** `bash scripts/stage.sh module-3` (the full `zo` lab gives you services, identities, routers, and
the cluster to point at). Log in: `docker exec -it zo-ziti-controller1-1 ziti edge login localhost:1280 -u admin -p admin -y`.

---

## concept.a - The five principles of zero trust (5 min, framing, no build)

**GOAL:** Name the model so every later demo maps to a principle.

**COLD OPEN:**
> "Zero trust gets used as a buzzword. It's actually five concrete rules. Here they are, and every demo in this
> series is one of them in action."

**SAY / DO:** (slides, point back at Module 1's dark service)
- Default deny: nothing connects unless a policy says so.
- Least privilege: access is per-service, not per-network.
- Identity-based, not location-based: who you are decides access, not what subnet you're on.
- No inbound attack surface: services have no listening ports (they're "dark").
- Continuous authorization: access is re-checked, it can be revoked mid-connection.

**TAKEAWAY:** "Five rules. Keep them in mind, every feature you'll see is one of these made real."

**DON'T SHOW:** any CLI; this is the map, not the territory.

---

## concept.b - Your traffic is invisible to the network (7 min) - E2EE

**GOAL:** Ziti encrypts identity-to-identity; the routers and fabric cannot read your data.

**COLD OPEN:**
> "Here's the part people miss. The routers carrying your traffic can't read it. Not the fabric, not a compromised
> router, nobody in the middle. Encryption is end to end, identity to identity, not TLS-to-a-proxy."

**SAY / DO:**
- SAY: "Services require end-to-end encryption by default." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list services
  ```
  (point at ENCRYPTION REQUIRED = true)
- SAY: "The bytes are sealed between the two SDK endpoints. A router only sees ciphertext it's relaying. Contrast
  a normal TLS reverse proxy, which terminates TLS and sees your plaintext." DO: (optional) tcpdump on a router
  link interface and show it's opaque.
- SAY: "So 'the network is hostile' is the assumption, and OpenZiti makes it safe to assume."

**TAKEAWAY:** "End-to-end encryption means the transport, even your own routers, is untrusted and can't see your
data. That's the difference between a tunnel and a trust boundary."

**DON'T SHOW:** crypto internals; the point is who can and can't read the bytes.

---

## concept.c - Three planes, and why the network survives (7 min)

**GOAL:** Control plane, data plane, and management API are separate; the data plane outlives the controllers.

**COLD OPEN:**
> "There are three planes here, and the surprising one is that your traffic keeps flowing even with the brain
> turned off."

**SAY / DO:**
- SAY: "Controllers are the control plane (config + decisions). Routers are the data plane (they carry traffic).
  The management API is how you administer it, and it's itself a dark service." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti agent cluster list
  ```
- SAY: "Watch an established flow survive losing the entire control plane." DO: hold a connection, then
  ```
  docker stop zo-ziti-controller1-1 zo-ziti-controller2-1 zo-ziti-controller3-1
  ```
  show the held flow still works, then `docker start` them.

**TAKEAWAY:** "Decisions and traffic are separate concerns. Lose the controllers and existing data keeps moving,
the control plane is for change, not for carrying packets."

**DON'T SHOW:** killing controllers during a brand-new dial (new circuits need the controller); use an
established flow.

---

## concept.d - Who are you, and may you? (7 min) - sessions and posture

**GOAL:** Authentication (API session) and authorization (per-service session + posture) are distinct, ongoing gates.

**COLD OPEN:**
> "Logging in and being allowed to reach a service are two different things, and both are re-checked continuously."

**SAY / DO:**
- SAY: "First you authenticate, that's an API session." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list api-sessions
  ```
- SAY: "Then, per service you dial, you get a service session, only if a policy and any posture checks allow."
  DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list sessions
  ```
- SAY: "Posture is evaluated continuously, fail a check and the session is torn down mid-connection. We saw this
  as the winonly deny in Module 2." (recap the deny)

**TAKEAWAY:** "Authentication says who you are; authorization (policy + posture) says what you may reach right now,
and 'right now' is enforced for the life of the connection, not just at login."

**DON'T SHOW:** the full posture/MFA setup (that's Modules 2/5); focus on the two-gate concept.

---

## concept.e - Five ways to join the overlay (8 min) - the attachment spectrum

**GOAL:** SDK vs tunneler vs router-hosted vs clientless, and why the SDK is the most secure.

**COLD OPEN:**
> "There's a spectrum of how an app or device gets onto the overlay, and where you land on it changes your attack
> surface."

**SAY / DO:**
- SAY: "Most secure: the SDK, embedded in the app. No listening socket at all, not even on localhost." DO: point
  at the `sdk/` echo apps (Module interop).
- SAY: "Next: a tunneler beside the app (host / proxy / tproxy modes). The app is unmodified; the tunneler holds
  the identity." DO: point at echo-host and the roamer tproxy client.
- SAY: "Or let a router host the service directly, no sidecar." DO: recall ssh on corp-er (Module 2).
- SAY: "And clientless options (BrowZer/zrok) for a browser or public share."
- SAY: "The further toward the SDK, the smaller the surface: with the SDK there is literally nothing to port-scan."

**TAKEAWAY:** "Pick your edge by how much you can change the app and how tight you want the surface. SDK = no
listener anywhere = tightest. Tunneler = zero app change. Router-hosted = nothing extra to deploy."

**DON'T SHOW:** code; this is the menu and the tradeoff.

---

## concept.f - Identity is a SPIFFE ID, and trust is bootstrapped by PKI (7 min)

**GOAL:** Identities are SPIFFE IDs under a trust domain; enrollment establishes trust via a cert chain.

**COLD OPEN:**
> "An identity here isn't a username in a database. It's a cryptographic identity, a SPIFFE ID, anchored to a
> trust domain by a certificate chain you control."

**SAY / DO:**
- SAY: "Every identity lives under one trust domain." DO: show the controller `trustDomain` /
  `learning.openziti.local` (config) and `ziti edge list identities` (each is cert-backed).
- SAY: "Trust is bootstrapped by PKI: a root CA, an intermediate that signs identities, and a signing cert handed
  out at enrollment. Enrolling swaps a one-time token for a key + cert; certs auto-renew." DO: point at
  `docs/controller-internals.md` (the PKI layout).

**TAKEAWAY:** "Identity is a SPIFFE ID proven by a cert under a trust domain you own. No shared secrets, no
passwords-by-default, and the trust chain is yours."

**DON'T SHOW:** raw cert parsing; the concept is SPIFFE ID + trust domain + cert chain.

---

## concept.g - How a service picks a host (6 min) - terminators and strategies

**GOAL:** One service can have many hosts (terminators); a strategy picks among them.

**COLD OPEN:**
> "A service isn't one server. It can be many, and the overlay decides which one each dial lands on."

**SAY / DO:**
- SAY: "Each host that binds a service creates a terminator. Our echo has several." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list terminators 'service.name="echo"'
  ```
- SAY: "A terminator strategy chooses among them: smartrouting (default), weighted, ha, random. That's your load
  balancing and failover, built in, no LB appliance." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list services
  ```
  (point at TERMINATOR STRATEGY)

**TAKEAWAY:** "Service HA and load balancing are a property of the overlay: many terminators, one strategy, no
external load balancer."

**DON'T SHOW:** precedence/cost math; name the strategies and move on.

---

## concept.h - Configs are typed and extensible (5 min)

**GOAL:** intercept.v1 / host.v1 are instances of registered, versioned config types.

**COLD OPEN:**
> "Those `intercept.v1` and `host.v1` blobs aren't magic strings. They're instances of typed, versioned schemas,
> and you can add your own."

**SAY / DO:**
- SAY: "The controller has a registry of config types." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list config-types
  ```
- SAY: "A service references configs of these types: a client-side intercept (how you address it) and a host-side
  config (where it goes, and what the host is allowed to proxy, via allowedAddresses)." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list configs
  ```

**TAKEAWAY:** "Service behavior is data, typed and versioned. Same model scales from a single port to wildcard
domains and IP ranges, and to config types you define."

**DON'T SHOW:** writing a custom config type; the concept is typed/versioned/extensible.

---

## concept.i - Routing that adapts (6 min) - smart routing

**GOAL:** The fabric measures link quality and re-routes on its own; cost is one input, not the whole story.

**COLD OPEN:**
> "We forced paths with cost in the pathing module. But left alone, the fabric is measuring itself and steering
> traffic for you."

**SAY / DO:**
- SAY: "Links report latency continuously; the controller folds that into each link's cost." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list links
  ```
  (point at SRC/DST LATENCY and FULL COST)
- SAY: "Smart routing periodically re-evaluates circuits and moves the underperforming ones, so a degrading link
  sheds traffic without anyone touching a config."

**TAKEAWAY:** "Routing is adaptive: latency-aware cost plus periodic re-evaluation. Static cost (pathing module)
is you overriding a system that's already optimizing."

**DON'T SHOW:** cycleSeconds/rerouteFraction tuning; the concept is 'it adapts'.

---

## Verification status

These are explainer videos that read off live state already in the lab (services, identities, sessions,
terminators, links, config-types, cluster). The only one with a destructive demo is concept.c (stop all
controllers, then start them); everything else is read-only `ziti edge`/`ziti fabric list` against the running
lab. The E2EE packet-capture in concept.b is optional flavor; the ENCRYPTION REQUIRED flag is the concrete proof.
