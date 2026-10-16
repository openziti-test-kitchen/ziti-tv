"""The agent: a model that chooses tools, reachable only over the appetizer's overlay.

Every line that arrives goes to a model, through llm-gateway, with the tools
mcp-gateway offers. The model decides which tool to use. The network decides
which tools can actually be reached: the tools are the appetizer's own dark
services, and OpenZiti service policy decides who may dial them.

    python agent/agent.py          # binds AGENT_SERVICE; talk to it with the reflect client
    python agent/agent.py --cli    # type at it directly; no OpenZiti identity needed

Logs go to stderr. In --cli mode, answers go to stdout.
"""

import asyncio
import http.client
import json
import os
import shlex
import sys
import threading
from collections import defaultdict

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

LLM_GATEWAY = os.getenv("LLM_GATEWAY", "127.0.0.1:8080")       # episode 2's llm-gateway
AGENT_KEY = os.environ["AGENT_GATEWAY_KEY"]                       # a virtual key, not a provider key
MCP_COMMAND = shlex.split(os.getenv("MCP_COMMAND", "mcp-tools run ziti-tv-appetizer"))
AGENT_SERVICE = os.getenv("AGENT_SERVICE", "agent-service")
IDENTITY = os.getenv("ZITI_IDENTITY", "")
MAX_STEPS = 5          # tool calls per question before giving up
MAX_HISTORY = 20       # messages kept per caller before starting over

SYSTEM = (
    "You answer chat messages for the OpenZiti Appetizer in a single line. "
    "For any arithmetic, call the math tool; never work it out yourself. "
    "When asked whether a message is offensive, call the classify tool. "
    "If a tool call fails, say which tool failed and give its error in a few words. "
    "The caller's OpenZiti identity is: {caller}."
)


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def to_openai(tool):
    """MCP tool -> OpenAI function definition. llm-gateway translates it for Claude."""
    return {
        "type": "function",
        "function": {
            "name": tool.name,                       # e.g. appetizer_math
            "description": tool.description or "",
            "parameters": tool.input_schema,
        },
    }


def chat(messages, tools):
    """One request to llm-gateway. model "auto": the gateway picks the model."""
    host, _, port = LLM_GATEWAY.partition(":")
    body = json.dumps({"model": "auto", "max_tokens": 300, "messages": messages, "tools": tools})
    conn = http.client.HTTPConnection(host, int(port or 80), timeout=60)
    try:
        conn.request("POST", "/v1/chat/completions", body=body, headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {AGENT_KEY}",
        })
        return json.loads(conn.getresponse().read())
    finally:
        conn.close()


class Agent:
    def __init__(self, session, tools):
        self.session = session
        self.tools = tools
        # The caller's identity is the session key. No login, no cookie, no bearer token.
        self.histories = defaultdict(list)

    async def answer(self, caller, text):
        history = self.histories[caller]
        if len(history) > MAX_HISTORY:
            history.clear()
        history.append({"role": "user", "content": text})
        system = {"role": "system", "content": SYSTEM.format(caller=caller)}

        for _ in range(MAX_STEPS):
            reply = await asyncio.to_thread(chat, [system] + history, self.tools)
            if "error" in reply:
                history.pop()
                return f"(llm-gateway refused: {reply['error'].get('message')})"
            msg = reply["choices"][0]["message"]
            log(f"  [{caller}] model={reply.get('model')}")
            history.append({k: v for k, v in msg.items() if k in ("role", "content", "tool_calls")})

            calls = msg.get("tool_calls") or []
            if not calls:
                return " ".join((msg.get("content") or "").split())

            for call in calls:
                name = call["function"]["name"]
                args = json.loads(call["function"].get("arguments") or "{}")
                result = await self.session.call_tool(name, args)
                out = " ".join(getattr(part, "text", "") for part in result.content).strip()
                log(f"  [{caller}] {'REFUSED' if result.is_error else 'tool'} {name}({args}) -> {out}")
                history.append({"role": "tool", "tool_call_id": call["id"], "content": out})

        return "(gave up after too many tool calls)"


def serve_dark(agent, loop):
    """Bind AGENT_SERVICE on the appetizer's overlay. Nothing listens on TCP."""
    import openziti

    ztx, err = openziti.load(IDENTITY, timeout=10_000)
    if err != 0:
        log(f"identity {IDENTITY} did not load cleanly: {openziti.strerror(err)}")
    server = ztx.bind(AGENT_SERVICE)
    server.listen()
    server.setblocking(True)   # OpenZiti's bound sockets start out non-blocking
    log(f"bound {AGENT_SERVICE} as {IDENTITY}; dial it with the reflect client")

    def handle(conn, caller):
        log(f"connection from {caller}")
        buf = b""
        try:
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    return
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    text = line.decode(errors="replace").strip()
                    if not text:
                        continue
                    log(f"[{caller}] {text}")
                    fut = asyncio.run_coroutine_threadsafe(agent.answer(caller, text), loop)
                    reply = fut.result()
                    log(f"[{caller}] -> {reply}")
                    # The reflect client reads exactly one line back.
                    conn.sendall((reply + "\n").encode())
        finally:
            conn.close()
            log(f"{caller} disconnected")

    while True:
        conn, peer = server.accept()     # peer[0] is the caller's identity name
        conn.setblocking(True)
        threading.Thread(target=handle, args=(conn, peer[0]), daemon=True).start()


async def main():
    cli = "--cli" in sys.argv
    params = StdioServerParameters(command=MCP_COMMAND[0], args=MCP_COMMAND[1:], env=dict(os.environ))
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            listed = (await session.list_tools()).tools
            log("tools offered by the gateway: " + ", ".join(t.name for t in listed))
            agent = Agent(session, [to_openai(t) for t in listed])

            if cli:
                while True:
                    try:
                        text = await asyncio.to_thread(input, "you> ")
                    except EOFError:
                        return
                    if text.strip():
                        print("agent>", await agent.answer("cli", text.strip()), flush=True)
            else:
                loop = asyncio.get_running_loop()
                threading.Thread(target=serve_dark, args=(agent, loop), daemon=True).start()
                await asyncio.Event().wait()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
