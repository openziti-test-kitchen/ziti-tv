# The interop matrix: every SDK talking to every SDK, then layered with zero-trust controls

Status: BUILT + smoke-verified for 5 languages. All 7 SDK app sets (echo + http, server + client) and the Ziti
model, compose, matrix harness, and the posture/auth/health/link-group layer scripts exist. Live smoke proved
go/py/js/java/c interoperate both ways (a 5x5 green block, see results/SMOKE.md). C# (cs) is PARKED: builds and
follows the contract but its OpenZiti.NET native identity-load did not work live, a known gap, not a blocker.
Swift is the macOS-only host edge. The sections below are the design; the build follows them.

The goal: prove OpenZiti is truly language-agnostic by running an echo app and an HTTP app in every SDK, as both
server and client, then dialing every client against every server in one homogeneous lab. Once the bare matrix is
green, layer on posture checks, auth policies, health checks, and customized pathing, and watch the matrix change
in ways you can see.

---

## 0. The big picture

```
                 servers  ->   go   cs   py  java  js   c  swift
        clients  +-----------------------------------------------
        go       |          [echo NxN grid]   [http NxN grid]
        cs       |           each cell = did <client-lang> reach
        py       |           <server-lang> over the Ziti service?
        java     |           green = ok, red = failed, grey = denied
        js       |
        c        |
        swift    |
```

Two apps (echo, http) x 7 languages x {server, client} = 28 programs. Two 7x7 grids (98 dials) prove that any
client speaks to any server with zero protocol surprises, because Ziti carries the bytes identically regardless of
language. The "homogeneous environment" is the lab itself: every program runs as a Linux container, enrolled with
its own SDK identity, no tunnelers.

---

## 1. The two app contracts (identical across all languages)

Both apps bind/dial a Ziti SERVICE by name using the SDK directly (no tunneler, no open ports).

- **echo** - raw stream. Server: accept a Ziti connection, read bytes, write the same bytes back, loop. Client:
  dial the service, send a known line, read it back, assert equal, print OK/latency.
- **http** - request/response. Server: serve HTTP over a Ziti listener (the SDK gives you a `net.Listener`-like
  object), respond to `GET /` with a small JSON body that includes the server language and hostname. Client: do an
  HTTP GET over Ziti, assert 200 and that the body parses, print OK/latency.

Why both: echo proves raw byte fidelity and stream semantics; http proves a real protocol with framing, headers,
and a library stack sitting on top of the Ziti socket. If both pass across all pairs, the overlay is transparent.

Each program reads an enrolled identity JSON from `ZITI_IDENTITY` and the service name from `ZITI_SERVICE`.
Servers also read `SELF_LANG` to put their language in responses.

---

## 2. The SDK roster and per-language deliverables

| Lang | code | SDK |
|---|---|---|
| Go | go | github.com/openziti/sdk-golang |
| C# | cs | github.com/openziti/ziti-sdk-csharp |
| Python | py | github.com/openziti/ziti-sdk-py |
| Java | java | github.com/openziti/ziti-sdk-jvm |
| JS/Node | js | github.com/openziti/ziti-sdk-nodejs |
| C | c | github.com/openziti/ziti-sdk-c |
| Swift | swift | github.com/openziti/ziti-sdk-swift |

Per language, four small programs + a Dockerfile:

```
sdk/<code>/
  echo/server   echo/client
  http/server   http/client
  Dockerfile        # builds all four into one image, entrypoint selects by arg
  README.md         # build + run + which APIs were used
```

The existing `sdk/` scaffolds (Go + Python complete, the rest marked) are the seed; this plan finishes them and
adds the http pair and the Dockerfile per language.

---

## 3. The Ziti model for the matrix (naming scheme)

Services (14): `echo.<code>` and `http.<code>` for each language. Attributes:
- every service: `#interop`
- echo services also: `#echo`; http services also: `#http`
- each service also carries `#srv.<code>` so its server binds it.

Identities:
- servers: `srv-<code>`, attribute `#servers` and `#host.<code>`
- clients: `cli-<code>`, attribute `#clients`

Policies (the whole matrix is four policies plus per-language bind):
- `dial-interop` (Dial): identityRoles `#clients`, serviceRoles `#interop`  -> any client may dial any service
- bind per language `bind-<code>` (Bind): identityRoles `#host.<code>`, serviceRoles `#srv.<code>` -> srv-go binds
  echo.go and http.go, etc.
- edge-router-policy `erp-all` and service-edge-router-policy `serp-all` (already exist in the lab)

This is deliberately minimal: ONE dial policy gives full NxN reach, and role attributes mean adding an 8th
language is "add two services + one identity + one bind," no policy churn.

Containers (homogeneous lab): for each language, a `srv-<code>` container (runs both echo and http servers) and a
`cli-<code>` container (runs the matrix client on demand). All on the lab network, all SDK-enrolled.

---

## 4. The interop matrix and how we see it

A harness `scripts/interop-matrix.sh`:
1. provisions the 14 services + 14 identities + policies (idempotent),
2. mints + enrolls identities, brings up the 7 server containers,
3. for app in {echo, http}, for client in 7 langs, for server in 7 langs: runs `cli-<client>` against
   `<app>.<server>`, captures OK/FAID + latency,
4. renders two 7x7 grids to `results/interop-<app>.md` (markdown heatmap) and a combined `results/interop.html`.

A cell is: green OK, red app-level failure (connected but wrong bytes/status), grey policy denial. In the bare
matrix every cell should be green. The grid IS the deliverable, it makes "language-agnostic" undeniable.

