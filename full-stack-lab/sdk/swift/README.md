# Swift: echo + http over OpenZiti (ziti-sdk-swift)

App-embedded zero trust with the official OpenZiti Swift SDK, `CZiti`
(github.com/openziti/ziti-sdk-swift). Each program binds or dials a Ziti service
by NAME over the overlay using an enrolled identity JSON. No tunneler, no host
ports, no enrollment in the program.

This is the Swift entry in the polyglot interop matrix. It delivers the same four
programs every language delivers (echo server, echo client, http server, http
client) plus a Package.swift, a Dockerfile, and this README.

## Platform constraint (read this first)

The Swift SDK is the one matrix entry that does NOT run as a Linux container.

`CZiti` is distributed only as a binary `.xcframework` built for Apple platforms
(macOS and iOS), via github.com/openziti/ziti-sdk-swift-dist as a SwiftPM
`binaryTarget`. It wraps `ziti-sdk-c`, but there is no Linux slice in the
published artifact. Consequently:

- On macOS: these programs build with SwiftPM and run as a host edge.
- On Linux (the Dockerfile path): `swift build` resolves the package but cannot
  link, because the xcframework contains no `linux/x86_64` library. The
  Dockerfile attempts the build anyway so the failure is real and reproducible
  rather than faked. If and when CZiti ships a Linux slice, the same Dockerfile
  should start producing a working `zo-sdk-swift` image with no source changes.

So in the lab, Swift participates as a macOS host edge (run the binaries
directly), while every other language runs as a Linux container. This is called
out honestly rather than papered over.

## The contract (identical across all languages)

- Env: `ZITI_IDENTITY` (path to enrolled identity JSON, default `/ziti/id.json`),
  `ZITI_SERVICE` (the service to bind/dial), `SELF_LANG=swift`.
- `TARGET` = last dotted segment of `ZITI_SERVICE` (e.g. `echo.go` -> `go`).
- echo server: bind `ZITI_SERVICE`, echo bytes back, forever.
- echo client: dial `ZITI_SERVICE`, send `ping from swift\n`, read a line, ok if
  it matches.
- http server: serve HTTP over a Ziti listener on `ZITI_SERVICE`. `GET /` ->
  200 JSON `{"lang":"swift","host":<hostname>}`, `GET /healthz` -> 200 `ok`.
- http client: minimal HTTP `GET /` over the Ziti conn, ok if 200 and the JSON
  body parses.
- Clients print EXACTLY one line and set the exit code accordingly:
  - `RESULT ok <APP> swift-><TARGET> <ms>ms` (exit 0)
  - `RESULT fail <APP> swift-><TARGET> <reason>` (exit non-zero)
- Servers run forever and print no RESULT line.

## Layout

```
sdk/swift/
  Package.swift
  Dockerfile          # attempts Linux build, documents the constraint
  entrypoint.sh       # maps APP ROLE -> executable
  README.md
  Sources/
    Common/Common.swift     # env parsing, RESULT formatting, target()
    EchoServer/main.swift
    EchoClient/main.swift
    HttpServer/main.swift
    HttpClient/main.swift
```

## Build and run on macOS (the supported path)

```sh
cd sdk/swift
swift build -c release

# echo server (hosts the service, runs forever)
export ZITI_IDENTITY=/path/to/srv-swift.json
export ZITI_SERVICE=echo.swift
export SELF_LANG=swift
.build/release/EchoServer

# echo client (from another shell / identity)
export ZITI_IDENTITY=/path/to/cli-swift.json
export ZITI_SERVICE=echo.swift
.build/release/EchoClient
# -> RESULT ok echo swift->swift 12ms
```

Or via the same entrypoint the image uses:

```sh
BINDIR=.build/release ./entrypoint.sh echo server
BINDIR=.build/release ./entrypoint.sh http client
```

http programs are identical except `ZITI_SERVICE=http.<lang>` and the executables
`HttpServer` / `HttpClient`.

## Docker (attempted, expected to fail on Linux)

```sh
docker build -t zo-sdk-swift sdk/swift
```

This will fail at `swift build` / link time on Linux for the reason above. The
log makes the missing Linux slice explicit. Do not treat the failure as a bug in
this code: it is the documented SDK platform limitation.

## SDK calls used (verified against lib/Ziti.swift and lib/ZitiConnection.swift)

- `Ziti(fromFile:)` loads the enrolled identity from JSON.
- `ziti.run { (err: ZitiError?) in ... }` starts the run loop. `CZiti` is not
  threadsafe: all Ziti operations run on this thread (use `ziti.perform` to hop
  onto it from elsewhere).
- `ziti.createConnection() -> ZitiConnection?` makes a connection object.
- Server: `conn.listen(service, onListen: ListenCallback, onClient:
  ClientCallback)`, then in `onClient` call `client.accept(onConn:, onData:)`.
- Client: `conn.dial(service, onConn: ConnCallback, onData: DataCallback)`.
- I/O: `conn.write(data, onWrite: WriteCallback)` and `conn.close(_:)`.
- `DataCallback = (conn, data: Data?, status: Int) -> Int`. A negative `status`
  signals error/EOF, which is how both clients detect a closed stream. `data` is
  a Foundation `Data?`.
- `Ziti.ZITI_OK` is the success constant compared against callback statuses.

## Implementation notes

- The http server hand-builds the HTTP/1.1 response (the SDK exposes a raw byte
  stream on the listen side, not a Foundation listener), parses only the request
  line, and replies `Connection: close`.
- The http client writes a raw `GET /` and validates 200 plus a JSON object body
  via `JSONSerialization`.
- Both clients arm a 15s watchdog so a dead or denied service fails the cell
  instead of hanging.

## Uncertainties

- Pinned CZiti version is `0.41.55` from `ziti-sdk-swift-dist`. The product name
  is `CZiti`. Confirm the latest tag and checksum before a release build.
- The `DataCallback` negative-status convention follows `ziti-sdk-c` (for example
  `ZITI_EOF`). If a future CZiti changes the sign or type of that status, adjust
  the `len < 0` checks.
- `ProcessInfo.hostName` is used for the http server `host` field. Swap to
  `gethostname` if you need the bare hostname without the local domain suffix.
- Not compiled here (no macOS toolchain in this Windows repo). The sources match
  the published CZiti API but should be built once on a Mac before relying on
  them in the matrix.
