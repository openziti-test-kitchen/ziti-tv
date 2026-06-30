"""Single entrypoint for the zo-sdk-py image.

Usage: entrypoint.py APP ROLE
    APP  = echo | http
    ROLE = server | client

Dispatches to the matching module under echo/ or http/. All configuration is via
environment variables (ZITI_IDENTITY, ZITI_SERVICE, SELF_LANG).
"""

import runpy
import sys

APPS = ("echo", "http")
ROLES = ("server", "client")


def main() -> int:
    if len(sys.argv) != 3:
        sys.exit("usage: entrypoint.py <echo|http> <server|client>")
    app, role = sys.argv[1], sys.argv[2]
    if app not in APPS:
        sys.exit(f"unknown APP {app!r}; expected one of {APPS}")
    if role not in ROLES:
        sys.exit(f"unknown ROLE {role!r}; expected one of {ROLES}")

    module = f"{app}/{role}.py"
    # Reset argv so the target module sees a clean argv[0].
    sys.argv = [module]
    runpy.run_path(module, run_name="__main__")
    return 0


if __name__ == "__main__":
    sys.exit(main())
