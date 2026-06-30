# Swift entry in the OpenZiti polyglot interop matrix.
#
# HONEST PLATFORM CONSTRAINT (read this before expecting a green build):
# The OpenZiti Swift SDK (CZiti) is published only as a binary .xcframework for
# Apple platforms (macOS / iOS) via github.com/openziti/ziti-sdk-swift-dist.
# There is NO Linux artifact. SwiftPM on Linux will resolve the package but the
# binaryTarget contains no linux/x86_64 slice, so the build CANNOT link here.
#
# This Dockerfile therefore ATTEMPTS the Linux build as the contract asks, so the
# failure is reproducible and visible (rather than faked). When CZiti gains a
# Linux slice this same Dockerfile should start producing a working image. Until
# then, Swift is the one matrix entry that runs as a macOS HOST edge, not a Linux
# container. See README.md "Platform constraint" for the macOS build/run path.
#
#   docker build -t zo-sdk-swift sdk/swift     # expected to fail at build/link
#
FROM swift:5.10 AS build

WORKDIR /src
COPY Package.swift ./
COPY Sources ./Sources

# Resolve + build. This is the step that fails on Linux because the CZiti
# xcframework ships no linux slice. Left intentionally un-guarded so the build
# log shows the real reason.
RUN swift build -c release

# --- Runtime stage (only reached if the build above ever succeeds) ---
FROM swift:5.10-slim AS runtime

WORKDIR /app
ENV ZITI_IDENTITY=/ziti/id.json \
    SELF_LANG=swift \
    BINDIR=/app/bin

COPY --from=build /src/.build/release/EchoServer /app/bin/EchoServer
COPY --from=build /src/.build/release/EchoClient /app/bin/EchoClient
COPY --from=build /src/.build/release/HttpServer /app/bin/HttpServer
COPY --from=build /src/.build/release/HttpClient /app/bin/HttpClient
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["echo", "server"]
