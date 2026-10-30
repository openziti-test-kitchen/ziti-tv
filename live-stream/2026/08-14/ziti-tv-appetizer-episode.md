# The OpenZiti appetizer

https://appetizer.openziti.io exists so trying OpenZiti costs nothing. Put a name in the box and you get an identity
you can come back to; skip it and you get a random one.

This builds your own from `git clone`. Assumes TCP, TLS, DNS, reverse proxies, mTLS. New to OpenZiti's vocabulary:
https://openziti.io/docs/learn/introduction/

Commands are tagged **[ubuntu]** (WSL Ubuntu, repo root), **[pwsh]** (elevated Windows PowerShell), or **[brave]**.
On Linux/macOS it is all one shell.

Need docker with buildx, go 1.25+, and a second browser profile that has never trusted this stack's CA. Two terminals:
T1 for everything, T2 for `docker compose logs -f router`.

---

## 1. Tour the public appetizer

Open https://appetizer.openziti.io/ and submit an email address. The response page hands you a one-time enrollment
token and names the two services that identity can dial: an HTTP endpoint and a reflect server. Download the token.

Poke around while you are there:

- https://appetizer.openziti.io/messages.html — live traffic through the reflect server, from every client on the
  network right now
- https://appetizer.openziti.io/wasm/ — the browser client. Get an identity, connect, send a message, watch it land in
  the feed
- https://appetizer.openziti.io/meta — the instance metadata the page runs on

This appetizer was built and hosted by NetFoundry for OpenZiti use but now you can build your own and learn/grow from it.

---

## 2. Clone and build

```bash
# [ubuntu] nothing up my sleeve
sudo rm -rf /tmp/appetizerdemo
mkdir -p /tmp/appetizerdemo
cd /tmp/appetizerdemo

git clone https://github.com/openziti-test-kitchen/appetizer.git
cd appetizer
grep -q init-ziti-dir docker-compose.yml && echo ok   # see step 4
unset APPETIZER_IMAGE                                  # set with a tag, publishContainer appends its own
./buildWasm.sh
ls -lh http_content/wasm/                              # .wasm ~50mb, .wasm.gz ~8mb, wasm_exec.js
./publishContainer.sh local                            # tags openziti/appetizer:local
```

`buildWasm.sh` is `GOOS=js GOARCH=wasm go build` against the same `sdk-golang` the CLI clients use. Output is
gitignored, so a fresh clone has no working `/wasm/` until this runs. The image build exists because
`openziti/appetizer:latest` predates the browser client.

Both take minutes. Read step 3.

---

## 3. The five terms

- **Controller** — policy and identity authority. REST management API, REST edge client API. No data plane.
- **Edge router** — the data plane. Clients connect *out* to it. Only component with a public port.
- **Identity** — X.509. Enrollment trades a one-time token for a keypair and a signed cert. Controller auth is mutual
  TLS. That matters in step 11.
- **Service** — a name, not an address.
- **Service policy** — who dials, who binds. Here: a dial policy for `#local_demo.clients`, a bind policy for
  `#local_demo.servers`, both on services tagged `#local_demo-services`.

A server binds a service by dialing *out* to a router. It never listens. No inbound socket to scan.

Three containers: `quickstart` (controller, `--no-router`), `router` (configured by this repo — step 12), `appetizer`.

---

## 4. Bring it up

```bash
# [ubuntu] after the image build, never before
export APPETIZER_IMAGE=openziti/appetizer:local
docker compose up -d
docker compose ps    # init-ziti-dir exited 0, other three up
```

`init-ziti-dir` chowns `./.ziti` to uid 2171 and exits; `quickstart` waits on `service_completed_successfully`.
`./.ziti` is a bind mount, docker creates it root-owned, and `openziti/ziti-cli` runs as 2171.

That `up` minted the PKI in `./.ziti` — root CA, intermediate, server certs for controller and router. Delete the
directory, get a different network.

`Up` is not dialable. Dialing before the appetizer binds fails with `service <id> has no terminators`. The ready
signal is `docker compose logs appetizer | grep "listener established"`, one line per service, under a minute.

---

## 5. Trust the CA

The browser client hits the controller's edge client API and opens a WebSocket to the router as the browser. Both certs
come from the CA just generated, and a page cannot skip verification. Untrusted fails with a message naming neither
certs nor the CA. CLI clients enroll instead and carry the CA inside.

