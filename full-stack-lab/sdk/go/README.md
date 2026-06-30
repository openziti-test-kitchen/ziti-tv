# Go interop programs (sdk-golang)

Go implementation of the polyglot interop matrix. Four programs (echo server/client, http server/client) built into
ONE image `zo-sdk-go`. App-embedded zero trust with the official Go SDK `github.com/openziti/sdk-golang/v2`. No
tunneler, no host ports: every program binds or dials a Ziti SERVICE by name using an already-enrolled identity JSON.

## Layout

```
sdk/go/
  echo/server   echo/client
  http/server   http/client
  internal/zo   shared env + context + RESULT-line helpers
  entrypoint.sh dispatches on APP/ROLE
  Dockerfile    one image, slim final stage
```

## Contract

One image. Entrypoint takes two args: `APP` (echo|http) and `ROLE` (server|client).

Environment:

- `ZITI_IDENTITY` path to the enrolled identity JSON (default `/ziti/id.json`)
- `ZITI_SERVICE` Ziti service name to bind (server) or dial (client)
- `SELF_LANG` defaults to `go`, used by the http server in its JSON body

Behavior:

- echo server: bind `ZITI_SERVICE`, echo bytes back per accepted connection, run forever.
- echo client: dial `ZITI_SERVICE`, send `ping from go\n`, read one line, OK when it matches.
- http server: serve HTTP over the Ziti listener. `GET /` returns 200 JSON `{"lang":"go","host":<hostname>}`,
  `GET /healthz` returns 200 `ok`.
- http client: HTTP `GET /` over the Ziti connection, OK when status is 200 and the body parses as JSON.

Clients print EXACTLY one stdout line and set the exit code:

```
RESULT ok <APP> go-><TARGET> <ms>ms      # success, exit 0
RESULT fail <APP> go-><TARGET> <reason>  # failure, exit non-zero
```

`TARGET` is the last dotted segment of `ZITI_SERVICE` (`echo.py` -> `py`).

## Build

```bash
docker build -t zo-sdk-go sdk/go
```

The base image is `golang:1.23-bookworm` as required by the contract, but sdk-golang v1.9.0 declares `go 1.25.0`. The
Dockerfile sets `GOTOOLCHAIN=auto` so the go command transparently downloads the newer toolchain at build time while
keeping the pinned base image. The build also runs `go mod tidy` (idempotent here since `go.sum` is committed).

## Run

The identity JSON must already be enrolled. Mount it and pass APP/ROLE:

```bash
# echo server hosting echo.go
docker run --rm -e ZITI_SERVICE=echo.go \
  -v /path/to/srv-go.json:/ziti/id.json zo-sdk-go echo server

# echo client dialing echo.py
docker run --rm -e ZITI_SERVICE=echo.py \
  -v /path/to/cli-go.json:/ziti/id.json zo-sdk-go echo client

# http server / client likewise
docker run --rm -e ZITI_SERVICE=http.go \
  -v /path/to/srv-go.json:/ziti/id.json zo-sdk-go http server
docker run --rm -e ZITI_SERVICE=http.js \
  -v /path/to/cli-go.json:/ziti/id.json zo-sdk-go http client
```

## Module deps

`go.mod` (direct require):

```
module github.com/netfoundry/zo-sdk-go
go 1.25.0
require github.com/openziti/sdk-golang v1.9.0
```

`go mod tidy` has been run, so `go.mod` lists the full indirect set and `go.sum` is committed. The latest stable SDK
release line is published under the bare module path `github.com/openziti/sdk-golang`, so imports are
`github.com/openziti/sdk-golang/ziti`. The `go` directive is `1.25.0` because sdk-golang v1.9.0 requires it (see the
build note below about the toolchain).

## SDK calls used

- `ziti.NewConfigFromFile(path)` load the enrolled identity JSON.
- `ziti.NewContext(cfg)` build the authenticated overlay context.
- `ctx.Listen(service)` bind/host a service, returns a standard `net.Listener`. Used by both servers. The http server
  hands that listener straight to `http.Serve`.
- `ctx.Dial(service)` dial a service, returns a standard `net.Conn`. Used by the echo client directly, and by the http
  client through a custom `http.Transport.DialContext` that maps the URL host to the service name.
- `ctx.Close()` teardown.

These mirror the upstream `simple-server` and `curlz` examples.

## Things I was unsure about

- Module version: upstream `main` declares the module path `github.com/openziti/sdk-golang/v2`, but the only thing
  published under `/v2` on the module proxy is `v2.0.0-pre1` (a pre-release). The latest STABLE release is `v1.9.0`
  under the bare path `github.com/openziti/sdk-golang`, so that is what is pinned here. If you want the v2 line, switch
  the require to `github.com/openziti/sdk-golang/v2 v2.0.0-pre1` and the imports to `.../v2/ziti`.
- `ctx.Listen` vs `ctx.ListenWithOptions`: the upstream http example uses `ListenWithOptions` with a connect timeout
  and max-connections. Plain `Listen` is sufficient for this contract, so that is what is used here.
- TLS verification on the http client: the upstream `curlz` example sets `InsecureSkipVerify`. It is not needed here
  because the request is plain `http://` over the already-encrypted overlay (no TLS layer to verify), so it is omitted.
- `CGO_ENABLED=0`: sdk-golang builds pure-Go in this configuration. If a future version pulls in a cgo-only
  dependency, drop that env and add a C toolchain to the build stage.
