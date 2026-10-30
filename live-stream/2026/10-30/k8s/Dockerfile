# For anyone with a Docker daemon. build-images.ps1 builds the same images with ko instead.
#   docker build -f Dockerfile -t zab.local/zab:dev <ziti-access-bridge checkout>
#   docker build -f Dockerfile --build-arg PKG=./demo/cmd/demo-http-server --build-arg BIN=demo-http-server \
#     -t zab.local/demo-http-server:dev <ziti-access-bridge checkout>
FROM golang:1.27 AS build
ARG PKG=./cmd/zab
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/app ${PKG}

FROM gcr.io/distroless/static-debian12:nonroot
ARG BIN=zab
# /ko-app/<name> matches the ko build, so `kubectl exec ... /ko-app/zab agent status` works with
# either image.
COPY --from=build /out/app /ko-app/${BIN}
COPY --from=build /out/app /ko-app/app
ENTRYPOINT ["/ko-app/app"]
