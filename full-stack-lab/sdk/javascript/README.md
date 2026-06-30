# JavaScript / Node: interop-matrix programs over OpenZiti

App-embedded zero trust with the official Node SDK: `@openziti/ziti-sdk-nodejs`
(github.com/openziti/ziti-sdk-nodejs). The SDK is a native N-API addon over the C
SDK and is callback based. No tunneler, no open ports: every bind and dial is by
Ziti SERVICE NAME using an already-enrolled identity JSON. These programs do NOT
enroll.

## Deliverables

```
sdk/javascript/
  common.js          shared config + RESULT-line helpers
  entrypoint.js      dispatch on APP (echo|http) ROLE (server|client)
  echo/server.js     bind ZITI_SERVICE, echo bytes back, forever
  echo/client.js     dial ZITI_SERVICE, send "ping from js\n", read a line
  http/server.js     serve HTTP over a Ziti listener (ziti.express)
  http/client.js     HTTP GET / over the Ziti conn (ziti.httpAgent)
  package.json       deps: @openziti/ziti-sdk-nodejs, express
  Dockerfile         builds one image, zo-sdk-js
```

## The contract

One image. Entrypoint args select the program:

```
node entrypoint.js <APP> <ROLE>     APP = echo|http   ROLE = server|client
```

Environment:

- `ZITI_IDENTITY`: path to the enrolled identity JSON (default `/ziti/id.json`)
- `ZITI_SERVICE`: the Ziti service name to bind (server) or dial (client)
- `SELF_LANG`: language tag put in the http server response (default `js`)

Clients print EXACTLY one line and set the exit code:

```
RESULT ok   <APP> js-><TARGET> <ms>ms      exit 0
RESULT fail <APP> js-><TARGET> <reason>     exit non-zero
```

`TARGET` is the last dotted segment of `ZITI_SERVICE` (e.g. `echo.go` -> `go`).

## Build

```bash
docker build -t zo-sdk-js sdk/javascript
```

## Run

Mount an enrolled identity at `/ziti/id.json` (or set `ZITI_IDENTITY`).

```bash
# echo server hosting echo.js
docker run --rm -e ZITI_SERVICE=echo.js \
  -v "$PWD/ids/srv-js.json:/ziti/id.json:ro" zo-sdk-js echo server

# echo client dialing echo.go
docker run --rm -e ZITI_SERVICE=echo.go \
  -v "$PWD/ids/cli-js.json:/ziti/id.json:ro" zo-sdk-js echo client

# http server hosting http.js
docker run --rm -e ZITI_SERVICE=http.js \
  -v "$PWD/ids/srv-js.json:/ziti/id.json:ro" zo-sdk-js http server

# http client dialing http.py
docker run --rm -e ZITI_SERVICE=http.py \
  -v "$PWD/ids/cli-js.json:/ziti/id.json:ro" zo-sdk-js http client
```

## SDK calls used

Grounded in the package source (`lib/*.js`, `samples/http-get.mjs`, and the native
`src/ziti_listen.c`), not guessed:

- `ziti.init(identityPath)` returns a Promise that resolves when the identity is
  loaded and the control plane session is up. Every program awaits it first.
- echo client: `ziti.dial(service, isWebSocket, onConnect, onData)`. `isWebSocket`
  is `false` for a raw byte stream. `onConnect(conn)` receives the connection
  handle, `onData(buf)` receives a Buffer. Write with
  `ziti.write(conn, buf, onWrite(status))` and close with `ziti.close(conn)`.
- echo server: `ziti.listen(service, jsArbData, on_listen, on_listen_client,
  on_client_connect, on_client_data)`. The native layer hands the per-client
  callbacks an object: connect gives `{ client, status, js_arb_data }` and data
  gives `{ client, app_data (Buffer), js_arb_data }`. Echo is
  `ziti.write(obj.client, obj.app_data, cb)`.
- http server: `ziti.express(express, service)` returns a wrapped Express app
  whose `app.listen()` binds the Ziti service instead of a TCP port (the port
  argument is ignored). Routes are ordinary Express handlers.
- http client: `ziti.httpAgent(http)` returns an `http.Agent` whose
  `createConnection` dials over the overlay. Standard `http.get(url, { agent },
  cb)` then works, with the service name as the URL host (port ignored).

## Native addon and the image

`@openziti/ziti-sdk-nodejs` is a prebuild-installable native addon. On common
platforms (including linux/amd64) `npm install` downloads a prebuilt binary, so no
compile happens. The Dockerfile still installs `python3 make g++ cmake` so that if
no prebuilt matches the platform, node-gyp / cmake-js can build from source. Base
image is `node:20-bookworm` (the SDK requires Node >= 20).

## Uncertainties

- `ziti.listen` is marked "Internal use only" in the SDK index, but it is the only
  raw-stream hosting primitive exposed and `express-listener.js` consumes exactly
  the callback object shapes used here (`{ client, app_data, ... }`). If a future
  release changes those shapes, the echo server is the file to adjust.
- The `on_listen` status convention (negative means failure) is inferred from the
  other callbacks. A bad bind is also observable as the listener never logging.
- The echo client assumes the reply arrives as one or more data callbacks that
  together contain a newline. It accumulates until the first `\n`, which matches
  the single-line echo contract. A server that never terminates the line would hit
  the 10s client timeout and report `fail ... timeout`.
- `app.listen(0, cb)` passes `0` only for readability. The ziti-wrapped `listen()`
  ignores the port and binds the service name.
- Whether `npm install` pulls a prebuilt vs compiles depends on the published
  release assets for the resolved version and Node ABI. See the build note below.
