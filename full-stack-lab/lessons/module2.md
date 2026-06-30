# Module 2 - "How it actually works"

**Stage setup:** `bash scripts/stage.sh module-2` (full lab). Log in first:
`docker exec -it zo-ziti-controller1-1 ziti edge login localhost:1280 -u admin -p admin -y`

---

## module-2.a - The fabric: routers, links, circuits (8 min)

**GOAL:** Routers mesh via links; each dial picks a circuit (a path); you can see it.

**COLD OPEN:**
> "We've been saying 'it goes over the overlay'. Let's actually watch a connection pick its path across the
> network."

**SAY / DO:**
- SAY: "Here are our routers. Each is a node in the mesh." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list routers
  ```
- SAY: "They connect to each other with links. This is the fabric." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list links
  ```
  (point at dialer/acceptor, latency, cost, state=up)
- SAY: "Now the cool part. Open a connection and watch the live circuit it builds." DO: in one terminal hold a
  connection open:
  ```
  docker exec zo-echo-client-1 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2222; sleep 30'
  ```
  in another, list circuits:
  ```
  docker exec -it zo-ziti-controller1-1 ziti fabric list circuits
  ```
  Expect: a circuit with a PATH like `r/home-er -> l/<link> -> r/corp-er`.
- SAY: "That PATH is the actual route your bytes took. Smart routing chooses it by cost and latency, and reroutes
  if a link degrades."

**TAKEAWAY:** "The fabric is a mesh of routers joined by links. Every connection is a circuit, a chosen path, and
the controller can show it to you live."

**DON'T SHOW:** link cost tuning math, terminator strategies (advanced).

---

## module-2.b - Two ways to host a service (7 min)

**GOAL:** A backend can be fronted by a dedicated tunneler OR by a router itself.

**COLD OPEN:**
> "So far our web app was hosted by a little sidecar tunneler. But a router can host a service directly. Let's
> prove it with SSH."

**SAY / DO:**
- SAY: "echo is hosted by a dedicated tunneler identity." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list terminators 'service.name="echo"'
  ```
  (binding = tunnel via the echo-host identity)
- SAY: "ssh is hosted by the corp-er ROUTER itself, no sidecar. Look at its bind policy." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list service-policies 'name="ssh-bind"'
  ```
  (identity roles = @corp-er, the router)
- SAY: "Same overlay, dial ssh, get a real sshd, with zero open ports on that box." DO:
  ```
  docker exec zo-echo-client-1 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2222; head -1 <&3'
  ```
  Expect: `SSH-2.0-OpenSSH_10.2`.

**TAKEAWAY:** "Host a service with a dedicated tunneler when the app box should stay dumb, or let a router host it
when the router already sits next to the resource. Same overlay, your choice at the edge."

**DON'T SHOW:** full ssh login flow (banner is enough), router config internals.

---

## module-2.c - Access control with posture checks (7 min)

**GOAL:** Policies can require device posture, not just identity.

**COLD OPEN:**
> "Identity says *who*. Posture says *what state your device is in*. Watch the same user get allowed to one service
> and denied another, by posture alone."

**SAY / DO:**
- SAY: "We have a service `winonly` gated by a posture check: the client OS must be Windows." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list service-policies 'name="winonly-dial"'
  ```
  (point at the posture check roles column -> #posture.windows)
- SAY: "Our client is Linux. It can dial echo just fine." DO:
  ```
  docker exec zo-echo-client-1 curl -s -o /dev/null -w "echo: %{http_code}\n" http://localhost:8080
  ```
  Expect: `echo: 200`.
- SAY: "But the exact same identity is denied winonly, because it fails the Windows posture check." DO:
  ```
  docker exec zo-echo-client-1 curl -s http://localhost:8081
  ```
  Expect: connection reset / denied.

**TAKEAWAY:** "Posture checks gate access on device state, OS, running process, MAC, domain, even MFA. Same
identity, different posture, different answer."

**DON'T SHOW:** MFA/TOTP enrollment flow (mention it as 'also possible').

---

## module-2.d - Enrollment, the full menu (8 min)

**GOAL:** Identities can come from tokens, passwords, or your existing PKI/CA.

**COLD OPEN:**
> "We've used one-time tokens. But maybe you have usernames, or a corporate CA already issuing certs. OpenZiti
> takes all of it."

**SAY / DO:**
- SAY: "Method 1, OTT, we've seen: mint a token, enroll." (recap one line)
- SAY: "Method 2, UPDB, username and password." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list identities 'name="alice"'
  ```
  (alice exists; created with `--updb alice`)
- SAY: "Method 3, bring your own CA. We generated one with ziti's own PKI tool and registered it." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list cas
  ```
  (point at flags A=autoca, O=ottca, E=auth; any cert this CA signs can auto-enroll)
- SAY: "So enrollment is pluggable: tokens for simple cases, passwords for humans, your CA for fleets that already
  have certs."

**TAKEAWAY:** "OTT, UPDB, and 3rd-party CA, OpenZiti meets your existing identity story instead of replacing it."

**DON'T SHOW:** the full CA verification dance (note it as a follow-up); x509 client cert wiring.
