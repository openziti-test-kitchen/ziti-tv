# 2026-09-25: delete it, use Agora

Episode 6 of the arc in [`season-arc.md`](../season-arc.md).

Episodes 4 and 5 hand-rolled a tool catalog and a permission model out of services, policies and role attributes.
https://github.com/openziti/agora already did that, properly. This episode deletes ours.

## What Agora is

A zero-trust overlay for agent-to-agent communication built on OpenZiti, A2A-compatible at the protocol layer.

- **Layer 0** — OpenZiti: identity, mutual auth, end-to-end encryption, dark by default. Everything episodes 0-5 used.
- **Layer 1** — organizations, accounts, environments, tunnels, tunnel grants.
- **Layer 2** — workgroups, catalog, advertisements, sessions, contracts, envelopes.

Layer 2 is where our hand-rolled version dies.

## What gets deleted

| Ours | Agora's |
|---|---|
| tool role attribute as a registry | the catalog, with named capabilities |
| the appetizer minting a service and two policies per tool | `catalog.EnsurePublished` with a workgroup scope and a contract |
| dial policy on or off | sessions bounded by contracts |
| SSE messages page as the only record | auditable envelopes |

```go
ad, err := catalog.EnsurePublished(ctx, a, catalog.PublishSpec{
    Name: "llm-gateway",
    Capabilities: []catalog.Capability{{Name: "llm-routing"}},
    WorkgroupScopeIDs: []string{"wg_..."},
    TunnelMode:        catalog.TunnelTCP,
    ContractID:        "con_...",
})
```

That is the SDK's own example, and it publishes an llm-gateway.

## The two things we never got to

**Cross-organization.** The whole arc so far is one appetizer, one network, one org. Agora's `examples/macro-pulse`
runs eight agents across five organizations where no provider hands its raw feed to anyone — the client discovers
capabilities, opens bounded sessions under contracts, and composes a result. Run it.

**A2A.** Episodes 3-5 were agent-to-tools over MCP. Agent-to-agent is what Agora is for.

## Payoff

The appetizer's tool wiring gone, replaced by catalog publish and session open, with the agent behaving identically —
then something episodes 1-5 could not do at all: an agent in another organization using a capability without either
side seeing the other's network.

## Say out loud

Everything episodes 0-5 built is Layer 0 and a hand-rolled Layer 2. Naming that is more useful to a viewer than
pretending the DIY version was the destination.

## Before recording

`./bin/demo-up.sh` needs external PostgreSQL and OpenZiti matching `etc/demo-controller.yaml`, plus Node for the
dashboard. Stand up macro-pulse once beforehand — it is not a first-take demo.
