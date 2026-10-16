"""List the Appetizer's MCP tools, and call each one once.

    python ep3-mcp-gateway/tools/check.py            # straight to tools/server.py, over stdio
    python ep3-mcp-gateway/tools/check.py gateway    # through mcp-tools, zrok and mcp-gateway
"""

import asyncio
import os
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SHARE = os.getenv("MCP_SHARE", "ziti-tv-appetizer")
HERE = os.path.dirname(os.path.abspath(__file__))


def server_params():
    if sys.argv[1:] == ["gateway"]:
        return StdioServerParameters(command="mcp-tools", args=["run", SHARE], env=dict(os.environ)), "appetizer_"
    env = dict(os.environ)
    env.setdefault("ZITI_IDENTITY", os.path.normpath(os.path.join(HERE, "..", ".ziti", "appetizer-tools.json")))
    return StdioServerParameters(command=sys.executable, args=[os.path.join(HERE, "server.py")], env=env), ""


async def main():
    params, prefix = server_params()
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("tools:", sorted(t.name for t in (await session.list_tools()).tools))
            for name, args in (("math", {"input1": 6, "operator": "*", "input2": 7}),
                               ("classify", {"text": "you are too stupid to understand this"})):
                result = await session.call_tool(prefix + name, args)
                text = " ".join(part.text for part in result.content)
                print(f"{prefix + name}: {'REFUSED' if result.is_error else 'ok'} -> {text}")


asyncio.run(main())
