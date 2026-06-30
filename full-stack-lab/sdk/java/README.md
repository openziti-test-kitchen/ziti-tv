# Java: echo + http over OpenZiti (ziti-sdk-jvm)

App-embedded zero trust with the official JVM SDK: github.com/openziti/ziti-sdk-jvm. Four programs (echo
server/client, http server/client) compile into ONE image, `zo-sdk-java`. No tunneler, no host ports: every
program binds or dials a Ziti SERVICE by name using an already-enrolled identity JSON.

## Contract

One image. Entrypoint args select the program:

```
docker run ... zo-sdk-java <APP> <ROLE>     # APP=echo|http  ROLE=server|client
```

Environment:

- `ZITI_IDENTITY` path to the enrolled identity JSON (default `/ziti/id.json`)
- `ZITI_SERVICE` the Ziti service name to bind (server) or dial (client)
- `SELF_LANG` defaults to `java`, used in responses and the result line

Clients print EXACTLY one line and exit 0 on success, non-zero otherwise:

```
RESULT ok   <APP> java-><TARGET> <ms>ms
RESULT fail <APP> java-><TARGET> <reason>
```

TARGET is the last dotted segment of `ZITI_SERVICE` (for `echo.go` the target is `go`).

## Behavior

- echo server: binds `ZITI_SERVICE`, echoes received bytes back, loops forever.
- echo client: dials `ZITI_SERVICE`, sends `ping from java\n`, reads one line, OK if it matches.
- http server: serves HTTP/1.1 over the Ziti listener. `GET /` returns 200 JSON
  `{"lang":"java","host":<hostname>}`. `GET /healthz` returns 200 `ok`.
- http client: does `GET /` over the dialed Ziti connection, OK if status 200 and the body is a JSON object.

## Build and run

Build the image:

```
docker build -t zo-sdk-java sdk/java
```

Run a server (long-lived) and a client (one-shot), each with an enrolled identity mounted at `/ziti/id.json`:

```
docker run --rm -e ZITI_SERVICE=echo.java -v /path/srv-java.json:/ziti/id.json zo-sdk-java echo server
docker run --rm -e ZITI_SERVICE=echo.java -v /path/cli-java.json:/ziti/id.json zo-sdk-java echo client
```

Swap `echo` for `http` to exercise the HTTP pair. The identity is NOT enrolled by the program: mint and enroll
it out of band, then mount the resulting JSON.

Local build without Docker (needs JDK 21 and network access to Maven Central):

```
cd sdk/java
gradle clean jar
ZITI_SERVICE=echo.java ZITI_IDENTITY=/path/id.json java -jar build/libs/zo-sdk-java.jar echo client
```

## Dependency / coordinates

Maven Central:

```
org.openziti:ziti:0.34.0
org.slf4j:slf4j-simple:2.0.5
```

`org.openziti:ziti` is the OpenZiti JVM SDK. `slf4j-simple` is just a logging backend so the SDK does not warn
about a missing provider.

## SDK calls used

Grounded in the SDK samples (`samples/sample`, `samples/http-sample`, `samples/sample-host`):

- `Ziti.setApplicationInfo(id, version)` sets the app id reported to the controller.
- `Ziti.newContext(String identityPath, char[] password)` loads the enrolled identity JSON and returns a
  `ZitiContext`. We pass an empty password since the JSON carries the key material.
- `ZitiContext.getStatus()` / `ZitiContext.Status.Active` we poll until the context is `Active` before
  dialing or binding so services are known.
- Client dial: `ZitiContext.dial(String service)` returns a `ZitiConnection`; `write(byte[])` and
  `read(byte[], off, len)` move bytes (these are the blocking convenience methods on `ZitiConnection`).
- Server bind: `ZitiContext.openServer()` returns a `java.nio.channels.AsynchronousServerSocketChannel`;
  `bind(new ZitiAddress.Bind(service))` binds the service name; `accept().get()` yields an
  `AsynchronousSocketChannel` per client, on which we use blocking `read(...).get()` / `write(...).get()`.

The http programs speak raw HTTP/1.1 directly over the Ziti channel rather than using the SDK seamless
`URL`/`HttpURLConnection` interception (`Ziti.init(..., seamless=true)`) shown in `http-sample`. Speaking the
protocol on the raw connection keeps the bind/dial path identical to echo and avoids depending on hostname to
service mapping.

## Uncertainties

- Pinned `org.openziti:ziti:0.34.0` (latest on Maven Central). The SDK sample version catalog still references
  0.27.2. The API used here (`newContext`, `dial`, `openServer`, `ZitiAddress.Bind`, `ZitiConnection`) is present
  on `main` and is stable across these versions, but has not been run end to end against a live controller in
  this repo.
- `ZitiContext.Status.Active` is a Kotlin `object`. The `instanceof` check compiles and works from Java. If a
  future SDK reshapes `Status`, the readiness poll in `Env.java` is the thing to adjust.
- The HTTP server is a minimal one-request-per-connection (`Connection: close`) HTTP/1.1 implementation, enough
  for the matrix contract. It is not a general purpose server (no keep-alive, no request body handling).
- The Dockerfile downloads Gradle 8.10.2 at build time rather than vendoring the wrapper, so the build needs
  network access to `services.gradle.org` and Maven Central.
