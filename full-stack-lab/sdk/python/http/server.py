"""HTTP server over OpenZiti using the openziti Python SDK (ziti-sdk-py).

Serves HTTP over a Ziti listener for the service named by ZITI_SERVICE. There is
no open TCP port: openziti.monkeypatch intercepts the bind on (host, port) and
hosts the Ziti service instead. Routes:
    GET /        -> 200 application/json {"lang":"py","host":<hostname>}
    GET /healthz -> 200 text/plain "ok"

Grounded in the SDK sample sample/ziti-http-server/ziti-http-server.py:
    cfg = dict(ztx=identity_path, service=service)
    openziti.monkeypatch(bindings={(host, port): cfg})
    HTTPServer((host, port), Handler).serve_forever()
"""

import json
import os
import socket
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

import openziti

DEFAULT_IDENTITY = "/ziti/id.json"

# A loopback address/port is only the intercept key for monkeypatch. No real
# socket binds it; the Ziti service is hosted instead.
BIND_HOST = "127.0.0.1"
BIND_PORT = 18080

HOSTNAME = socket.gethostname()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802 - required name from BaseHTTPRequestHandler
        if self.path == "/healthz":
            body = b"ok"
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        body = json.dumps({"lang": "py", "host": HOSTNAME}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):  # keep stdout quiet/structured
        sys.stderr.write("http %s\n" % (fmt % args))


def main() -> None:
    identity = os.environ.get("ZITI_IDENTITY", DEFAULT_IDENTITY)
    service = os.environ.get("ZITI_SERVICE")
    if not service:
        sys.exit("ZITI_SERVICE is not set; name the service to bind")

    cfg = dict(ztx=identity, service=service)
    openziti.monkeypatch(bindings={(BIND_HOST, BIND_PORT): cfg})

    server = HTTPServer((BIND_HOST, BIND_PORT), Handler)
    print(f"serving HTTP over Ziti service {service!r}; no TCP port is open", flush=True)
    try:
        server.serve_forever(poll_interval=600)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