Every clone has its own `.ziti` and its own CA. `$APPETIZER_PATH` must be the clone the running stack came from.

```powershell
# [pwsh] elevated. drop any CA from a previous run - a stale one fails exactly like no CA
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -match 'root-ca' | Remove-Item

# UNC path to the clone you just brought up; `wslpath -w .` in that directory prints it
$APPETIZER_PATH = '\\wsl.localhost\Ubuntu\tmp\appetizerdemo\appetizer'
Import-Certificate -FilePath "$APPETIZER_PATH\.ziti\pki\root-ca\certs\root-ca.cert" `
  -CertStoreLocation Cert:\LocalMachine\Root
```

WSL2 forwards localhost, so `*.127.0.0.1.nip.io` reaches the containers from Windows.

Linux — system store for curl, NSS for Chrome/Brave/Edge, both:

```bash
export APPETIZER_PATH=/tmp/appetizerdemo/appetizer
sudo cp "$APPETIZER_PATH/.ziti/pki/root-ca/certs/root-ca.cert" \
  /usr/local/share/ca-certificates/ziti-appetizer-root.crt
sudo update-ca-certificates    # .crt extension required, others skipped
sudo apt install -y libnss3-tools
certutil -d "sql:$HOME/.pki/nssdb" -A -t "C,," -n ziti-appetizer-root \
  -i "$APPETIZER_PATH/.ziti/pki/root-ca/certs/root-ca.cert"
```

macOS:

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain \
  "$APPETIZER_PATH/.ziti/pki/root-ca/certs/root-ca.cert"
```

Step 16 removes it.

---

## 6. Prove it works before you trust it

```bash
# [ubuntu] expect {"browserController":"https://quickstart.127.0.0.1.nip.io:1280","qualifier":"local"}
curl -s http://localhost:18000/meta

# -k deliberate: reachability, not trust
curl -sk https://quickstart.127.0.0.1.nip.io:1280/edge/client/v1/version | head -c 200

# missing this line means 'no edge routers connected in time' later, with no explanation
docker compose logs router | grep -i "starting the edge router"

curl -s https://quickstart.127.0.0.1.nip.io:1280/edge/client/v1/version >/dev/null && echo trusted
```

Then open `https://quickstart.127.0.0.1.nip.io:1280/edge/client/v1/version` in the browser you will use. Padlock, no
warning. The curls prove nothing about it — on Windows they read the Linux store inside WSL while the import went to
the Windows store.

Fix a warning here or every browser failure downstream traces back to it.

---

## 7. The landing page, as a stranger sees it

http://localhost:18000/ — the public site as the `local` instance instead of `prod`.

`/meta` shows the instance prefix. One appetizer per instance name, many sharing one controller, because
`Server.scopedName` prefixes every entity it creates.

The prefix is `OPENZITI_DEMO_INSTANCE`, set to `local` at `docker-compose.yml:81`. Unset, `main.go:20` uses the
hostname. `prod` scopes to nothing — hence bare `reflectService` on the public site, `local_reflectService` here.

Clients never read it. `common.PrefixedName` asks `/meta` (`clients/common/common.go:235`), which is what
`OPENZITI_APPETIZER_URL` in step 8 points at.

Submit a name: the server deletes any identity using it, creates one with the `local_demo.clients` attribute, renders
`add-to-openziti-response.html` with the token id and both service names. `/download-token?token=<identity-id>` returns
the enrollment JWT with a `Content-Disposition` filename.

- "Don't bother me with this right now" → `/add-me-to-openziti?randomizer=true`, generates `randomizer_<8 chars>`. The
  clients look for `randomizer_*.json` in the working directory and reuse it.
- `/getinvite?who=<x>` builds a shareable `/taste?ziti=<base64>` link, same handler.

Names allow letters, digits, `. _ @ + -`, 4-100 chars *after* the prefix — the name doubles as a UPDB username in
step 10.

`underlay/httpServer.go`, at `addToOpenZiti`.

---

## 8. Dial services that have no address

```bash
# [ubuntu]
export OPENZITI_APPETIZER_URL=http://localhost:18000
export DL=/mnt/c/Users/$USER/Downloads    # ~/Downloads on Linux/macOS

# enrolls on first use: .jwt becomes <name>.json beside it, .jwt is deleted
go run clients/reflect.go reflectService "$DL/<name>.jwt"

# these two take the name verbatim - prefix it yourself
go run clients/curlz.go local_httpService "$DL/<name>.json"
go run clients/math.go  local_httpService "$DL/<name>.json" 6 '*' 7

# no identity file: orders one from /sample, reuses randomizer_*.json after
go run clients/reflect.go reflectService
```

