# 2026-08-28: put llm-gateway in the middle

Episode 2 of the arc in [`season-arc.md`](../season-arc.md). Starts from episode 1's working classifier.

Same classification as last week, with a gateway between the appetizer and the model.

## What gets built

Phase 1 of the LLM/MCP plan, nothing further:

- `overlay/proxyServer.go` — binds a service with `ctx.ListenWithOptions`, reverse-proxies to a loopback sidecar,
  `FlushInterval = -1` because chat completions are SSE.
- The image gains `llm-gateway` and `dummy-model` as sidecars, plus `etc/llm-gateway.yml`.
- `llmService` as a second dark AI service, and `clients/llmproxy.go` listening on `127.0.0.1:8080` and forwarding
  over the overlay.

The shape is `CreateZitiListener` from the 08-14 episode pointed at a different backend.

## The configuration tour

- routing rules and how a request picks a backend
- virtual API keys, and what they replace
- multi-endpoint load balancing and fallback
- what happens when a backend is down

## Payoff

Point `classifier-service` at llm-gateway, then swap the model behind it with zero changes to the appetizer. The
service name is the stable interface; everything behind it moves.

Then `ss -ltn` on the host and a port scan: an OpenAI-compatible endpoint reachable by an unmodified client, listening
on nothing.

## Decisions on camera

- **Proxy hop vs embed.** The plan argues for the hop: importing either gateway pulls zrok, the Agora SDK and a second
  `sdk-golang` pin into a module that also builds for wasm. Invite disagreement.
- **`dummy-model` as the shipped default.** Every identity the appetizer ever minted can dial this, and identities go
  to anyone who asks.

## Say out loud

A fine-tuned classifier beats an LLM at this job on latency, cost and determinism. Doing it with an LLM anyway, and
explaining why, is more credible than calling it an upgrade.

## Before recording

Prove the plan's step 1: `llm-gateway` running against `dummy-model` on plain loopback, no ziti in the picture.
