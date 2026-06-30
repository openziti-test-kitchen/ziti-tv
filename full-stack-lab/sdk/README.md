# Echo over OpenZiti: app-embedded SDK examples

These examples show **app-embedded zero trust**: your application links an OpenZiti SDK and dials or binds a Ziti
service directly. There is **no tunneler**, no sidecar, and no open inbound ports on the host. The app authenticates
with an enrolled identity and all traffic rides the OpenZiti overlay.

> Not yet verified: none of the code in this directory has been compiled, run, or tested. Treat every file as a
> starting sketch. Go and Python are the most complete. The others are best-effort and are marked at the top with a
> `SCAFFOLD: verify against the current <sdk> API` comment.

## App-embedded SDK vs tunneler

| Aspect            | App-embedded SDK                                  | Tunneler                                         |
| ----------------- | ------------------------------------------------- | ------------------------------------------------ |
| Where Ziti runs   | Inside your process, linked as a library          | A separate process or service on the host        |
| Open ports        | None. The app dials and binds over the overlay    | Usually intercepts a loopback or local port      |
| Identity          | The app loads the identity JSON directly          | The tunneler loads the identity                  |
| Code changes      | Your app calls SDK dial and bind APIs             | App is unchanged, uses normal sockets            |
| Best for          | Learning the SDK, fully embedded zero trust apps  | Retrofitting existing apps without code changes  |

## Pinned versions

- OpenZiti: 2.0.0
- The controller is reachable in-overlay and a service named `echo` already exists in the lab.

## Enroll an identity

Each app instance needs its own enrolled identity. From a host with the `ziti` CLI and admin access to the
controller, run:

```bash
# Create an identity and emit a one-time enrollment token (JWT)
ziti edge create identity sdk-echo -o sdk-echo.jwt

# Enroll the token to produce the identity JSON the SDK will load
ziti edge enroll sdk-echo.jwt -o sdk-echo.json
```

The resulting `sdk-echo.json` holds the identity's keys and the controller address. Every example reads its path from
the `ZITI_IDENTITY` environment variable:

```bash
export ZITI_IDENTITY=/path/to/sdk-echo.json    # bash
$env:ZITI_IDENTITY = "C:\path\to\sdk-echo.json" # PowerShell
```

For a real deployment you would create two identities (one for the server, one for the client) and grant each the
appropriate bind or dial permission via service policies. For this lab a single identity with both bind and dial
permissions on `echo` is the simplest path.

## The service contract

- Service name: `echo`
- **Server**: binds (hosts) the `echo` service, accepts connections, and echoes back every byte it receives.
- **Client**: dials the `echo` service, sends a line of text, and prints the reply.

The service must allow the server identity to bind and the client identity to dial. In the lab the `echo` service and
its policies are already configured.

## Languages and official SDKs

| Language          | Official SDK repository                  | Status in this lab        |
| ----------------- | ---------------------------------------- | ------------------------- |
| Go                | github.com/openziti/sdk-golang           | Most complete             |
| Python            | github.com/openziti/ziti-sdk-py          | Most complete             |
| C#                | github.com/openziti/ziti-sdk-csharp      | Scaffold, verify API      |
| Java              | github.com/openziti/ziti-sdk-jvm         | Scaffold, verify API      |
| JavaScript / Node | github.com/openziti/ziti-sdk-nodejs      | Scaffold, verify API      |
| C                 | github.com/openziti/ziti-sdk-c           | Scaffold, verify API      |
| Swift             | github.com/openziti/ziti-sdk-swift       | Scaffold, verify API      |

Open the subdirectory for your language. Each has its own README with the exact dependency to add and the run
commands, plus an echo client and echo server source sketch.