`OPENZITI_APPETIZER_URL` points the clients at the local appetizer for the prefix (`/meta`) and, with no identity file,
a token (`/sample`).

The clients disagree on that prefix:

- `reflect.go:18` runs the name through `common.PrefixedName` — pass **`reflectService`**. `local_reflectService`
  yields `local_local_reflectService` and exits not-found.
- `curlz.go:15` and `math.go:18` use the argument verbatim as the URL host — pass **`local_httpService`**.
  `httpService` exits with `service 'httpService' not found`.

`ctx.Dial` reports an end-to-end encrypted connection: encrypted between the two SDK endpoints, so the router forwards
ciphertext it cannot read.

Open http://localhost:18000/messages.html alongside. The reflect server pushes every relayed message to an SSE topic;
that page is an `EventSource` on `/sse`.

Replies say the message "can't be qualified at this time for offensiveness". The reflect server POSTs each line to
`http://classifier-service:80/api/v1/classify` **over the overlay** with a zitified `http.Client`. That service exists
in production, not here, so the dial fails, result is `COULD_NOT_CLASSIFY`, message relays anyway — one dark service
calling another by name. A local `go-away` check runs first and refuses to relay outright.

`curlz` and `math`: `common.NewZitifiedHttpClient` clones `http.DefaultTransport` and swaps `DialContext` for
`ctx.Dial(serviceName)`. URL is `http://httpService/domath?...`. Stock `net/http`, no address, hostname is a service
name.

Reflect reads 1024-byte chunks and closes connections idle over 60 seconds. Clients redial on next send.

`clients/common/common.go`, at `ZitiDialContext`.

---

## 9. The whole server, in about eighty lines

`main.go`: resolve the instance name, `Prepare` the network, start the underlay server on 18000, serve HTTP over a ziti
listener, serve reflect over another, wait for a signal.

`Prepare` is the network as code against the management API: two services sharing a role attribute, a dial policy, a
bind policy, the server identity with the bind role, enroll it, return a `ziti.Config` held in memory. Nothing on disk.
Everything step 8 used came from here at container start.

`CreateZitiListener`: `ctx.ListenWithOptions(serviceName, opts)` returns a `net.Listener` and
`http.Server{}.Serve(listener)` takes it. Stock `net/http`, bound to an overlay service instead of a port. Reflect uses
`AcceptEdge` to read `conn.SourceIdentifier()` — how the messages page knows who sent what, with no application auth.
The identity is the connection.

`OPENZITI_RECREATE_NETWORK` defaults true, so this runs every boot: services and policies deleted and rebuilt,
`local_demo-server` re-enrolled. Restarting the appetizer breaks anything mid-dial. Set it `false` if you need
restarts.

`main.go`, `underlay/httpServer.go`, `overlay/httpServer.go`, `manage/manage.go`.

---

## 10. The same SDK, in a browser tab

http://localhost:18000/wasm/, devtools on Network. No tunneler, no agent, no extension, no proxy.

**Load** downloads `appetizer.wasm` from step 2 — ~8mb over the wire, ~50mb decompressed. `static/precompressed.go`
finds the sibling `.gz` and sends `Content-Encoding: gzip` when accepted. Everything is `Cache-Control: no-cache`, so
rebuilds are picked up. Inside: the OpenZiti golang SDK at `GOOS=js GOARCH=wasm`, the same code step 8 ran.

**Get an Identity** → `/sample-updb` creates an identity, attaches a username/password authenticator directly with no
enrollment, returns JSON. Stored in `localStorage` under `appetizer.wasm.updb`; "Forget Identity" deletes that key.

**Connect** — expand the SDK log pane first. CA certs fetched from the controller, end-to-end encrypted connection to
`local_reflectService`, the service list for this identity.

Send a message. The realtime widget at the page bottom shows it beside the terminal messages — same reflect server,
same SSE topic.

`?name=alice.example` requests a specific name; the landing page's "Try it in your Browser" button carries the typed
name into the same parameter.

`http_content/wasm/app.js`.

---

## 11. Why the browser client is shaped this way

A browser can use any credential that travels *in the request*, and none that must be presented during the TLS
handshake. That governs everything in `clients/wasm/main.go`.

