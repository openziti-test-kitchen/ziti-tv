"""Connect stdin and stdout to an OpenZiti service, by name.

The agent runs this as if it were a local MCP server:

    ZITI_IDENTITY=.ziti/agent.json .venv/bin/python byo/dial.py byo-local_ziggy

It's the mirror image of byo/host.py, and the same idea as `mcp-tools run
<share>` from episode 3, with the Appetizer's own network in place of zrok.

Its stdout is the MCP stream, so every log line goes to stderr. If the network
refuses the dial, it prints the network's reason on one line and exits 1.
"""

import os
import sys
import threading

import openziti

CONNECT_TIMEOUT = float(os.getenv("BYO_CONNECT_TIMEOUT", "8"))   # seconds


def log(msg):
    print(f"byo-dial: {msg}", file=sys.stderr, flush=True)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: dial.py <service>")
    service = sys.argv[1]
    identity = os.environ["ZITI_IDENTITY"]

    # A dial that never answers would leave the agent waiting. Give up instead.
    watchdog = threading.Timer(CONNECT_TIMEOUT, lambda: (log(f"{service}: no answer in {CONNECT_TIMEOUT:g}s"), os._exit(1)))
    watchdog.daemon = True
    watchdog.start()

    ztx, err = openziti.load(identity, timeout=10_000)
    if err != 0:
        log(f"identity {identity} did not load cleanly: {openziti.strerror(err)}")
    try:
        # Blocking dial, so a refusal raises OpenZiti's own message (episode 3's lesson).
        sock = ztx.connect(service)
    except Exception as e:
        detail = e.args[-1] if e.args and isinstance(e.args[-1], str) else str(e)
        log(f"{service}: {detail}")
        os._exit(1)
    watchdog.cancel()

    def to_service():
        try:
            while chunk := os.read(0, 65536):
                sock.sendall(chunk)
        except OSError:
            pass
        os._exit(0)    # the agent closed our stdin: we're done

    threading.Thread(target=to_service, daemon=True).start()
    out = sys.stdout.buffer
    try:
        while chunk := sock.recv(65536):
            out.write(chunk)
            out.flush()
    except OSError as e:
        # A dial to a service nobody is hosting "succeeds", then resets. The
        # network's reason ("has no terminators") is on the SDK's ERROR log line
        # just above this one, so keep ZITI_LOG at 1 or higher.
        log(f"{service}: connection dropped: {e}")
        os._exit(1)
    log(f"{service}: the other end hung up")
    os._exit(1)


if __name__ == "__main__":
    main()
