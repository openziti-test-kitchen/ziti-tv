# Module 1 - "What even is it"

**Stage setup:** `bash scripts/stage.sh module-1` (minimal stack). **Teardown:** `bash scripts/stage.sh down`.

---

## module-1.a - The problem (5 min, no code)

**GOAL:** OpenZiti is a zero-trust overlay; services become "dark" (no inbound ports) and are reached only by
authorized identities.

**COLD OPEN:**
> "Every server you run has a door, an open port, and the entire internet is allowed to walk up and rattle the
> handle. Firewalls and VPNs just move the door. What if there was no door at all?"

**SAY / DO** (slides + one diagram, no terminal):
- SAY: "Here's how we connect things today." DO: show a box `app :443` with arrows from "good user", "scanner",
  "attacker" all reaching the open port.
- SAY: "A VPN doesn't fix this, it just puts you *inside* the network, now you can reach everything." DO: show a
  VPN blob with one user given access to a whole subnet.
- SAY: "OpenZiti flips it. The app makes only OUTBOUND connections, to an overlay. It has no listening port on the
  network at all. It's dark." DO: show the same app with NO inbound arrow, only an outbound line to a cloud labeled
  "Ziti overlay", and a separate authorized identity connecting through that cloud.
- SAY: "Nothing can connect to what it can't even see. Access is per-service, per-identity, default-deny."

**TAKEAWAY:** "OpenZiti makes your services invisible and unreachable, except to cryptographic identities you
explicitly allow. The rest of the series shows how."

**DON'T SHOW:** any command, any component names beyond "overlay". Pure concept.

---

## module-1.b - The five words you need (6 min, diagram-driven)

**GOAL:** Name and define controller, router, identity, service, policy.

**COLD OPEN:**
> "OpenZiti has a reputation for jargon. It's really five nouns. Learn these and every doc suddenly reads fine."

**SAY / DO** (build one diagram, no terminal yet):
- SAY: "**Controller** - the brain. It holds all config and decides who's allowed to do what. It carries no app
  traffic." DO: draw the controller.
- SAY: "**Router** - the muscle. Routers form the mesh that actually carries traffic across the overlay." DO: draw
  two routers linked.
- SAY: "**Identity** - who you are. Every participant, every app, user, device, has a cryptographic identity, a
  cert, not a password-by-default." DO: draw an identity badge.
- SAY: "**Service** - the thing you reach, 'the payroll database', 'the ssh box'. A named destination on the
  overlay." DO: draw a service.
- SAY: "**Policy** - the rules. Which identities may offer a service (Bind) and which may use it (Dial)." DO: draw
  arrows identity -> policy -> service.

**TAKEAWAY:** "Controller decides, routers carry, identities authenticate, services are destinations, policies
connect them. That's the whole model."

**DON'T SHOW:** configs, enrollment types, posture. Just the nouns.

---

## module-1.c - Hello overlay (7 min, minimal stack)

**GOAL:** A running controller + an enrolled router IS an overlay.

**COLD OPEN:**
> "Let's make the smallest possible OpenZiti network, exactly two moving parts, and watch it come alive."

**SAY / DO:**
- SAY: "One command brings up one controller and one router." DO:
  ```
  bash scripts/lesson-up.sh
  ```
  Expect: controller healthy, token minted, router started.
- SAY: "Two containers. That's it." DO:
  ```
  docker ps --format '{{.Names}}\t{{.Status}}' --filter name=zomin-
  ```
  Expect: `zomin-ziti-controller-1` and `zomin-lesson-router-1`, healthy.
- SAY: "Let's talk to the brain." DO:
  ```
  docker exec -it zomin-ziti-controller-1 ziti edge login localhost:1280 -u admin -p admin -y
  docker exec -it zomin-ziti-controller-1 ziti edge list edge-routers
  ```
  Expect: `lesson-router  ONLINE true`.
- SAY: "And there's a web console too." DO: open `https://localhost:1280/zac`, log in admin/admin, show the empty
  network.

**TAKEAWAY:** "A controller and one enrolled router is a working overlay. It just has nothing on it yet, that's
next."

**DON'T SHOW:** HA, multiple routers, the big lab. Two containers only.

---

## module-1.d - Your first dark service (8 min) - the money shot

