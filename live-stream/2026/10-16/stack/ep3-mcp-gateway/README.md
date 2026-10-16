# Episode 3: an agent whose tools are OpenZiti services

So far the models have only answered questions. In this episode a model starts choosing what to do. The Appetizer gets
an agent: a small program that asks Claude which tool would help, calls that tool, and uses the result. That raises a
question episodes 1 and 2 did not have:

> What stops an agent from doing something it should not?

A system prompt can ask a model not to do something. It cannot stop it. So the agent's tools are dark services on the
Appetizer's OpenZiti network, and service policies decide which of them can be reached. The tools reach the agent
through [MCP Gateway](https://github.com/openziti/mcp-gateway), an open source gateway for MCP servers. In the middle of
a conversation, one `ziti` command takes a tool away and another gives it back. Nothing restarts, and none of the
Appetizer's code changes.

**The model decides which tool to use. The network decides which tools it can reach.**

You end up with:

- Two tools that were already on the network: the Appetizer's math service, there since 2023, and episode 1's
  classifier.
- A tool server with its own identity, and one dial policy per tool.
- MCP Gateway serving those tools through a closed zrok share, with no listening port.
- An agent that hosts `agent-service`, so Ziggy talks to it the way she talks to the reflect server.
- One policy deletion that takes the math tool away from the agent mid-conversation.

This episode starts from the stack [episode 2](../ep2-llm-gateway/README.md) leaves running, including the agent's
virtual key from its step 3. It adds a [zrok](https://docs.zrok.io) account. The steps are in [LAB.md](LAB.md). This
page explains what they show.

## The pieces

| Piece | What it is | Where it runs |
| --- | --- | --- |
| `local_httpService` | The Appetizer's arithmetic service, `/domath`. The first tool. | `appetizer` container |
| `classifier-service` | Episode 1's classifier. The second tool. | `classifier` container |
| Tool server | `tools/server.py`, an MCP server offering `math` and `classify`. Each tool dials one service by name, as identity `appetizer-tools`. | started by MCP Gateway |
| MCP Gateway | Starts the tool server and offers its tools to agents through one endpoint: a zrok share. | `mcp-gateway` container |
| zrok share | A persistent, closed share: the gateway's address, reachable only from your own zrok account. | zrok's public network |
| `mcp-tools` | Connects an agent to a gateway's share, and speaks MCP to it over stdio. | inside the `agent` container |
| Agent | `agent/agent.py`. Holds one key, the agent's virtual key, and hosts `agent-service` as `agent-service-host`. | `agent` container |
| `dial` client | Dials `agent-service` as Ziggy. | `dial`, run on demand |
| LLM Gateway | Episode 2's. Its `has_tools` rule sends every request that offers tools to the `tools` route, Claude Haiku. | `llm-gateway` container |

Two OpenZiti networks appear here. zrok's public network carries the agent's connection to MCP Gateway, and the
Appetizer's network carries everything else. MCP Gateway serves only over zrok or Agora today.

## What you do

1. Call the math service as Ziggy, the way it has been callable since 2023.
2. Get a zrok environment and a closed share.
3. Create the tool server's identity, one dial policy per tool, and the agent's identity and service.
4. Call both tools straight from the tool server, then through MCP Gateway.
5. Send one tool-calling request with the agent's key, and see the `tools` route answer it.
6. Run the agent at a prompt, then as a dark service that Ziggy dials.
7. Delete the math tool's dial policy mid-conversation, and put it back.

## What makes it an agent

1. **It chooses.** The model decides whether a tool would help, and which one.
2. **It calls.** It asks for that tool, with specific arguments.
3. **It loops.** It reads the result and decides what to do next, until it has an answer.

The model only asks for a call. `agent.py` makes it, through MCP Gateway, and allows at most five calls per question.
Everything but the choosing is ordinary code, and that code is where the network gets its say.

## The tool server

`tools/server.py` dials each service by name with `ztx.connect(service)`, and the standard library speaks HTTP over the
connection. There is no host and no port in the file. Three more choices in it:

- **Every failure becomes a `ToolError`.** MCP's Python SDK 2.x hides the text of any other exception and reports only
  `Error executing tool math`. A `ToolError` passes the message through, so when the network refuses a call, the agent
  hears about it.
- **It never prints to stdout.** stdout is the MCP stream. Its log lines go to stderr.
- **`classify` returns only the verdict.** When the classifier escalates, its log still shows its own score for the
  verdict the LLM overruled. Passing that score on would tell the agent a message is offensive with 84% confidence when
  the classifier meant the opposite.

## Policies by name, one per tool

Episode 1's policies matched by tag, `#classifier-clients`. This episode's match by name, with `@`: each names exactly
one identity and one service.

| Policy | Type | Identity | Service |
| --- | --- | --- | --- |
| `math-tool-dial` | Dial | `@appetizer-tools` | `@local_httpService` |
| `classify-tool-dial` | Dial | `@appetizer-tools` | `@classifier-service` |
| `agent-service-bind` | Bind | `@agent-service-host` | `@agent-service` |
| `agent-service-dial` | Dial | `#local_demo.clients` | `@agent-service` |

One dial policy per tool is what lets one tool go without touching the other. The last row lets every identity the
Appetizer hands out, Ziggy's included, talk to the agent.

The policies name the tool server's identity, not the caller's, so every agent session gets the same tools. Giving
different callers different tools needs policies that name the callers. That is episode 4.

## MCP Gateway

`mcp-gateway.yml` sets four things:

| Setting | What it does |
| --- | --- |
| `share_token` | The persistent share. The gateway serves through it, and listens on no port. Compose puts `SHARE` from `.env` here at start. |
| `separator: "_"` | Tools reach agents as `<backend id>_<tool>`, so `math` becomes `appetizer_math`. OpenAI and Anthropic allow only letters, digits, `_` and `-` in tool names. |
| `env_policy: closed` | Starts the tool server with exactly the variables listed under `env`. The gateway's own environment never reaches it. |
| `tools: mode: allow` | The operator's menu. A tool not on the list never reaches an agent. |

The gateway asks the tool server for its tools once, at start, and logs every call with its arguments. The allowlist is
config, read at start. A service policy is the network's version, checked on every dial.

The share is closed: only your zrok account can reach it. That matters, because anyone who can reach the gateway can
call the tools, and `classify` can escalate to Claude on your account.

## The agent's key and route

The agent sends every request with `model: "auto"` and its list of tools. LLM Gateway's `has_tools` rule runs before
semantic routing and sends such requests to the `tools` route. The agent's key works only there:

```yaml
    - name: agent
      key: "${AGENT_GATEWAY_KEY}"
      allowed_models: ["claude-haiku-4-5-*"]
      allowed_routes: ["tools"]
```

The `agent` container holds that one key and no other. A leaked agent key reaches Claude Haiku for tool calls, and
nothing else.

## Identity instead of login

When Ziggy dials `agent-service`, the agent logs `connection from local_ziggy`. It knows who is asking from the identity
on the overlay, with no login and no token, and keeps each caller's conversation separate by that name.

## Take the tool away

Deleting `math-tool-dial` restarts nothing. The tool server still runs, and MCP Gateway still offers `appetizer_math`,
because it read its tools at start. The menu lists the tool; the network will not serve it. OpenZiti refuses the dial,
and its Python SDK reports the refusal as a dropped connection.

The agent's system prompt tells Claude to use the math tool for any arithmetic and never to work it out itself. So
Claude does not answer 42 on its own. That is a request, not a control. If Claude ever answers 42 anyway, the network
still did its job: you cannot take away what a model already knows, only what it can reach.

## In your own application

- Make each tool a dark service, with its own policy.
- Give the tool server its own identity, so the network decides what it can reach.
- Put a gateway between agents and tools: one endpoint with no open port, an allowlist, every call logged, and
  `env_policy: closed`.
- Route tool-calling requests on purpose, and give agents keys restricted to that route.
- Do not treat a prompt as a control.
- Make refusals visible. An agent can only explain a failure it can see.

This is the compose version of Joey's
[original walkthrough](https://github.com/AccordionGuy/openziti-appetizer-meets-mcp-gateway), which runs the tool server
and the agent natively on a Mac.
