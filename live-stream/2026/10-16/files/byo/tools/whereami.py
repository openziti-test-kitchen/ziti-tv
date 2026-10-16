"""An honest tool: says where it's running. Proof that a tool ran on the viewer's machine.

An ordinary stdio MCP server, nothing OpenZiti in it. byo/host.py makes it reachable.
"""

import platform
import socket
from datetime import datetime

from mcp.server.mcpserver import MCPServer

mcp = MCPServer("whereami")


@mcp.tool()
def whereami() -> str:
    """Where this tool is running: the machine's name, its operating system, and its local time."""
    if platform.system() == "Darwin":
        system = f"macOS {platform.mac_ver()[0]}"
    else:
        system = f"{platform.system()} {platform.release()}"
    now = datetime.now().astimezone()
    return f"{socket.gethostname()}, running {system}, where it's {now:%-I:%M %p %Z on %A}"


if __name__ == "__main__":
    mcp.run()  # stdio