**The credential.** OpenZiti certificate auth is mutual TLS. No JavaScript API attaches a client certificate, so a
certificate identity fails `INVALID_AUTH` from a page however it was obtained — and installing it in the browser's own
store is not a workaround, since no web API installs one and the private key would have to leave the page. Hence
username and password, which the appetizer mints with no IdP to configure. The production answer is OIDC: a bearer
token from an external JWT signer, supported via `edge-apis.NewJwtCredentials`, which needs an `ext-jwt-signer` and
something to fetch the token.

**`pinLegacyAuth`.** A controller advertising OIDC makes the SDK switch to it, and that flow reads an auth request id
from a response *header*. Script sees only headers in `Access-Control-Expose-Headers`, so unless the controller exposes
`auth-request-id` it dead-ends with "could not find auth request id header from authorize endpoint". Legacy auth
returns its token in the body.

**`controllerCaPool`**, from `/.well-known/est/cacerts`. A UPDB identity enrolls nothing, so it carries no CA bundle,
and a wasm build has no system trust store.

**Router trust.** Two layers: the browser opens a WebSocket to the router's `wss` address, then the SDK runs a second
ziti TLS handshake inside it.

The root pool for the inner handshake is not the controller's. `routerTrustPool` trusts Mozilla's root list — present
in wasm only because of the `golang.org/x/crypto/x509roots/fallback` import, since `x509.SystemCertPool` is empty
there — plus the controller's CA bundle. Wrong pool gives `x509: certificate signed by unknown authority`, then `no
edge routers connected in time`.

The client cert for that inner handshake is the **api session certificate** the controller issues during
authentication. `useBrowserTrustForRouters` wraps it in credentials implementing `edge-apis.IdentityProvider`, because
`CtrlClient.GetIdentity` prefers that interface and it is the only hook for the TLS config. It runs *after*
`Authenticate()` — the cert does not exist before. That cert stands in for the one a browser cannot present.

`Options.EdgeRouterUrlFilter` restricts routers to `wss:` so the SDK skips the `tls:` addresses advertised alongside.

**What any network must provide:**

1. An edge router advertising `wss`. `tls:`-only routers are invisible, and plain `ws` will not do — the address parser
   in a `js/wasm` build handles `wss` only.
2. Browser-trusted certs on the edge client API *and* the `wss` address, plus CORS for the page's origin.
3. A `wss` listener that does not demand a client certificate.

Browser-trusted need not mean publicly trusted. This stack satisfies all three with the CA from step 4.

---

## 12. One port doing two jobs

`docker/router.yaml` declares two `edge` listeners on one port: `tls:0.0.0.0:3022` and `wss:0.0.0.0:3022`. The
underlying TLS listener is shared per bind address and picks a config per connection from the ClientHello's ALPN — SDK
clients ask `ziti-edge`, browsers ask `http/1.1` or `h2`. Steps 8 and 10 hit the same port.

The `transport: wss: identity:` block at the bottom is required. Without it the router wraps its identity so every
handshake demands a peer certificate. A browser cannot present one, so the router log says `no client certificate
presented` while the page says `no edge routers connected in time`. Watch both:

```bash
# [ubuntu] T2
docker compose logs -f router
```

It is last in the file because it names certs that enrollment creates, so `router-bootstrap.sh` enrolls with a copy
truncated at `transport:` (`sed '/^transport:/,$d'`).

That script also creates an `edge-router-policy` and a `service-edge-router-policy`. A `--no-router` quickstart creates
neither, since normally its integrated router brings them, and without them every dial fails
`NO_EDGE_ROUTERS_AVAILABLE`.

Addressing: nip.io resolves `*.127.0.0.1.nip.io` to 127.0.0.1, so the host reaches both through published ports, and
compose network aliases point the same names at the containers from inside. The network tells clients where to connect,
so an advertised name has to resolve in both places.

---

## 13. Running your own on a real machine

The name split is the design. Four names on one wildcard: the app on 443, `ctrl.` for SDK clients and enrollment on the
ziti-signed cert, `api.` for browsers on a Let's Encrypt cert via the controller's `alt_server_certs`, and `router.` on
3022 serving ziti on `tls:` and Let's Encrypt on `wss:` — step 12's ALPN split with two issuers behind it.

`OPENZITI_CTRL` is SDK-facing, `OPENZITI_CTRL_PUBLIC` is browser-facing and published by `/meta`. It cannot be
discovered: a controller advertises only its SDK-facing hostname in `/version`, even when reached under another name.
`?ctrl=` on the page tries one without a redeploy.

The appetizer gets its own cert through `certmagic` in `underlay/httpServer.go`, driven by `OPENZITI_DOMAIN`,
`OPENZITI_ACME_EMAIL`, `OPENZITI_CA=prod`. It must own port 443.

Controller and router certs are manual: `lego` on port 80 before the first `up`, then `ZITI_PKI_ALT_SERVER_CERT` and
`ZITI_PKI_ALT_SERVER_KEY`. Renewal wrinkle — the appetizer holds port 80, so the cron job stops it, renews, restarts.

```bash
# [ubuntu] on the public machine. the ALPN probe is the useful one
openssl s_client -connect "router.$DOMAIN:3022" -servername "router.$DOMAIN" -alpn http/1.1 </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer -subject
curl -s "https://appetizer.$DOMAIN/meta"
curl -si "https://api.$DOMAIN:1280/edge/client/v1/version" -H "Origin: https://appetizer.$DOMAIN" \
  | grep -i access-control