---

## 5. Layer 1 - posture checks on the matrix

Add device posture to a subset of access and watch cells flip grey.

- Split clients: tag half `#clients.trusted`, half `#clients.posture`.
- Add `dial-interop-posture` (Dial): identityRoles `#clients.posture`, serviceRoles `#interop`,
  posture-check-roles `#posture.matrix`.
- Posture checks to demo, one of each type so learners see the menu: `os` (e.g. Linux only), `process`
  (a required binary present), `mac` (allowlist), `domain` (Windows domain). Tag them `#posture.matrix`.
- Re-run the matrix: posture clients that fail the check show a grey ROW; trusted clients stay green. Same code,
  same service, access decided by device state.

Teaching point: posture is evaluated continuously and per-service; flip a process off and the row goes grey on the
next dial.

---

## 6. Layer 2 - auth policies on the matrix

Posture decides "may this identity use this service." Auth policy decides "may this identity authenticate at all,
and how." They are different gates and the matrix shows both.

- Create auth-policies: `ap-default` (cert only), `ap-mfa` (cert + required TOTP), `ap-updb` (password allowed).
- Assign `ap-mfa` to one client (say `cli-swift`). Without enrolling TOTP it cannot get an API session, so its
  ENTIRE row is "auth-denied" (a distinct color from posture-grey), even for services it is otherwise allowed.
- Assign `ap-updb` to a `human-*` identity to show password auth alongside cert auth in the same matrix.

Teaching point: auth-policy is the front door (authentication, what methods are allowed, is MFA mandatory);
service-policy + posture is the room key (authorization). The matrix renders auth-denied vs dial-denied vs ok as
three colors.

---

## 7. Layer 3 - health checks

Make terminators self-heal and show it in the matrix.

- Run TWO servers per service (`srv-<code>` and `srv-<code>-b`) so each service has two terminators (HA).
- Configure health checks: for http services, an `httpCheck` (GET /healthz on the backend); for echo, a
  `portCheck`. A failing health check drops that terminator from the pool and lowers its precedence.
- Demo inside the matrix: kill one server's health endpoint, its terminator goes unhealthy, dials transparently
  use the healthy twin, the matrix STAYS green (failover) while `ziti edge list terminators` shows one down.
- Then kill both: that server-column goes red (no healthy terminator), proving the check actually gates traffic.

Teaching point: health checks tie real backend liveness to overlay routing, no load balancer required.

---

## 8. Layer 4 - customized pathing with router link groups

So far smart routing picks the path. Now constrain it deliberately with link groups.

- Give routers link `groups` (e.g. `premium`, `budget`) so links only form within matching groups. Tag the
  long-haul links `budget` and a direct high-grade link `premium`.
- Steer per service: high-value services (say `http.go`) are pinned to traverse the `premium` group; bulk services
  use `budget`. Combine with `--static-cost` to make smart routing prefer the intended group.
- Visualize: for a chosen matrix cell, `ziti fabric list circuits` shows the path staying inside the assigned
  group; raise the premium link cost or take it down and watch the circuit refuse to use budget (or reroute,
  depending on policy) so you can SEE the constraint, not just assert it.

Teaching point: link groups + cost are how you express "this traffic must take that path," compliance routing,
keeping sensitive flows off shared links, multi-region steering.

---

## 9. Build order (soup to nuts)

1. Finish the app pairs: echo server/client AND http server/client in all 7 SDKs, one Docker image per language.
   Start with Go and Python (already seeded), then JS, then the compiled ones (C#, Java, C, Swift).
2. Stand up the Ziti model: 14 services, 14 identities, the dial + bind policies. Script it idempotently.
3. Bring up the 7 server containers; mint + enroll all identities.
4. Build the harness and render the two bare 7x7 grids. Target: all green.
5. Layer posture (Section 5), re-render, show the grey rows.
6. Layer auth policies (Section 6), re-render, show auth-denied rows.
7. Add the second server per service + health checks (Section 7), demo failover keeping the grid green.
8. Add link groups + steering (Section 8), show constrained circuits per cell.

Each step is independently demoable and maps cleanly to a video.

---

## 10. How it folds into the series

This is naturally a new module (call it the "interop" module) that sits after Module 4 (SDKs) and pulls forward
posture (Module 2/5), auth policies (new), health checks (new), and pathing (Module 6). Suggested videos:
`interop.a` the matrix idea + echo across 3 langs, `interop.b` the full green grid, `interop.c` posture flips
cells, `interop.d` auth policies vs posture, `interop.e` health-check failover, `interop.f` link-group steering.

Directory additions when built: `sdk/<code>/{echo,http}/...`, `scripts/interop-matrix.sh`,
`scripts/provision-interop.sh`, `compose/interop.yml`, `results/interop*.{md,html}`.

---

## 11. Open questions to settle before building

- Echo transport: keep it line-based TCP-style over the Ziti conn, agreed? (simplest cross-language contract)
- One image per language with an arg selector, or four tiny images per language? (plan assumes one image)
- Matrix scope v1: all 7 languages, or prove the harness on 3 (go/py/js) then fan out? (recommend 3 then fan out)
- Health check transport: rely on host.v1-style checks via an SDK shim, or implement a `/healthz` in each server?
  (recommend a `/healthz` in the http servers and a port check for echo)
- Link groups: confirm the exact router config keys for `groups` against the pinned 2.0.0 router before relying on
  them in a video.
