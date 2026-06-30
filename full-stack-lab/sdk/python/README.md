# Python SDK programs for the interop matrix (`zo-sdk-py`)

App-embedded zero trust with the official Python SDK: github.com/openziti/ziti-sdk-py (the `openziti` package on
PyPI). No tunneler, no open host ports. Servers bind a Ziti service by name, clients dial/GET it by name. The
identity is an already-enrolled identity JSON. These programs do NOT enroll.

## Layout

```
sdk/python/
  entrypoint.py     # dispatches on APP (echo|http) ROLE (server|client)
  echo/server.py    echo/client.py
  http/server.py    http/client.py
  Dockerfile        # one image, args select APP + ROLE
  README.md
```

## Build

```bash
docker build -t zo-sdk-py sdk/python
```

## Run

One image, two positional args: `APP` (`echo` or `http`) and `ROLE` (`server` or `client`). Configuration is by
environment variable.

| Env | Meaning | Default |
|---|---|---|
| `ZITI_IDENTITY` | path to the enrolled identity JSON | `/ziti/id.json` |
| `ZITI_SERVICE` | Ziti service to bind (server) or dial (client) | (required) |
| `SELF_LANG` | language tag baked into responses | `py` |

```bash
# echo server hosting service echo.py
docker run --rm -v "$PWD/id.json:/ziti/id.json:ro" -e ZITI_SERVICE=echo.py zo-sdk-py echo server

# echo client dialing echo.py
docker run --rm -v "$PWD/id.json:/ziti/id.json:ro" -e ZITI_SERVICE=echo.py zo-sdk-py echo client

# http server hosting service http.py
docker run --rm -v "$PWD/id.json:/ziti/id.json:ro" -e ZITI_SERVICE=http.py zo-sdk-py http server

# http client dialing http.py
docker run --rm -v "$PWD/id.json:/ziti/id.json:ro" -e ZITI_SERVICE=http.py zo-sdk-py http client
```

Clients print exactly one line and set the exit code:

```
RESULT ok   echo py->py 12ms
RESULT fail http py->go connection_refused
```

`TARGET` is the last dotted segment of `ZITI_SERVICE` (so `http.go` reports `py->go`). Exit code is 0 on ok,
non-zero on failure.

## App contracts

- echo server: bind `ZITI_SERVICE`, echo received bytes back, loop forever.
- echo client: dial `ZITI_SERVICE`, send `ping from py\n`, read one line, OK if it matches.
- http server: serve HTTP over a Ziti listener. `GET /` returns 200 JSON `{"lang":"py","host":<hostname>}`.
  `GET /healthz` returns 200 text `ok`.
- http client: HTTP `GET /` over the Ziti connection, OK if 200 and the body parses as JSON.

## SDK calls used (grounded in the SDK samples)

The SDK is a binding over the C SDK. It offers an explicit context API and a `monkeypatch` API. We use whichever
the upstream sample uses for that case.

- `ztx, _ = openziti.load(identity)` loads the enrolled identity and returns a Ziti context. Mirrors
  `sample/ziti-echo-server`.
- echo server: `server = ztx.bind(service)`, `server.listen()`, `server.accept()` returns `(conn, peer)`. The
  conn supports `recv` / `sendall`. From `sample/ziti-echo-server/ziti-echo-server.py`.
- echo client: `with ztx.connect(service) as conn: conn.send(...); conn.recv(...)`. From
  `sample/ziti-echo-server/ziti-echo-client.py` (the sample uses `connect`, the SDK's dial-equivalent).
- http server: `openziti.monkeypatch(bindings={(host, port): dict(ztx=identity, service=service)})` then a plain
  `http.server.HTTPServer`. The `(host, port)` is only an intercept key. No TCP port is opened. The Ziti service
  is hosted instead. From `sample/ziti-http-server/ziti-http-server.py`.
- http client: `with openziti.monkeypatch(): urllib.request.urlopen(f"http://{service}/")`. monkeypatch routes the
  socket over Ziti and resolves the URL host as the Ziti service name. Mirrors `sample/ziti-requests` (which uses
  `requests`). We use stdlib `urllib` to avoid an extra dependency. The pattern is identical.

## Uncertainties

- The upstream echo client sample uses `ztx.connect(service)`, not a top-level `openziti.dial`. We followed the
  sample. If your SDK build exposes `openziti.dial` / `ztx.dial`, it is an alias for the same path.
- The http client relies on monkeypatch resolving the URL host (`http://<service>/`) to the Ziti service. The
  `requests` sample uses a service that looks like a hostname (`demo.service.ziti`). Service names like `http.py`
  should work the same way since the host is matched literally, but this has not been run against a live overlay
  here (no controller/identity available in this build environment).
- `GET /healthz` and the JSON `host` field are our additions to satisfy the interop contract. They are plain
  handler logic on top of the SDK listener, so they carry no extra SDK risk.
- Only the Docker image build is verified in this environment. End-to-end dialing requires an enrolled identity
  and a running OpenZiti network, which are provisioned by the matrix harness, not here.
