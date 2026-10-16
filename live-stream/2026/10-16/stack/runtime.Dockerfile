# One image for everything in the arc that is not the classifier: LLM Gateway, MCP Gateway with the tool server it
# starts, the agent, and episode 4's tool hosts and client. All of them are a gateway binary, a Python script, or both.
FROM python:3.12-slim

ARG LLM_GATEWAY_VERSION=0.1.8
# mcp-gateway and mcp-tools come from the same release: v0.1.10 changed how they talk, and a mismatched pair cannot
# connect
ARG MCP_GATEWAY_VERSION=0.1.11
# zrok2 is only for `zrok2 enable` and `zrok2 create share` in episode 3, so the host needs no install
ARG ZROK_VERSION=2.0.8
ARG TARGETARCH

ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates iproute2 \
 && rm -rf /var/lib/apt/lists/*

RUN set -e; cd /tmp; \
    curl -fsSLO "https://github.com/openziti/llm-gateway/releases/download/v${LLM_GATEWAY_VERSION}/llm-gateway_${LLM_GATEWAY_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    curl -fsSLO "https://github.com/openziti/mcp-gateway/releases/download/v${MCP_GATEWAY_VERSION}/mcp-gateway_${MCP_GATEWAY_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    curl -fsSLO "https://github.com/openziti/zrok/releases/download/v${ZROK_VERSION}/zrok_${ZROK_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    for f in *.tar.gz; do tar xzf "$f"; done; \
    install -m 755 llm-gateway mcp-gateway mcp-tools zrok2 /usr/local/bin/; \
    rm -rf /tmp/*

COPY ep3-mcp-gateway/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt

WORKDIR /stack
