# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# Builds image zo-sdk-c containing echo_server, echo_client,
# http_server, http_client linked against ziti-sdk-c (prebuilt artifact).
#
# Entrypoint: /entrypoint.sh
# Usage:
#   docker run --rm \
#     -e ZITI_IDENTITY=/ziti/id.json \
#     -e ZITI_SERVICE=echo.c \
#     -e SELF_LANG=c \
#     -v /path/to/id.json:/ziti/id.json:ro \
#     zo-sdk-c echo server
#
# The entrypoint selects the binary by combining APP (echo|http) and
# ROLE (server|client).
# ---------------------------------------------------------------------------

# ---- stage 1: build -------------------------------------------------------
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    ca-certificates \
    unzip \
    pkg-config \
    libuv1-dev \
    libjson-c-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy sources
COPY echo_server.c echo_client.c http_server.c http_client.c CMakeLists.txt ./

# Download the prebuilt ziti-sdk-c for Linux x86_64.
# If the zip layout changes between releases, adjust ZITI_SDK_ROOT below.
ARG ZITI_SDK_VERSION=1.17.1
# tlsuv version pinned to what ziti-sdk-c 1.17.1 depends on (see its CMakeLists.txt)
ARG TLSUV_VERSION=v0.41.4
RUN curl -fsSL \
    "https://github.com/openziti/ziti-sdk-c/releases/download/${ZITI_SDK_VERSION}/ziti-sdk-Linux-x86_64.zip" \
    -o ziti-sdk.zip \
 && unzip -q ziti-sdk.zip -d ziti-sdk-prebuilt \
 && rm ziti-sdk.zip

# The prebuilt zip includes ziti headers but NOT tlsuv headers (which ziti.h includes
# transitively).  Fetch them from the matching tlsuv release tag.
RUN mkdir -p ziti-sdk-prebuilt/include/tlsuv \
 && for f in tlsuv.h connector.h tls_engine.h tls_link.h queue.h src_t.h http.h websocket.h keychain.h; do \
      curl -fsSL \
        "https://raw.githubusercontent.com/openziti/tlsuv/${TLSUV_VERSION}/include/tlsuv/${f}" \
        -o "ziti-sdk-prebuilt/include/tlsuv/${f}" || true; \
    done

# Build. We pass ZITI_SDK_ROOT so CMakeLists.txt skips FetchContent.
RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DZITI_SDK_ROOT=/src/ziti-sdk-prebuilt \
 && cmake --build build --parallel "$(nproc)"

# ---- stage 2: runtime image -----------------------------------------------
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libuv1 \
    libjson-c5 \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries
COPY --from=builder \
    /src/build/echo_server \
    /src/build/echo_client \
    /src/build/http_server \
    /src/build/http_client \
    /usr/local/bin/

# Copy the ziti shared library from the prebuilt tree so the binaries can find it
COPY --from=builder /src/ziti-sdk-prebuilt/lib/libziti.so /usr/local/lib/libziti.so
RUN ldconfig

# Default identity path expected by all four binaries
ENV ZITI_IDENTITY=/ziti/id.json
ENV ZITI_SERVICE=echo.c
ENV SELF_LANG=c

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
# Default: show usage
CMD ["echo", "server"]
