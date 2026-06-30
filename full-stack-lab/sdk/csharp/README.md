# C# / .NET 8 - OpenZiti interop matrix node

App-embedded zero trust with the official C# SDK (`OpenZiti.NET` / `OpenZiti.NET.native` NuGet packages).
No tunneler, no open ports. Bind and dial by Ziti service name using an enrolled identity JSON.

## Files

| File | Purpose |
|---|---|
| `ZoSdk.csproj` | SDK-style project, targets `net8.0`, pulls `OpenZiti.NET` + `OpenZiti.NET.native` |
| `Program.cs` | Entrypoint, dispatches on `APP ROLE` args |
| `Env.cs` | Reads `ZITI_IDENTITY`, `ZITI_SERVICE`, derives `TARGET` |
| `EchoServer.cs` | Binds service, echoes bytes, accepts in a loop |
| `EchoClient.cs` | Dials service, sends `ping from cs\n`, asserts echo |
| `HttpServer.cs` | Kestrel over a Ziti listener: `GET /` JSON, `GET /healthz` |
| `HttpClient.cs` | `SocketsHttpHandler` + `ZitiContext.NewZitiSocketHandler`, HTTP GET / |
| `Dockerfile` | Single image `zo-sdk-cs`; entrypoint selects app/role at runtime |

## Build

```bash
docker build -t zo-sdk-cs sdk/csharp
```

## Run

```bash
# Echo server
docker run --rm \
  -v /path/to/srv-cs.json:/ziti/id.json:ro \
  -e ZITI_SERVICE=echo.cs \
  -e SELF_LANG=cs \
  zo-sdk-cs echo server

# Echo client (dial echo.go server)
docker run --rm \
  -v /path/to/cli-cs.json:/ziti/id.json:ro \
  -e ZITI_SERVICE=echo.go \
  zo-sdk-cs echo client

# HTTP server
docker run --rm \
  -v /path/to/srv-cs.json:/ziti/id.json:ro \
  -e ZITI_SERVICE=http.cs \
  -e SELF_LANG=cs \
  zo-sdk-cs http server

# HTTP client
docker run --rm \
  -v /path/to/cli-cs.json:/ziti/id.json:ro \
  -e ZITI_SERVICE=http.go \
  zo-sdk-cs http client
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `ZITI_IDENTITY` | `/ziti/id.json` | Path to enrolled identity JSON inside the container |
| `ZITI_SERVICE` | (required) | Ziti service name to bind (server) or dial (client) |
| `SELF_LANG` | `cs` | Language tag included in the HTTP server JSON response |

## Output contract

Clients print exactly one line to stdout:

```
RESULT ok <app> cs-><target> <ms>ms
RESULT fail <app> cs-><target> <reason>
```

`<target>` is the last dotted segment of `ZITI_SERVICE` (e.g. `echo.go` -> `go`).
Exit code 0 on success, non-zero on failure.

## SDK calls used

| Call | Location | Purpose |
|---|---|---|
| `new ZitiContext(string identityFile)` | `EchoServer`, `EchoClient`, `HttpServer`, `HttpClient` | Load enrolled identity and create native context |
| `new ZitiSocket(SocketType.Stream)` | `EchoServer`, `EchoClient`, `HttpServer` | Allocate a Ziti socket handle |
| `API.Bind(socket, ctx, service, "")` | `EchoServer`, `HttpServer` | Bind (host) the service - server side |
| `API.Listen(socket, backlog)` | `EchoServer`, `HttpServer` | Mark socket as accepting |
| `API.Accept(socket, out caller)` | `EchoServer`, `HttpServer` | Blocking accept, returns a new `ZitiSocket` |
| `API.Connect(socket, ctx, service, "")` | `EchoClient` | Dial (connect) the service - client side |
| `ZitiSocket.ToNetworkStream()` | `EchoServer`, `EchoClient` | Wraps the socket in a `NetworkStream` for `StreamReader`/`StreamWriter` |
| `ZitiContext.NewZitiSocketHandler(service)` | `HttpClient` | Returns a `SocketsHttpHandler` with a Ziti `ConnectCallback` |

## Native dependency

`OpenZiti.NET.native` ships a prebuilt `ziti4dotnet.so` for `linux-x64` inside its NuGet package.
`dotnet publish -r linux-x64` copies it to `runtimes/linux-x64/native/`. The `aspnet:8.0`
base image provides `glibc`, `libssl`, and `libcrypto`, which are the native deps.
`LD_LIBRARY_PATH=/app/runtimes/linux-x64/native` is set in the Dockerfile as a belt-and-suspenders
measure in case the CLR probing path does not resolve the `.so` automatically.

## Uncertainties / known constraints

1. **`OpenZiti.NET` NuGet version**: the project pins `1.0.*` for the managed package. The package on
   NuGet.org may lag the GitHub source. If the version resolution fails during `docker build`, pin to
   whatever `dotnet search OpenZiti.NET` reports as latest.

2. **HTTP server transport**: `HttpServer.cs` inlines a minimal Kestrel transport (no Kestrel
   `ZitiEndPoint` extension from the samples project is vendored). The pattern mirrors
   `ZitiConnectionListenerFactory` from the upstream samples verbatim. If the `SocketConnectionContextFactory`
   API shape changes across patch versions of `Microsoft.AspNetCore.App`, adjust the factory options ctor.

3. **`API.Accept` blocking**: the echo server calls `API.Accept` on the main loop thread and offloads
   each connection to a `Task.Run`. The HTTP server uses a `Socket.Poll` inside `AcceptAsync` to stay
   cancellation-friendly with Kestrel. Both patterns are lifted directly from upstream samples.

4. **ARM64 / linux-arm64**: `OpenZiti.NET.native` ships a linux-x64 native asset. ARM64 images will
   fail to load `ziti4dotnet.so` unless NetFoundry publishes an arm64 build of the native wrapper.
   Build the image with `--platform linux/amd64` when running on ARM64 hosts.
