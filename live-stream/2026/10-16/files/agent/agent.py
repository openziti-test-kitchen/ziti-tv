"""The agent: a model that chooses tools, reachable only over the appetizer's overlay.

Every line that arrives goes to a model, through llm-gateway, with the tools
mcp-gateway offers. The model decides which tool to use. The network decides
which tools can actually be reached: the tools are the appetizer's own dark
services, and OpenZiti service policy decides who may dial them.

Episode 4: a caller can also bring their own tools. For each question, the agent
dials byo-<caller>, and if the caller is hosting anything there, it offers those
tools in that caller's conversation only. Only <caller> is allowed to host
byo-<caller>, so the network decides whose tools they are.

    python agent/agent.py                      # binds AGENT_SERVICE; talk to it with the reflect client
    python agent/agent.py --cli                # type at it directly; house tools only
    python agent/agent.py --cli --as local_ziggy   # rehearsal: claim to be local_ziggy

Logs go to stderr. In --cli mode, answers go to stdout. --as is a claim anyone can
make; over the overlay, the caller's identity is cryptographic.
"""

import asyncio
import http.client
import json
import os
import shlex
import sys
import threading
from collections import defaultdict

import anyio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

LLM_GATEWAY = os.getenv("LLM_GATEWAY", "127.0.0.1:8080")       # episode 2's llm-gateway
AGENT_KEY = os.environ["AGENT_GATEWAY_KEY"]                       # a virtual key, not a provider key
MCP_COMMAND = shlex.split(os.getenv("MCP_COMMAND", "mcp-tools run ziti-tv-appetizer"))
AGENT_SERVICE = os.getenv("AGENT_SERVICE", "agent-service")
IDENTITY = os.getenv("ZITI_IDENTITY", "")
MAX_STEPS = 5          # tool calls per question before giving up
MAX_HISTORY = 20       # messages kept per caller before starting over

# Episode 4: the caller's own tools, reached over the Appetizer's network.
HERE = os.path.dirname(os.path.abspath(__file__))
BYO_DIAL = os.getenv("BYO_DIAL", os.path.join(HERE, "..", "byo", "dial.py"))
BYO_PREFIX = "byo_"    # the model, and the logs, can tell the caller's tools from the house's
BYO_SETUP_TIMEOUT = 10  # seconds to reach a caller's tools before answering without them
CLI_CALLER = "cli"     # --cli with no --as: no identity, so no tools of its own

SYSTEM = (
    "You answer chat messages for the OpenZiti Appetizer in a single line. "
    "For any arithmetic, call the math tool; never work it out yourself. "
    "When asked whether a message is offensive, call the classify tool. "
    "Tools whose names start with byo_ belong to the caller and run on the caller's own machine. "
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


def byo_to_openai(tool, caller):
    """One of the caller's own tools -> OpenAI function definition, marked as theirs."""
    fn = to_openai(tool)
    fn["function"]["name"] = BYO_PREFIX + tool.name
    fn["function"]["description"] = f"(runs on {caller}'s machine) " + (tool.description or "")
    return fn


class Agent:
    def __init__(self, session, tools):
        self.session = session   # the house tools, through mcp-gateway
        self.tools = tools
        # The caller's identity is the session key. No login, no cookie, no bearer token.
        self.histories = defaultdict(list)

    async def answer(self, caller, text):
        """Answer one line, with the house tools plus whatever the caller is hosting right now.

        Rule 1: the only extra tools are the ones on byo-<caller>, and only <caller>
        may host that service. A stranger's tool never enters someone else's conversation.

        The caller's session is opened and closed inside this one call. anyio won't
        let a task close a session that a different task opened, and each answer
        runs as its own task.
        """
        if caller == CLI_CALLER:
            return await self.converse(caller, text, None, [])

        env = {**os.environ, "ZITI_LOG": os.getenv("ZITI_LOG", "1")}   # 1: the SDK's ERROR lines carry the network's reasons
        params = StdioServerParameters(command=sys.executable, args=[BYO_DIAL, f"byo-{caller}"], env=env)
        reply, connected = None, False
        try:
            async with stdio_client(params) as (read, write):
                async with ClientSession(read, write) as byo:
                    with anyio.fail_after(BYO_SETUP_TIMEOUT):
                        await byo.initialize()
                        own = (await byo.list_tools()).tools
                    connected = True
                    names = ", ".join(BYO_PREFIX + t.name for t in own) or "none"
                    log(f"  [{caller}] own tools: {names}")
                    reply = await self.converse(caller, text, byo, [byo_to_openai(t, caller) for t in own])
        except Exception as e:
            if not connected:
                # Nothing on byo-<caller>, or nobody answering. byo/dial.py has logged the network's reason.
                log(f"  [{caller}] own tools: none")
                return await self.converse(caller, text, None, [])
            if reply is None:
                raise
            log(f"  [{caller}] own tools closed untidily: {e!r}")
        return reply

    async def call_tool(self, caller, byo, name, args):
        """Route a call to the caller's own tool, or to the house's. Returns (text, failed)."""
        if name.startswith(BYO_PREFIX):
            if byo is None:
                return f"{name} is gone: {caller} isn't hosting it any more", True
            try:
                result = await byo.call_tool(name[len(BYO_PREFIX):], args)
            except Exception as e:
                return f"{caller}'s own tool stopped answering: {e}", True
        else:
            result = await self.session.call_tool(name, args)
        out = " ".join(getattr(part, "text", "") for part in result.content).strip()
        return out, result.is_error

    async def converse(self, caller, text, byo, own_tools):
        history = self.histories[caller]
        if len(history) > MAX_HISTORY:
            history.clear()
        history.append({"role": "user", "content": text})
        system = {"role": "system", "content": SYSTEM.format(caller=caller)}

        tools = self.tools + own_tools
        for _ in range(MAX_STEPS):
            reply = await asyncio.to_thread(chat, [system] + history, tools)
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
                out, failed = await self.call_tool(caller, byo, name, args)
                log(f"  [{caller}] {'REFUSED' if failed else 'tool'} {name}({args}) -> {out}")
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
    caller = sys.argv[sys.argv.index("--as") + 1] if "--as" in sys.argv[:-1] else CLI_CALLER
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
                        print("agent>", await agent.answer(caller, text.strip()), flush=True)
            else:
                loop = asyncio.get_running_loop()
                threading.Thread(target=serve_dark, args=(agent, loop), daemon=True).start()
                await asyncio.Event().wait()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
