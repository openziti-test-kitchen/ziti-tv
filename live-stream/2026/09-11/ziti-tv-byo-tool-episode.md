# 2026-09-11: bring your own tool

Episode 4 of the arc in [`season-arc.md`](../season-arc.md).

Episodes 1 through 3 gave the agent tools we host. Here a viewer supplies one from their own machine.

## What the viewer does

Runs a client that binds a service — the same `ctx.ListenWithOptions` shape as `CreateZitiListener`, now on their
laptop. No port opened, no tunnel, no ngrok, nothing inbound.

## What the appetizer does

Creates the service, a bind policy for that identity, and a dial grant for the agent. Same management-API path
`Prepare` already uses in `manage/manage.go` — one more service, two more policies.

The agent's tool list becomes: the services it may dial that carry a tool role attribute.

## Two rules it does not work without

1. **The agent offers only tools bound by the identity it is currently talking to.** `conn.SourceIdentifier()` gives
   that for free. Without it, one stranger's tool runs inside another stranger's conversation.
2. **Tool output enters the model's context.** This is prompt injection from an untrusted party, by design. Name it on
   camera rather than letting a commenter name it.

## Payoff

A tool running on a laptop with nothing exposed, called by an agent that only knows its name. Then close the laptop:
the tool dies with `service <id> has no terminators` — the same error the 08-14 episode spent a paragraph explaining.

## Worth arguing about

Whether a stranger's tool should be callable at all, and what the appetizer would have to do to make that safe.
