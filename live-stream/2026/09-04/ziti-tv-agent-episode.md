# 2026-09-04: the agent, and the network that governs it

Episode 3 of the arc in [`season-arc.md`](../season-arc.md).

Episodes 1 and 2 made a model reachable over the overlay. This one lets it decide what to do, and lets the network
decide what it is allowed to do.

## What makes it an agent

Responding to messages is a chatbot. Choosing among actions, calling tools, and looping on the result is an agent. The
reflect server gets two tools, both already dark services:

- `math` — `local_httpService/domath`, the one from the 08-14 episode
- `classify` — episode 1's classifier

Math first, because 6 * 7 = 42 is checkable on camera. Classify second, so the agent is choosing rather than always
doing the same thing.

## What comes free from the overlay

`conn.SourceIdentifier()` at `overlay/reflectServer.go:163` is the caller's cryptographic identity — the agent's
session key and user context, with no application authentication, no cookies, no bearer token.

## Service policy is the tool-permission boundary

What the agent may dial is what the agent may do, enforced by the network rather than by a prompt, an allowlist in
code, or a framework's config file.

## Payoff

Ask for `6 * 7`. Watch the tool call, watch 42 come back.

Then revoke the dial policy live and ask again. The tool is gone and nothing in the agent changed.

## Prior art in the repo

- `overlay/reflectServer.go` — the accept loop, `SourceIdentifier`, the SSE push to `/messages.html`
- `overlay/httpServer.go` — the same listener trick for `net/http`
- `clients/common/common.go` — `NewZitifiedHttpClient`, for the agent dialing a tool by name

## Consequence to decide before recording

Tool calling against an OpenAI-compatible endpoint works through episode 2's llm-gateway without MCP. If the tool
protocol should be MCP from the start, episode 5 moves forward and this one gets longer.
