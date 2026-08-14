# 2026-09-18: somebody else's agent

Episode 5 of the arc in [`season-arc.md`](../season-arc.md). The close.

Everything so far has been our agent using tools. This one hands the toolset to an agent we do not control, running on
a machine we cannot reach.

## What gets built

- `mcp-gateway` exposing the tools from episodes 3 and 4. Its serve side is already done —
  `gateway.NewWithListener(cfg, listener)` takes a `net.Listener`, so the ziti side is a listener away.
- `clients/mcp.go` — a stdio-to-overlay bridge, which is `mcp-tools run <share>` with ziti in place of zrok.
  `mcp-gateway`'s own client does this with `mcp.SSEClientTransport{Endpoint, HTTPClient}`, and an `*http.Client` is
  exactly what `common.NewZitifiedHttpClient` returns.

## Payoff

A few lines of `mcpServers` config in someone's agent, and it has tools on an endpoint with no public IP, no open
port, and no API key to leak. Nothing on the internet can reach it. Their agent can.

## Close the loop

The first tool it gets is the classifier — the one that has been running this way since 2023, before anyone called it
an agent, and which episode 1 spent a commit resurrecting.

## Risk to name, as the plan does

Every identity the appetizer ever minted can dial these, and identities go to anyone who asks. Hence `dummy-model` as
the shipped default and MCP tools allowlisted read-only.

## Phase 3, whenever it lands

A `ziti:` transport contributed upstream to llm-gateway and mcp-gateway, beside their existing zrok and Agora paths,
deletes the appetizer's copy of the wiring. Show the code that disappears.
