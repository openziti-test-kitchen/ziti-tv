# 2026-08-21: a dark LLM endpoint

Part two. The 08-14 episode built an appetizer from an empty directory and ended on a written LLM/MCP integration plan
that nobody had built. This one builds phase 1 of it, on camera.

Start from a working stack. [`ziti-tv-appetizer-episode.md`](../08-14/ziti-tv-appetizer-episode.md) gets it there —
clone, build, up, trust the CA, verify. Do that before recording this time; it is not the show twice.

## Which gateway

**llm-gateway is the one.** An OpenAI-compatible endpoint that any unmodified client can point at is a demo people
already understand, and the payoff sentence is one line: no public IP, no open port, no API key to leak.

**mcp-gateway is the better argument but the harder demo.** It is relevant — an agent getting tools from an endpoint
with no address is the more interesting claim — but proving it on camera means an agent, a tool call, and a stdio
bridge, which is three moving parts before anything visible happens. It also has the easier code path
(`gateway.NewWithListener(cfg, listener)` already takes a `net.Listener`; llm-gateway has no equivalent), so it is
tempting for the wrong reason.

Lead with llm-gateway. Land mcp-gateway as the closing segment if the pacing holds, or as part three.

## What gets built

Phase 1 from the plan, nothing further:

- `overlay/proxyServer.go` — binds `llmService` with `ctx.ListenWithOptions`, reverse-proxies to a loopback sidecar,
  `FlushInterval = -1` because chat completions are SSE
- the image gains `llm-gateway` and `dummy-model` as sidecars, plus `etc/llm-gateway.yml`
- `clients/llmproxy.go` — listens on `127.0.0.1:8080`, forwards over the overlay, so an unmodified OpenAI client works

The shape is the same trick from last week's `CreateZitiListener` segment, pointed at a different backend. That is the
callback worth making explicitly.

## The moment to build toward

An unmodified OpenAI client — the `openai` python package, or `curl` against `127.0.0.1:8080/v1/chat/completions` —
talking to a model endpoint that has no address. Then `ss -ltn` on the server showing nothing listening, and a port
scan finding nothing.

## Decisions to make on camera

- **Proxy hop vs embed.** The plan argues for the hop: importing either gateway pulls zrok, the Agora SDK and a second
  `sdk-golang` pin into a module that also builds for wasm. Worth stating and inviting disagreement, since it is the
  part of the plan most likely to be wrong.
- **`dummy-model` as the shipped default.** Every identity the appetizer ever minted can dial this, and identities go
  to anyone who asks. A real model behind it needs something more.
- **What phase 3 deletes.** A `ziti:` transport upstream in llm-gateway, beside its zrok and Agora paths, makes the
  appetizer's copy of the wiring deletable. Show the code that would disappear.

## Open before recording

1. Does `llm-gateway` build and run against `dummy-model` on plain loopback, with no ziti in the picture? Prove that
   first — the plan's step 1.
2. What does the ziti reverse proxy need beyond `FlushInterval = -1` for SSE to survive the hop?
3. Is there a real model worth pointing at for one shot, or is `dummy-model` the whole episode?
