"""Bring your own tool: host any stdio MCP server as a dark service.

Runs on the viewer's machine, as the viewer's own OpenZiti identity. It binds
byo-<identity> and, for each connection the agent makes, starts the MCP server
you name and pipes bytes between the two. The MCP server needs no changes: as
far as it knows, it's talking over stdin and stdout. Nothing listens on TCP.

    .venv/bin/python byo/host.py ~/.ziti-demo/local_ziggy.json -- .venv/bin/python byo/tools/whereami.py

The service name defaults to byo-<identity file name without .json>, which is
how the Appetizer names identity files. Use --service to try another name; the
bind policy, not this script, decides whether you're allowed to host it.

Press Ctrl-C to "close the laptop".
"""

import argparse
import json
import os
import subprocess
import sys
import threading

import openziti


def log(msg):
    print(f"byo-host: {msg}", file=sys.stderr, flush=True)


def note_calls(caller, buf, chunk):
    """Log each MCP tools/call as it goes by. MCP over stdio is one JSON message per line."""
    buf += chunk
    while b"\n" in buf:
        line, buf = buf.split(b"\n", 1)
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if isinstance(msg, dict) and msg.get("method") == "tools/call":
            p = msg.get("params") or {}
            log(f"{caller} called {p.get('name')}({p.get('arguments') or {}})")
    return buf


def handle(conn, caller, command):
    log(f"connection from {caller}; starting {os.path.basename(command[-1])}")
    # The tool's stderr comes straight to this terminal. Its stdin and stdout go to the agent.
    proc = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0)

    def agent_to_tool():
        buf = b""
        try:
            while chunk := conn.recv(65536):
                proc.stdin.write(chunk)
                proc.stdin.flush()
                buf = note_calls(caller, buf, chunk)
        except OSError:
            pass
        finally:
            try:
                proc.stdin.close()      # EOF: a stdio MCP server exits when its input ends
            except OSError:
                pass

    inbound = threading.Thread(target=agent_to_tool, daemon=True)
    inbound.start()
    try:
        while chunk := proc.stdout.read(65536):
            conn.sendall(chunk)
    except OSError:
        pass
    finally:
        conn.close()
        inbound.join(timeout=2)
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
        log(f"{caller} disconnected")


def serve(ztx, service, command):
    try:
        server = ztx.bind(service)
    except OSError as e:
        # The SDK raises a refused bind as a bare libziti code; translate it.
        reason = openziti.strerror(e.errno) if isinstance(e.errno, int) and e.errno < 0 else str(e)
        log(f"the network refused to let this identity host {service}: {reason}")
        os._exit(1)
    server.listen()
    server.setblocking(True)    # OpenZiti's bound sockets start out non-blocking
    log(f"hosting {service}; nothing is listening on TCP")
    while True:
        conn, peer = server.accept()     # peer[0] is the caller's identity name
        conn.setblocking(True)
        threading.Thread(target=handle, args=(conn, peer[0], command), daemon=True).start()


def main():
    argv = sys.argv[1:]
    if "--" not in argv:
        sys.exit(__doc__)
    split = argv.index("--")
    command = argv[split + 1:]
    parser = argparse.ArgumentParser(description="Host a stdio MCP server as a dark service.")
    parser.add_argument("identity", help="your OpenZiti identity file, e.g. ~/.ziti-demo/local_ziggy.json")
    parser.add_argument("--service", help="service to host (default: byo-<identity file name>)")
    args = parser.parse_args(argv[:split])
    if not command:
        sys.exit("give the MCP server's command after --")

    identity = os.path.expanduser(args.identity)
    service = args.service or "byo-" + os.path.splitext(os.path.basename(identity))[0]

    ztx, err = openziti.load(identity, timeout=10_000)
    if err != 0:
        log(f"identity {identity} did not load cleanly: {openziti.strerror(err)}")

    # Accept in a background thread, so Ctrl-C reaches the main thread right away.
    t = threading.Thread(target=serve, args=(ztx, service, command), daemon=True)
    t.start()
    try:
        t.join()
    except KeyboardInterrupt:
        log(f"stopped hosting {service}")


if __name__ == "__main__":
    main()
