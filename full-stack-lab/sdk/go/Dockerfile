# Build all four interop programs and ship them in one slim image.
# Entrypoint dispatches on APP (echo|http) ROLE (server|client).
FROM golang:1.23-bookworm AS build

WORKDIR /src

# Resolve dependencies first for better layer caching. go.sum may not exist
# yet, so copy go.mod alone and let `go mod tidy` populate the rest.
COPY go.mod ./
COPY go.su[m] ./
COPY internal ./internal
COPY echo ./echo
COPY http ./http

# The base image ships Go 1.23, but the current sdk-golang requires a newer
# Go. GOTOOLCHAIN=auto lets the go command fetch the toolchain the module's
# go directive asks for, at build time, while keeping the pinned base image.
ENV GOTOOLCHAIN=auto
RUN go mod tidy

# CGO is not required by sdk-golang's pure-Go path; build static binaries.
ENV CGO_ENABLED=0
RUN go build -o /out/echo-server ./echo/server \
 && go build -o /out/echo-client ./echo/client \
 && go build -o /out/http-server ./http/server \
 && go build -o /out/http-client ./http/client

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /out/ /app/
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV ZITI_IDENTITY=/ziti/id.json
ENV SELF_LANG=go

ENTRYPOINT ["/app/entrypoint.sh"]
