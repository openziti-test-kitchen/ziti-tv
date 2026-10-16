"""The appetizer's dark services, offered to agents as MCP tools.

Each tool is a service the appetizer already hosts on its OpenZiti network.
This process holds its own identity, and it can call a tool only if that
identity may dial the tool's service. Revoke the dial policy and the call is
refused by the network, not by this code.

mcp-gateway runs this over stdio. Anything printed to stdout corrupts the MCP
stream, so every log line goes to stderr.
"""

import http.client
import json
import os
import sys
from urllib.parse import urlencode

import openziti
from mcp.server.mcpserver import MCPServer
from mcp.server.mcpserver.exceptions import ToolError

IDENTITY = os.environ["ZITI_IDENTITY"]
MATH_SERVICE = os.getenv("MATH_SERVICE", "local_httpService")
CLASSIFY_SERVICE = os.getenv("CLASSIFY_SERVICE", "classifier-service")


def log(msg):
    print(f"appetizer-tools: {msg}", file=sys.stderr, flush=True)


ztx, err = openziti.load(IDENTITY, timeout=10_000)
if err != 0:
    log(f"identity {IDENTITY} did not load cleanly: {openziti.strerror(err)}")


class ZitiHTTPConnection(http.client.HTTPConnection):
    """Plain HTTP/1.1, over a socket dialed by service name. No address anywhere."""

    def __init__(self, service, timeout=15):
        super().__init__(service, timeout=timeout)  # Host: header is the service name
        self.service = service

    def connect(self):
        # Dial in blocking mode. That way, a refused dial raises OpenZiti's own
        # error message. With a timeout, the SDK dials asynchronously, and a
        # refusal only shows up later as a dropped connection with no reason.
        self.sock = ztx.connect(self.service)
        self.sock.settimeout(self.timeout)  # for the HTTP exchange that follows


def call(service, method, path, body=None):
    conn = ZitiHTTPConnection(service)
    try:
        try:
            conn.connect()
        except Exception as e:
            # The network's answer, verbatim. This is the line to read on camera.
            # OpenZiti raises a plain Exception(code, message) for a refused dial.
            detail = e.args[-1] if e.args and isinstance(e.args[-1], str) else str(e)
            log(f"dial {service} refused: {detail}")
            raise ToolError(f"the network refused a connection to {service}: {detail}") from e
        headers = {"Content-Type": "application/json"} if body else {}
        try:
            conn.request(method, path, body=body, headers=headers)
            resp = conn.getresponse()
            return resp.status, resp.read().decode().strip()
        except Exception as e:
            # Raised as a ToolError so MCP passes the reason on instead of hiding it.
            log(f"connection to {service} dropped: {e!r}")
            raise ToolError(f"the connection to {service} was dropped: {e}") from e
    finally:
        conn.close()


mcp = MCPServer("appetizer")


@mcp.tool()
def math(input1: float, operator: str, input2: float) -> str:
    """Exact arithmetic on two numbers. operator is one of: + - * /"""
    query = urlencode({"input1": input1, "operator": operator, "input2": input2})
    status, text = call(MATH_SERVICE, "GET", f"/domath?{query}")
    if status != 200:
        raise ToolError(f"math service said {status}: {text}")
    return text  # "Result: 42.00"


@mcp.tool()
def classify(text: str) -> str:
    """Judge whether a chat message is offensive. Returns OFFENSIVE or CLEAN."""
    status, raw = call(CLASSIFY_SERVICE, "POST", "/api/v1/classify", json.dumps({"text": text}))
    if status != 200:
        raise ToolError(f"classifier said {status}: {raw}")
    top = json.loads(raw)[0]
    verdict = "OFFENSIVE" if top["label"] == "Offensive" else "CLEAN"
    # No score: after an escalation, the score is still the classifier's
    # confidence in its own verdict, which the gateway's model overruled.
    return verdict


if __name__ == "__main__":
    log(f"serving math via {MATH_SERVICE}, classify via {CLASSIFY_SERVICE}, as {IDENTITY}")
    mcp.run()  # stdio