**GOAL:** Reach a web server that has zero open ports, over the overlay.

**COLD OPEN:**
> "I've got a web server. It has no published ports, you cannot curl it, nmap finds nothing. And I'm about to load
> it in a browser anyway."

**SAY / DO** (minimal stack: `bash scripts/lesson-up.sh` already running from module-1.c):
- SAY: "Add a web server and publish it on the overlay, one command." DO:
  ```
  bash scripts/lesson-echo.sh
  ```
- SAY: "Here's the backend. Notice: no ports column. It's dark." DO:
  ```
  docker ps --filter name=zomin-echo-backend --format '{{.Names}}\t{{.Ports}}'
  ```
  Expect: a name and an EMPTY ports field.
- SAY: "Prove it, try to reach it directly from the host." DO: (nothing is listening)
  ```
  curl -m 3 http://localhost:80    # nothing here
  ```
- SAY: "Now the same thing over Ziti. A client tunneler exposes the service locally." DO:
  ```
  docker exec zomin-echo-client-1 curl -s http://localhost:8080
  ```
  Expect: the whoami response (hostname, headers).
- SAY: "That request never touched an open port. It went app -> tunneler -> router -> tunneler -> app, encrypted
  end to end."

**TAKEAWAY:** "The service was dark the whole time. Only an authorized identity, through the overlay, could reach
it. That's zero trust in one curl."

**DON'T SHOW:** the 6-router mesh, circuits, policies internals. Just dark-in, dial-out.

---

## module-1.e - Who are you? Identities & OTT enrollment (6 min)

**GOAL:** Every participant has a cryptographic identity; enrollment trades a one-time token for a client cert.

**COLD OPEN:**
> "That client was allowed to connect. But allowed how? Nobody typed a password. Let's meet identities."

**SAY / DO:**
- SAY: "Create an identity. We get back a one-time enrollment token, a JWT." DO:
  ```
  docker exec -it zomin-ziti-controller-1 ziti edge create identity demo-user -o /tmp/demo-user.jwt
  docker exec -it zo-ziti-controller1-1 head -c 60 /tmp/demo-user.jwt
  ```
- SAY: "That token is single-use. Enrolling swaps it for a private key and a signed cert, the token is then dead."
- SAY: "Every router, every app, every user is an identity. Let's list them." DO:
  ```
  docker exec -it zomin-ziti-controller-1 ziti edge list identities
  ```
  Expect: routers (type Router), echo-host, echo-client, the admin.

**TAKEAWAY:** "Identity is the foundation, a cert, not a shared secret. OTT is the simplest way to hand one out:
mint a token, enroll, done."

**DON'T SHOW:** UPDB, CA, posture. Just OTT.

---

## module-1.f - Services, configs & policies (9 min)

**GOAL:** A service ties config (where/how) to policy (who); role attributes scale access.

**COLD OPEN:**
> "Access is deny-by-default. So how did our client earn the right to dial echo? Three pieces: a service, its
> config, and a policy."

**SAY / DO:**
- SAY: "A service has two configs. `host.v1` says where the real server is." DO:
  ```
  docker exec -it zomin-ziti-controller-1 ziti edge list configs 'name="echo.host.v1"' -j
  ```
  (point at address/port -> echo-backend:80)
- SAY: "`intercept.v1` says how clients address it, the overlay DNS name and port." DO: show `echo.intercept.v1`
  (echo.ziti:80).
- SAY: "Two policies grant access. Bind = who may HOST. Dial = who may USE." DO:
  ```
  docker exec -it zomin-ziti-controller-1 ziti edge list service-policies 'name contains "echo"'
  ```
  (point at echo-bind #echo.servers, echo-dial #echo.clients)
- SAY: "Those `#hashtags` are role attributes. Tag an identity `#echo.clients` and it's instantly allowed, no
  per-user rule." DO:
  ```
  docker exec -it zomin-ziti-controller-1 ziti edge list identities 'name="echo-client"'
  ```
  (point at the attributes column)

**TAKEAWAY:** "Config says where and how; policy says who; attributes let you grant access to groups, not
individuals. Deny-by-default until a Dial policy says yes."

**DON'T SHOW:** posture-check-roles (tease: "there's a fourth column we'll use later"), the fabric.