```

---

## 14. Break it on purpose

Open `/wasm/` in the browser profile that never trusted the CA. The page says it could not fetch the CA bundle, or gets
past that and stalls on `no edge routers connected in time`. The router log says something else entirely. The page
reports only what the browser told it.

Same message, different cause:

```bash
# [ubuntu]
docker compose stop router
# connect from the page, then
docker compose start router
```

Failures here are certificate trust, ALPN, or a missing policy. The client-side message is the least informative
artifact available.

---

## 15. What's next: AI-shaped services

There is a written plan for this. None of the files it names exist in the repo yet.

It adds two dark services beside `httpService` and `reflectService`: `llmService`, an OpenAI-compatible chat endpoint
on `llm-gateway`, and `mcpService`, an MCP endpoint aggregating tools on `mcp-gateway`. No public IP, no open port, no
API key to leak — nothing on the internet reaches it, your agent does.

Phase 1: a new `overlay/proxyServer.go` binds the service and reverse-proxies to a loopback sidecar,
`FlushInterval = -1` since chat completions and MCP are both SSE. Avoids pulling zrok, the Agora SDK and a second
`sdk-golang` pin into a module that also builds for wasm.

Client side: a `clients/llmproxy.go` on `127.0.0.1:8080` forwarding over the overlay so unmodified OpenAI clients work,
and a `clients/mcp.go` stdio-to-overlay bridge so a few lines of `mcpServers` config give an agent tools on an endpoint
with no address.

Phase 3: a `ziti:` transport contributed upstream to both gateways beside their zrok and Agora paths, making the
appetizer's wiring deletable.

Named risk: every identity the appetizer ever minted can dial these, and identities go to anyone who asks. Hence
`dummy-model` by default and MCP tools allowlisted read-only.

---

## 16. Tear it down

```bash
# [ubuntu] the stack and the whole PKI
docker compose down
sudo rm -rf .ziti
```

```powershell
# [pwsh] elevated
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -match 'root-ca' | Remove-Item
```

```bash
# linux
certutil -d "sql:$HOME/.pki/nssdb" -D -n ziti-appetizer-root
sudo rm /usr/local/share/ca-certificates/ziti-appetizer-root.crt && sudo update-ca-certificates
```

macOS: Keychain Access.

Every identity minted here died with `./.ziti`. The token from step 1 is still live — that one is on someone else's
network.

---

## Troubleshooting

**`quickstart-1` exits with `mkdir /ziti/pki: permission denied`.** Old `docker-compose.yml`, no `init-ziti-dir`. Fix:
`git pull`, or `mkdir -p .ziti && sudo chown -R 2171:2171 .ziti`.

**`invalid tag "openziti/appetizer:local:local"`.** `APPETIZER_IMAGE` exported with a tag before the build. Fix:
`unset APPETIZER_IMAGE`, build, export.

**`/wasm/` cannot load `appetizer.wasm`.** `./buildWasm.sh` not run, or run after the image build. Fix:
`./buildWasm.sh`, `./publishContainer.sh local`, recreate the container.

**The page cannot fetch the CA bundle.** Root CA not in the OS store, or `./.ziti` regenerated after the import. Fix:
re-import, restart the browser.

**A root CA from a previous run is still installed.** Identical symptom to no CA. Fix: remove, import the current one.

**No padlock, and the installed CA's thumbprint matches the one on disk.** You are comparing against a different clone
than the one that is running. Each clone mints its own CA in its own `.ziti`. Confirm which one the stack came from,
then compare that CA against the store:

```powershell
# [pwsh] on disk, in the clone the stack is running from
$disk = New-Object Security.Cryptography.X509Certificates.X509Certificate2 `
  "$APPETIZER_PATH\.ziti\pki\root-ca\certs\root-ca.cert"
$disk.Thumbprint

# in the store
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -match 'root-ca' |
  Format-List Thumbprint, Subject, NotAfter
```

