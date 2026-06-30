"""HTTP client over OpenZiti using the openziti Python SDK (ziti-sdk-py).

Does an HTTP GET / over the Ziti overlay for the service named by ZITI_SERVICE.
openziti.monkeypatch intercepts the socket so the request URL's host is resolved
to the Ziti service rather than DNS/TCP. OK when the response is 200 and the body
parses as JSON.

Prints exactly one line:
    RESULT ok http py-><target> <ms>ms
    RESULT fail http py-><target> <reason>

Grounded in the SDK sample sample/ziti-requests/ziti-requests.py:
    with openziti.monkeypatch():
        requests.get(f"http://{service}/")
"""

import json
import os
import sys
import time
import urllib.request

import openziti

DEFAULT_IDENTITY = "/ziti/id.json"


def main() -> int:
    identity = os.environ.get("ZITI_IDENTITY", DEFAULT_IDENTITY)
    service = os.environ.get("ZITI_SERVICE")
    if not service:
        print("RESULT fail http py-> ZITI_SERVICE-not-set", flush=True)
        return 2

    target = service.rsplit(".", 1)[-1]
    start = time.monotonic()
    try:
        # Load identity so monkeypatch can resolve the service over the overlay.
        openziti.load(identity)
        # The host portion of the URL is the Ziti service name. monkeypatch
        # routes the connection over Ziti instead of DNS/TCP.
        url = f"http://{service}/"
        with openziti.monkeypatch():
            with urllib.request.urlopen(url, timeout=60) as resp:  # noqa: S310 - ziti overlay
                status = resp.status
                payload = resp.read()
        elapsed_ms = int((time.monotonic() - start) * 1000)
        if status != 200:
            print(f"RESULT fail http py->{target} status:{status}", flush=True)
            return 1
        json.loads(payload.decode("utf-8"))  # assert body parses
        print(f"RESULT ok http py->{target} {elapsed_ms}ms", flush=True)
        return 0
    except Exception as exc:  # noqa: BLE001 - report any failure on one line
        reason = str(exc).replace(" ", "_") or type(exc).__name__
        print(f"RESULT fail http py->{target} {reason}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
