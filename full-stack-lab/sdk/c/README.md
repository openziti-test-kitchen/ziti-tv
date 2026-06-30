# C SDK: interop matrix programs

App-embedded zero trust using [ziti-sdk-c](https://github.com/openziti/ziti-sdk-c) 1.x.
No tunneler, no open ports. All connections are Ziti-overlay only.

## Files

| File | Purpose |
|---|---|
| `echo_server.c` | Binds a Ziti service, echoes every received byte back |
| `echo_client.c` | Dials the service, sends `ping from c\n`, verifies the echo |
| `http_server.c` | Binds a Ziti service, speaks HTTP/1.1: `GET /` and `GET /healthz` |
| `http_client.c` | Dials the service, sends `GET /`, validates 200 + JSON body |
| `CMakeLists.txt` | Builds all four binaries; downloads the prebuilt SDK via FetchContent |
| `Dockerfile` | Two-stage build; produces image `zo-sdk-c` |
| `entrypoint.sh` | Dispatches to the right binary by `APP` and `ROLE` args |

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `ZITI_IDENTITY` | `/ziti/id.json` | Path to the enrolled identity JSON |
| `ZITI_SERVICE` | `echo.c` / `http.c` | Ziti service name to bind or dial |
| `SELF_LANG` | `c` | Language tag injected into HTTP responses |

The identity file must already be enrolled before the container starts.
The programs do not run `ziti edge enroll` themselves.

## Docker build and run

```bash
# Build the image (downloads ziti-sdk-c 1.17.1 prebuilt artifact during build)
docker build -t zo-sdk-c sdk/c

# Run echo server
docker run --rm \
  -e ZITI_IDENTITY=/ziti/id.json \
  -e ZITI_SERVICE=echo.c \
  -v /path/to/enrolled-id.json:/ziti/id.json:ro \
  zo-sdk-c echo server

# Run echo client
docker run --rm \
  -e ZITI_IDENTITY=/ziti/id.json \
  -e ZITI_SERVICE=echo.c \
  -v /path/to/enrolled-id.json:/ziti/id.json:ro \
  zo-sdk-c echo client

# Run http server
docker run --rm \
  -e ZITI_IDENTITY=/ziti/id.json \
  -e ZITI_SERVICE=http.c \
  -e SELF_LANG=c \
  -v /path/to/enrolled-id.json:/ziti/id.json:ro \
  zo-sdk-c http server

# Run http client (cross-language: C client -> Go server)
docker run --rm \
  -e ZITI_IDENTITY=/ziti/id.json \
  -e ZITI_SERVICE=http.go \
  -v /path/to/enrolled-id.json:/ziti/id.json:ro \
  zo-sdk-c http client
```

## SDK acquisition

The Dockerfile downloads a prebuilt release artifact during `docker build`:

```
https://github.com/openziti/ziti-sdk-c/releases/download/1.17.1/ziti-sdk-Linux-x86_64.zip
```

The zip is unpacked to `/src/ziti-sdk-prebuilt/` inside the builder stage. CMake is pointed at
it via `-DZITI_SDK_ROOT`. CMakeLists.txt uses `find_path` / `find_library` to locate `ziti/ziti.h`
and `libziti.so` inside that tree.

The zip does NOT include the `tlsuv` headers that `ziti.h` includes transitively. A second
`RUN` step fetches them from the pinned tlsuv tag (`v0.41.4`) directly off GitHub raw and places
them at `include/tlsuv/`. The builder also installs `libuv1-dev` and `libjson-c-dev` (system
packages) which provide `<uv.h>` and `<json-c/json.h>` respectively.

To override the version or supply a local copy, pass `--build-arg ZITI_SDK_VERSION=<tag>` or set
`ZITI_SDK_ROOT` when building with plain CMake outside Docker:

```bash
cmake -B build -DZITI_SDK_ROOT=/path/to/sdk-prefix
cmake --build build
```

## SDK calls used

| Call | Purpose |
|---|---|
| `ziti_load_config` | Parse enrolled identity JSON into `ziti_config` |
| `ziti_context_init` | Allocate a `ziti_context` from the config |
| `ziti_context_set_options` | Register `event_cb` and select event types |
| `ziti_context_run` | Attach the context to a `uv_loop_t` and start it |
| `ziti_conn_init` | Allocate a `ziti_connection` bound to the context |
| `ziti_listen` | Bind (host) a service; callbacks: `ziti_listen_cb`, `ziti_client_cb` |
| `ziti_accept` | Accept an inbound client connection; registers `on_data` |
| `ziti_dial` | Dial (connect to) a service; callbacks: `ziti_conn_cb`, `ziti_data_cb` |
| `ziti_write` | Async write; completion callback frees the heap buffer |
| `ziti_close_write` | Half-close the write side (FIN equivalent) |
| `ziti_close` | Close a connection |
| `ziti_shutdown` | Gracefully stop the context and drain the loop |

The SDK is fully asynchronous and driven by libuv. The pattern is:

1. `ziti_context_init` + `ziti_context_set_options` + `ziti_context_run`
2. Wait for `ZitiContextEvent` with `ctrl_status == ZITI_OK` in `event_cb`
3. From inside `event_cb`, call `ziti_conn_init` then `ziti_listen` or `ziti_dial`
4. All I/O happens in callbacks; call `uv_run(loop, UV_RUN_DEFAULT)` last

This is the pattern used in `programs/sample-host` and `programs/sample_wttr` in the SDK repo.

## Build result (confirmed)

`docker build -t zo-sdk-c sdk/c` succeeds and produces a 84.9 MB image. All four binaries compile
and link cleanly against ziti-sdk-c 1.17.1 on Ubuntu 22.04 / GCC 11. Confirmed facts from the build:

- The prebuilt zip ships `libziti.so` (shared), not a static archive.
- The zip omits `tlsuv` headers; the Dockerfile fetches them from the pinned tag (`v0.41.4`).
- `ZITI_ENOMEM` does not exist; use `ZITI_ALLOC_FAILED`.
- System packages required in builder: `libuv1-dev`, `libjson-c-dev`. Runtime: `libuv1`, `libjson-c5`.

## Uncertainties and known gaps

**Runtime shared library dependencies.** Binaries embed rpath `/usr/local/lib` where `libziti.so`
is installed. If `libziti.so` has additional dynamic dependencies beyond `libuv` and `libjson-c`
(e.g. mbedTLS or OpenSSL), those surface as dynamic linker errors at container start. Add the
missing package to the runtime `apt-get install` in the Dockerfile.

**`ziti_close_write` availability.** Declared in `ziti.h` for 1.x. If building against a 0.x
SDK, replace it with `ziti_close(conn, NULL)` after the final write completes.

**HTTP framing.** The HTTP server and client use a minimal hand-rolled parser. It handles
`\r\n\r\n` and `\n\n` header terminators but does not parse `Transfer-Encoding: chunked` or
`Content-Length` for large bodies. For the interop matrix contract (small fixed responses) this
is sufficient.

**Windows.** The C source uses POSIX `clock_gettime`, `gethostname`, and `unistd.h`. It will
not compile on Windows without a compatibility shim. The Docker image is Linux-only.
