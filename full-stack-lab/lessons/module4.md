# Module 4 - "Real edges"

How real clients (laptops, apps) join the overlay, beyond a proxy container.

**Stage setup:** `bash scripts/stage.sh module-4` (full lab). Log in first:
`docker exec -it zo-ziti-controller1-1 ziti edge login localhost:1280 -u admin -p admin -y`.

---

## module-4.a - Dial by name (8 min)

**GOAL:** A tproxy edge intercepts service DNS names, so you dial `http://echo.ziti`, not a local port.

**COLD OPEN:**
> "Real users don't `curl localhost:8080`. They type the real name. Let's make `echo.ziti` resolve and route,
> with nothing but Ziti."

**SAY / DO:**
- SAY: "The `roamer` client runs in tproxy mode. Its `intercept.v1` config says clients reach echo at
  `echo.ziti`." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge list configs 'name="echo.intercept.v1"' -j
  ```
- SAY: "Dial it by name. The tunneler's own DNS resolves `echo.ziti` to an intercept IP and routes it onto the
  overlay." DO:
  ```
  docker exec zo-roamer-1 curl -s http://echo.ziti
  ```
  Expect: the whoami response.
- SAY: "No hosts file, no port mapping. To the app it looks like a normal DNS name, the tunneler does the rest."

**TAKEAWAY:** "Intercept configs + a tproxy edge give you transparent, name-based access, exactly what a desktop
or server tunneler does in production."

**DON'T SHOW:** the docker DNS plumbing (just mention the tunneler runs a resolver).

---

## module-4.b - Your actual laptop (8 min) - needs your host

**GOAL:** Dial a lab service from the real machine using Ziti Desktop Edge (Windows/macOS) or
ziti-edge-tunnel (Linux).

**COLD OPEN:**
> "Containers are cute. Let's dial a dark service from THIS laptop."

**SAY / DO:**
- SAY: "Publish the controller and a public router so the laptop can reach them on the LAN." (point at the
  published ports 1280 / 3022; for a remote laptop you advertise LAN-reachable addresses.)
- SAY: "Create an identity for the laptop and enroll it in the Desktop Edge." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge create identity my-laptop -a echo.clients -o my-laptop.jwt
  ```
  Then: copy the JWT out (`docker cp zo-ziti-controller1-1:/.../my-laptop.jwt .`), add it in Ziti Desktop Edge
  for Windows/macOS (or `ziti-edge-tunnel enroll`), and toggle the identity on.
- SAY: "Now the laptop dials the dark service by name." DO: in a browser/terminal on the laptop: `curl http://echo.ziti`.

**TAKEAWAY:** "The exact same identity model runs natively on Windows, macOS, and Linux, the lab service was dark
the whole time, and your laptop reached it with zero open ports."

**DON'T SHOW:** lab internals; this episode is about the real client. See `docs/edges-host.md` for setup.

---

## module-4.c - No tunneler at all: the SDK (9 min)

**GOAL:** An app can join the overlay directly with an SDK, no tunneler, no sidecar.

**COLD OPEN:**
> "Every demo so far used a tunneler. But your app can speak Ziti natively. Here's the same echo, embedded."

**SAY / DO:**
- SAY: "Enroll one identity for the app." DO:
  ```
  docker exec -it zo-ziti-controller1-1 ziti edge create identity sdk-echo -a echo.servers,echo.clients -o sdk-echo.jwt
  ziti edge enroll sdk-echo.jwt -o sdk-echo.json
  ```
- SAY: "The Go server binds the `echo` service directly, no host.v1, no tunneler." DO: show `sdk/go/server.go`,
  run it with `ZITI_IDENTITY=sdk-echo.json`.
- SAY: "The Go client dials the service name directly from code." DO: run `sdk/go/client.go`, show the echo.
- SAY: "Same pattern exists in Python, C#, Java, Node, C, and Swift, see `sdk/`."

**TAKEAWAY:** "With an SDK the zero-trust boundary moves into your application itself, the most secure option,
no listening port even on localhost."

**DON'T SHOW:** all 7 languages, pick Go (and mention the rest). Note the non-Go scaffolds need API verification.
