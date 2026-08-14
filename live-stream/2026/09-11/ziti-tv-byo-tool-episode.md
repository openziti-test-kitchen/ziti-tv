# 2026-09-11: bring your own tool

Episode 4 of the arc in [`season-arc.md`](../season-arc.md).

Episodes 1 through 3 gave the agent tools we host. This one reverses the direction: a viewer supplies a tool from their
own machine, and the agent starts using it.

## What the viewer does

Runs a client that binds a service — the same `ctx.ListenWithOptions` shape as `CreateZitiListener`, now on their
laptop. No port opened, no tunnel, no ngrok, nothing inbound.

## What the appetizer does

Creates the service, a bind policy for that identity, and a dial grant for the agent. Same management-API path
`Prepare` already uses in `manage/manage.go` — this is one more service and two more policies, not new machinery.

The agent's tool list becomes: the services it may dial that carry a tool role attribute.

## Two rules it does not work without

1. **The agent offers only tools bound by the identity it is currently talking to.** `conn.SourceIdentifier()` gives
   that for free. Without it, one stranger's tool runs inside another stranger's conversation.
2. **Tool output enters the model's context.** This is prompt injection from an untrusted party, by design. Name it on
   camera rather than letting a commenter name it. It is the interesting problem here, not a flaw in the demo.

## Payoff

A tool running on a laptop with nothing exposed, called by an agent that only knows its name. Then close the laptop:
the tool dies with `service <id> has no terminators` — the same error the 08-14 episode spent a paragraph explaining.

## Worth arguing about

Whether a stranger's tool should be callable at all, and what the appetizer would have to do to make that safe. There
is no clean answer, which is why it is worth the segment.
