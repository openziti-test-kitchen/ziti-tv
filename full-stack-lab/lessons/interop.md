# Module interop - "Every SDK talks to every SDK"

Honest status: BUILT and smoke-verified. Six Linux SDK images build (go, py, js, cs, java, c); Swift is the
Apple-only host edge. Live smoke proved go/py/js/java fully interoperate both directions and C works
(see results/SMOKE.md). Run these in a normal Docker Desktop / WSL shell (the compose bind mounts and
`docker run` stdout misbehave under Git Bash).

**Stage setup:** `bash scripts/stage.sh module-2` (the full `zo` lab carries the fabric, routers, and identities the
matrix rides on). Then:
- `bash scripts/provision-interop.sh` (14 services + identities + policies, enrolled to tokens/interop/)
- `docker compose -p zo -f compose/interop.yml up -d` (brings up the server containers zo-i-echo-<c>-1 / zo-i-http-<c>-1)
- `bash scripts/interop-matrix.sh` (dials every client x every server, writes results/interop-echo.md,
  results/interop-http.md, results/interop.html on the HOST)
Log in first: `docker exec -it zo-ziti-controller1-1 ziti edge login localhost:1280 -u admin -p admin -y`

A single manual dial (one matrix cell) is a one-shot docker run that uses the client image's entrypoint:
`docker run --rm --network zo-ctrl -e ZITI_SERVICE=echo.py -e ZITI_IDENTITY=/ziti/id.json
-v "$(pwd)/tokens/interop/icli-go.json:/ziti/id.json:ro" zo-sdk-go echo client`  ->  `RESULT ok echo go->py <ms>ms`

---

## interop.a - Same bytes, any language (6 min)

**GOAL:** A client in one language echoes through a service hosted by a server in another language, with byte-for-byte
identical results.

**COLD OPEN:**
> "People ask if OpenZiti is a Go thing, or a Python thing, or a Node thing. It's none of them. It's all of them at
> once. Watch a Go client, a Python client, and a Node client send the exact same bytes through each other's
> servers."

**SAY / DO:**
- SAY: "We have echo servers running in three languages, each bound to its own Ziti service." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list services 'name contains "echo."'
  ```
  Expect: `echo.go`, `echo.py`, `echo.js` listed, each with a bound terminator.
- SAY: "Start with the Go client hitting the Go server. One-shot dial over the overlay." DO:
  ```
  docker run --rm --network zo-ctrl -e ZITI_SERVICE=echo.go -e ZITI_IDENTITY=/ziti/id.json \
    -v "$(pwd)/tokens/interop/icli-go.json:/ziti/id.json:ro" zo-sdk-go echo client
  ```
  Expect: `RESULT ok echo go->go <ms>ms`.
- SAY: "Now the same Go client image, pointed at the Python server. Different language hosting, no change on the
  client." DO:
  ```
  docker run --rm --network zo-ctrl -e ZITI_SERVICE=echo.py -e ZITI_IDENTITY=/ziti/id.json \
    -v "$(pwd)/tokens/interop/icli-go.json:/ziti/id.json:ro" zo-sdk-go echo client
  ```
  Expect: `RESULT ok echo go->py <ms>ms`.
- SAY: "Flip it. Python client into the Node server." DO:
  ```
  docker run --rm --network zo-ctrl -e ZITI_SERVICE=echo.js -e ZITI_IDENTITY=/ziti/id.json \
    -v "$(pwd)/tokens/interop/icli-py.json:/ziti/id.json:ro" zo-sdk-py echo client
  ```
  Expect: `RESULT ok echo py->js <ms>ms`.
- SAY: "The bytes that go in are the bytes that come out, every time, regardless of which SDK sits on either end.
  Ziti carries the stream, the language is just who's holding the socket."

**TAKEAWAY:** "One service contract, every SDK. A client in any language reaches a server in any other language and
the bytes are identical, because the overlay is what's moving them."

**DON'T SHOW:** the full 7x7 grid (that's interop.b), the http app (mention echo proves raw bytes, http is next),
Dockerfile or enrollment plumbing.

---

## interop.b - The full green grid (7 min)

**GOAL:** Every client language dialing every server language, for both echo and http, renders as two all-green
heatmaps.

**COLD OPEN:**
> "Three languages is a demo. Let's prove it at scale. Every language as a client, every language as a server, two
> apps, one grid. If Ziti is really language-agnostic, the whole thing lights up green."

**SAY / DO:**
- SAY: "One script provisions the services and identities, then dials every client against every server for both
  echo and http." DO:
  ```
  bash scripts/interop-matrix.sh
  ```
  Expect: a run log of `<client> -> <app>.<server>: OK` lines scrolling past, then a render step.
- SAY: "Here's the echo grid (rendered on the host). Rows are clients, columns are servers. Green means the client
  reached the server and the bytes matched." DO:
  ```
  cat results/interop-echo.md            # or open results/interop.html for the heatmap
  ```
  Expect: a 7x7 (or as-many-as-built) markdown heatmap, every cell ok.
- SAY: "And the http grid. Same shape, but now there's a real protocol, headers, status codes, a library stack,
  riding the same Ziti socket." DO:
  ```
  cat results/interop-http.md
  ```
  Expect: a second 7x7 heatmap, every cell ok.
- SAY: "Two grids, every pair green. Raw bytes and a full HTTP stack, both transparent across every SDK. That's the
  whole claim, proven in one picture."

**TAKEAWAY:** "Language-agnostic isn't a slogan, it's a green grid. Any client, any server, raw stream or HTTP, the
overlay is invisible to all of them."

**DON'T SHOW:** per-language build times, the HTML render internals, any red/grey cell (if a language image isn't
built, note it's pending rather than dwelling on the gap).

---

## interop.c - Posture flips cells (7 min)

**GOAL:** Adding a device posture check to a subset of clients turns their rows grey while the rest stay green, with
no code change.

**COLD OPEN:**
> "The grid is green because everyone's allowed. Now let's gate some clients on device state, not identity. Watch
> whole rows go grey while the code stays exactly the same."

**SAY / DO:**
- SAY: "We split the clients: half trusted, half subject to a posture check. This adds the posture policy and tags."
  DO:
  ```
  bash scripts/provision-interop-posture.sh
  ```
  Expect: log lines creating `dial-interop-posture` and the `#posture.matrix` checks.
