# Single image for the JS/Node interop-matrix programs: zo-sdk-js
#
# Entrypoint args: APP (echo|http) ROLE (server|client)
# Env: ZITI_IDENTITY (default /ziti/id.json), ZITI_SERVICE, SELF_LANG=js
#
# @openziti/ziti-sdk-nodejs is a native (N-API) addon. It ships prebuilt binaries
# for common platforms, so on linux/amd64 the install usually downloads a prebuilt
# rather than compiling. The build toolchain (python3, make, g++, cmake) is
# included so that, if no prebuilt matches, node-gyp/cmake-js can compile it.

FROM node:20-bookworm

# Build deps for the native addon (fallback path if no prebuilt is downloaded).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        make \
        g++ \
        cmake \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies first for better layer caching.
COPY package.json ./
RUN npm install --omit=dev

# App sources.
COPY common.js entrypoint.js ./
COPY echo ./echo
COPY http ./http

ENV ZITI_IDENTITY=/ziti/id.json \
    SELF_LANG=js

# APP and ROLE are passed as `docker run ... <APP> <ROLE>`.
ENTRYPOINT ["node", "entrypoint.js"]