If they differ, remove and re-import from the right path, then fully quit the browser and reopen. If they match, the
CA is not the problem — check the leaf's SANs:

```bash
# [ubuntu]
openssl s_client -connect quickstart.127.0.0.1.nip.io:1280 \
  -servername quickstart.127.0.0.1.nip.io </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates -ext subjectAltName
```

**`no edge routers connected in time`.** Three causes, one message: the browser rejected the router's `wss` cert, the
advertised name is not in that cert, or the router is down. Fix: ALPN probe, `docker compose logs router`.

**`no client certificate presented` in the router log, page says no edge routers.** The `transport: wss: identity:`
block did not apply. Fix: confirm it is present and last in `docker/router.yaml`, recreate the router.

**`INVALID_AUTH` using a `.jwt` identity in the browser.** Certificate auth is mutual TLS. Not a bug — it is why
`/sample-updb` exists.

**`could not find auth request id header from authorize endpoint`.** The SDK took the OIDC path and CORS hides the
header. `pinLegacyAuth` prevents this, so the binary predates it. Fix: `./buildWasm.sh`.

**`x509: certificate signed by unknown authority`.** Stale `./.ziti` against a fresh controller, or the wrong root
pool. Fix: `docker compose down`, `sudo rm -rf .ziti`, up, import the new root.

**The wasm download crawls, or shows 50mb transferred.** The `.gz` sibling is missing, or something other than the
appetizer is serving — `python3 -m http.server` sends the raw binary. Fix: check `http_content/wasm/appetizer.wasm.gz`,
serve through the appetizer.

**Old behavior after a rebuild.** `Cache-Control: no-cache` still allows a conditional request, so a truly stale
response means a service worker, a proxy, or a static server setting its own headers. Fix: hard reload, disable cache
in devtools.

**`service name [local_local_reflectService] was not found`.** `reflect.go` prefixes for you and the prefixed name was
passed. Fix: `go run clients/reflect.go reflectService <identity-file>`.

**`service 'httpService' not found` from curlz or math.** Those two do not prefix — `curlz.go:15` and `math.go:18` take
the argument verbatim. Fix: pass `local_httpService`.

**`NO_EDGE_ROUTERS_AVAILABLE`.** No `edge-router-policy` or `service-edge-router-policy`. `router-bootstrap.sh` creates
both — check the router got past its login loop.

**`unable to dial service '<name>' (dial failed: service <id> has no terminators)`.** Nothing is bound. Either the
appetizer has not finished starting, or it is not running. Fix: wait for
`docker compose logs appetizer | grep "listener established"` to show one line per service. Under a minute from
`compose up` on a warm machine.

**Everything was working, now every client is broken.** The appetizer restarted and `OPENZITI_RECREATE_NETWORK`
defaults true. Fix: reconnect, set it `false`.

**Reflect drops after a pause.** 60-second idle timeout. Next message redials.

**Replies say "can't be qualified at this time for offensiveness".** No classifier service on this overlay. Expected.

**`quickstart.127.0.0.1.nip.io` does not resolve.** A resolver stripping private answers as rebinding protection. Fix:
`127.0.0.1 quickstart.127.0.0.1.nip.io router.127.0.0.1.nip.io` in hosts.

**Token file not where the client expects it.** Browser downloaded to Windows, client runs in WSL. Fix:
`/mnt/c/Users/<you>/Downloads/<name>.jwt`.

**The appetizer 404s its own pages.** It serves `http_content` relative to the working directory. Fix: run from the
repo root.

**`/messages` blank, `/messages.html` fine.** `/messages` serves `./messages.html` relative to the working directory;
the static handler serves the copy under `http_content`. Use `/messages.html`.

**The published image has no browser client.** `openziti/appetizer:latest` predates it. Fix: `./publishContainer.sh
local`, `APPETIZER_IMAGE=openziti/appetizer:local`.