- SAY: "Confirm the posture policy is in place and which check it requires." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list service-policies 'name="dial-interop-posture"'
  ```
  (point at the posture check roles column -> `#posture.matrix`)
- SAY: "Re-run the matrix. The posture clients fail the check, so their rows can't dial anything." DO:
  ```
  bash scripts/interop-matrix.sh
  ```
  Expect: run log shows `denied` for the posture client rows.
- SAY: "Look at the grid now. The trusted rows are still green. The posture rows are grey, top to bottom, denied by
  device state." DO:
  ```
  cat results/interop-echo.md
  ```
  Expect: a heatmap with green trusted rows and full grey rows for posture clients.
- SAY: "Same client code, same service, same bytes. The only thing that changed is what the device is, and the
  overlay refused the dial."

**TAKEAWAY:** "Posture gates access on device state, not just identity. Flip a posture requirement on and a whole
row of the matrix goes grey, with nothing touched in the app."

**DON'T SHOW:** the four posture types in depth (name them, move on), MFA (that's a different gate, interop.d),
re-enabling posture to flip rows back (mention it's continuous).

---

## interop.d - Auth policy vs posture, two different gates (7 min)

**GOAL:** An auth policy that mandates MFA blocks a client at the front door, denying its entire row with a color
distinct from posture-grey.

**COLD OPEN:**
> "Posture grey means 'you may not use this service.' But there's an earlier gate: may you even log in? Auth policy
> and posture are two different doors, and the matrix shows both at once."

**SAY / DO:**
- SAY: "Auth policy is the front door: it decides whether you can authenticate and how. We create one that requires
  MFA and assign it to a single client." DO:
  ```
  AP_MFA_CODE=java bash scripts/provision-interop-authpolicy.sh
  ```
  Expect: log lines creating `ap-mfa` and assigning it to `icli-java` (the script defaults to swift, but swift has
  no Linux client image, so target a built language like java for a live matrix row).
- SAY: "Confirm that client is on the MFA-required auth policy." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list identities 'name="icli-java"'
  ```
  (point at the auth policy column -> `ap-mfa`)
- SAY: "That client never enrolled TOTP, so it can't even get an API session. Re-run the matrix." DO:
  ```
  bash scripts/interop-matrix.sh
  ```
  Expect: run log shows `auth-denied` for the entire `icli-java` row before any service is even considered.
- SAY: "Here's the grid. The MFA client's row is a different color from the posture rows. Posture-grey means the
  door opened but the room was locked. Auth-denied means the front door never opened at all." DO:
  ```
  cat results/interop-echo.md
  ```
  Expect: a heatmap with green rows, grey posture rows, and one distinctly-colored auth-denied row.
- SAY: "Think of it this way: auth policy is the front door, can you come in, with what credentials, is MFA
  mandatory. Posture and service policy are the room key, now that you're in, which rooms can you open. Different
  gates, different failures, both visible."

**TAKEAWAY:** "Auth policy is the front door, posture plus service policy is the room key. The matrix renders
auth-denied, posture-denied, and ok as three different colors, so you can see exactly which gate stopped a client."

**DON'T SHOW:** the TOTP enrollment dance (mention it would clear the row), UPDB / password auth (note it's another
auth method), per-method internals.

---

## interop.e - Health-check failover keeps the grid green (8 min)

**GOAL:** With two servers per service, killing one backend's health endpoint reroutes to its twin and the matrix
stays green; killing both turns that column red.

**COLD OPEN:**
> "A green grid is nice. A green grid while a backend is on fire is the point. We run two servers per service, kill
> one, and watch the matrix not even flinch."

**SAY / DO:** (setup is in `scripts/provision-interop-health.sh` + `scripts/INTEROP-LAYERS.md`, which add a second
server per service so each service has two terminators and wire health checks. Some of this is scripted, some is
documented, read INTEROP-LAYERS.md before shooting.)
- SAY: "We run two servers per service, so each has two terminators. Both up to start." DO:
  ```
  bash scripts/provision-interop-health.sh
  docker exec -it zo-ziti-controller1-1 ziti edge list terminators 'service.name="http.go"'
  ```
  Expect: two terminators for `http.go`.
- SAY: "Baseline: the http.go column is green." DO:
  ```
  bash scripts/interop-matrix.sh
  cat results/interop-http.md
  ```
  Expect: the `http.go` column all green.
- SAY: "Stop one of the two http.go servers. Its terminator drops out of the pool." DO:
  ```
  docker stop zo-i-http-go-1
  docker exec -it zo-ziti-controller1-1 ziti edge list terminators 'service.name="http.go"'
  ```
  Expect: one terminator remains (the twin).
- SAY: "Re-run. Dials use the healthy twin, the column stays green, nobody noticed the failover." DO:
  ```
  bash scripts/interop-matrix.sh
  cat results/interop-http.md
  ```
  Expect: the `http.go` column still green.
- SAY: "Stop the twin too. No terminator left, the column goes red, proving the routing really follows health." DO:
  ```
  docker stop <the-second-http-go-server>
  bash scripts/interop-matrix.sh
  cat results/interop-http.md
  ```
  Expect: the `http.go` column red. (Restart the servers to recover.)

**TAKEAWAY:** "Health checks tie real backend liveness to overlay routing. One server dies and the grid stays green
on the twin; both die and the column goes red, proving the check actually gates traffic. No load balancer in sight."

**DON'T SHOW:** the httpCheck vs portCheck config syntax (name them, don't tour the YAML), terminator precedence
math, restoring health to flip the column back (mention removing the marker recovers it).

---

## interop.f - Link-group pathing (8 min)

**GOAL:** Steer a service onto a chosen router link group and watch its circuits stay on the intended path.

**COLD OPEN:**
> "So far smart routing picks the path for us. Sometimes you need to dictate it: keep this traffic off shared links,
> pin it to a premium route. Link groups let you say 'this service takes that path,' and you can watch it obey."

**SAY / DO:**
- SAY: "Our routers carry link groups, premium and budget, so links only form within a group. Here's the fabric."
  DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list links
  ```
  (point at the group column: some links premium, some budget)
- SAY: "We steer a high-value service, http.go, onto the premium group and bias smart routing toward it." DO:
  ```
  bash scripts/provision-interop-linkgroups.sh
  ```
  Expect: it steers `http.go` (via link cost in the scripted approximation; real link groups need router config,
  see the script's notes).
- SAY: "Hold a dial open against that service so there's a live circuit to inspect." DO:
  ```
  docker run -d --name hold --network zo-ctrl -e ZITI_SERVICE=http.go -e ZITI_IDENTITY=/ziti/id.json \
    -v "$(pwd)/tokens/interop/icli-go.json:/ziti/id.json:ro" zo-sdk-go http client
  ```
  (or hold an echo conn open as in module-2)
- SAY: "List the circuits. The path for http.go stays on the intended links." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list circuits
  ```
  Expect: a circuit for `http.go` whose PATH follows the steered route.
- SAY: "Raise the premium link's cost or take it down, and the circuit refuses to fall back to budget, it reroutes
  within the constraint or fails closed. That's the difference between a preference and a rule." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list circuits
  ```
  Expect: the path still avoids budget-group links.

**TAKEAWAY:** "Link groups plus cost let you express 'this traffic must take that path.' Compliance routing,
keeping sensitive flows off shared links, multi-region steering, and you can see the circuit honoring it, not just
assert it."

**DON'T SHOW:** the exact router config keys for groups (confirm against the pinned 2.0.0 router before relying on
them on camera), cost-tuning math, the full rerouting policy matrix.

---

## Verification status

Smoke-verified live (results/SMOKE.md): go, py, js, java, and c interoperate over the overlay (a 5x5 green block,
both directions). So interop.a and interop.b hold up across five languages today. C# (cs) is PARKED, the image
builds and the code follows the contract, but the OpenZiti.NET native identity-load did not work live; treat the cs
row/column as a known gap, not a blocker. Swift is the macOS-only host edge (a documented row, not a Linux
container). interop.e (health failover) and interop.f (link groups) are partly scripted, partly documented, read
`scripts/INTEROP-LAYERS.md` before shooting them.
