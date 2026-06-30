"""Echo client over OpenZiti using the openziti Python SDK (ziti-sdk-py).

Dials the Ziti service named by ZITI_SERVICE directly over the overlay, sends a
known line, reads a line back, and asserts it matches. There is no tunneler and
no host:port; the SDK resolves the service via the controller.

Prints exactly one line:
    RESULT ok echo py-><target> <ms>ms
    RESULT fail echo py-><target> <reason>

Grounded in the SDK sample sample/ziti-echo-server/ziti-echo-client.py:
    ztx, _ = openziti.load(identity)
    with ztx.connect(service) as client: client.send(...); client.recv(...)
"""

import os
import sys
import time

import openziti

DEFAULT_IDENTITY = "/ziti/id.json"
MESSAGE = b"ping from py\n"


def main() -> int:
    identity = os.environ.get("ZITI_IDENTITY", DEFAULT_IDENTITY)
    service = os.environ.get("ZITI_SERVICE")
    if not service:
        print("RESULT fail echo py-> ZITI_SERVICE-not-set", flush=True)
        return 2

    target = service.rsplit(".", 1)[-1]
    start = time.monotonic()
    try:
        ztx, _ = openziti.load(identity)
        with ztx.connect(service) as conn:
            conn.send(MESSAGE)
            reply = read_line(conn)
        elapsed_ms = int((time.monotonic() - start) * 1000)
        if reply == MESSAGE:
            print(f"RESULT ok echo py->{target} {elapsed_ms}ms", flush=True)
            return 0
        print(f"RESULT fail echo py->{target} mismatch:{reply!r}", flush=True)
        return 1
    except Exception as exc:  # noqa: BLE001 - report any failure on one line
        reason = str(exc).replace(" ", "_") or type(exc).__name__
        print(f"RESULT fail echo py->{target} {reason}", flush=True)
        return 1


def read_line(conn) -> bytes:
    """Read until a newline (or the peer closes)."""
    buf = b""
    while b"\n" not in buf:
        chunk = conn.recv(4096)
        if not chunk:
            break
        buf += chunk
    return buf


if __name__ == "__main__":
    sys.exit(main())
