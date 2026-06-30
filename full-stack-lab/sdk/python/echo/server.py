"""Echo server over OpenZiti using the openziti Python SDK (ziti-sdk-py).

App-embedded zero trust: this process binds (hosts) the Ziti service named by
ZITI_SERVICE and echoes back whatever a client sends. There is no TCP listener
and no open port. Connectivity comes entirely from the OpenZiti overlay.

Grounded in the SDK sample sample/ziti-echo-server/ziti-echo-server.py:
    ztx, _ = openziti.load(identity)
    server = ztx.bind(service); server.listen(); server.accept()
"""

import os
import sys

import openziti

DEFAULT_IDENTITY = "/ziti/id.json"


def main() -> None:
    identity = os.environ.get("ZITI_IDENTITY", DEFAULT_IDENTITY)
    service = os.environ.get("ZITI_SERVICE")
    if not service:
        sys.exit("ZITI_SERVICE is not set; name the service to bind")

    # Load the enrolled identity JSON into the SDK. load() returns (ztx, _).
    ztx, _ = openziti.load(identity)

    # Bind (host) the service. No local TCP port is opened.
    server = ztx.bind(service)
    server.listen()
    server.setblocking(True)
    print(f"hosting service {service!r} over the overlay; no TCP port is open", flush=True)

    while True:
        conn, peer = server.accept()
        print(f"connection from {peer}", flush=True)
        conn.setblocking(True)
        try:
            handle(conn)
        finally:
            conn.close()


def handle(conn) -> None:
    """Echo every chunk received back to the sender until the peer closes."""
    while True:
        data = conn.recv(4096)
        if not data:
            return
        conn.sendall(data)


if __name__ == "__main__":
    main()
