# Arc: from a dead classifier to somebody else's agent

Five episodes. Through-line: **the network decides what the model may reach, and what an agent may do.**

The appetizer has been calling a model over the overlay since 2023 — `IsOffensive` in `overlay/reflectServer.go` POSTs
to `classifier-service` over a zitified `http.Client`. It has not worked in a long time. Episode 1 fixes it.

---

## 1. Make the classifier real

**Payoff on screen:** the amber "can't be qualified at this time for offensiveness" turns green, then red for
something offensive, with the Mattermost poll firing.

- Fix the blocker first: `reflectServer.go:241` hardcodes `http://classifier-service:80/api/v1/classify`, unprefixed.
  A `local_` instance has no such service, so `IsOffensive` always returns `COULD_NOT_CLASSIFY`. Route it through
  `PrefixedName` or an env var. This one commit explains the amber message every viewer has seen.
- Stand up a hate-speech classifier behind `classifier-service`. The existing contract is a HuggingFace
  text-classification pipeline: request `{"text": "..."}`, response `[{"label": "Offensive", "score": 0.97}]`.
- Bind it as a dark service so the model has no address either. Two dark services talking by name.
- `goaway.IsProfane` at `:128` short-circuits before the model — say so, or the demo looks like the model caught
  something it never saw.

**Decision on camera:** ollama's `/api/generate` does not return `[{label,score}]`. Either shim it, or change
`IsOffensive`. That difference *is* the difference between a classifier and an LLM.

---

## 2. Put llm-gateway in the middle

**Payoff on screen:** swap the model behind `classifier-service` with zero changes to the appetizer.

- Same classification, now through `llm-gateway`. Explore its config: routing, virtual API keys, multi-endpoint load
  balancing, fallback.
- Phase 1 of `llm-mcp-integration-plan.md`: `overlay/proxyServer.go` binds the service, reverse-proxies to a loopback
  sidecar, `FlushInterval = -1` for SSE.
- Add `llmService` and `clients/llmproxy.go` on `127.0.0.1:8080`, so an unmodified OpenAI client talks to a model
  endpoint with no address. `ss -ltn` on the server shows nothing listening.

**Say out loud:** a fine-tuned classifier beats an LLM here on latency, cost and determinism. Doing it anyway, and
explaining why, is more credible than calling it an upgrade.

---

## 3. The agent

**Payoff on screen:** ask the reflect server `what is 6 * 7`, watch it call the math tool and answer 42 — then revoke
the service policy live and watch the tool disappear from the agent's hands.

- The reflect server asks a model what to do with each line. Two tools, both already dark services: `math`
  (`local_httpService/domath`) and `classify`.
- Math first, because the answer is checkable on camera. Classify second, so the agent is choosing rather than always
  doing the same thing.
- `conn.SourceIdentifier()` is the session key and the user context — cryptographic identity, no application auth, no
  cookies, no bearer token.
- **Service policy is the tool-permission boundary.** What the agent may dial is what the agent may do, enforced by
  the network rather than by a prompt or an allowlist in code.

---

## 4. Bring your own tool

**Payoff on screen:** a viewer binds a tool on their laptop and the agent starts using it. Nothing is exposed, no port
is opened, and the grant is a policy.

Episodes 1-3 gave the agent tools we host. Here a stranger supplies one.

- The user runs a client that binds a service — same `ctx.ListenWithOptions` shape as `CreateZitiListener`, now on
  their machine.
- The appetizer creates the service, a bind policy for their identity, and a dial grant for the agent. Same
  management-API path `Prepare` already uses in `manage/manage.go`.
- The agent's tool list is the set of services it may dial carrying a tool role attribute.

**Two rules it does not work without:**

1. **The agent offers only tools bound by the identity it is currently talking to.** `conn.SourceIdentifier()` gives
   that for free. Without it, one stranger's tool runs inside another stranger's conversation.
2. **Tool output enters the model's context**, so this is prompt injection from an untrusted party by design. Name it
   on camera.

**Free callback:** close the laptop and the tool dies with `service <id> has no terminators` — the same error episode
1 spent a commit explaining.

---

## 5. Somebody else's agent

**Payoff on screen:** an agent on a laptop with nothing installed uses tools that have no address.

- `mcp-gateway` exposes the tools; `gateway.NewWithListener(cfg, listener)` already takes a `net.Listener`, so the
  ziti side is a listener away.
- `clients/mcp.go` bridges stdio to the overlay: a few lines of `mcpServers` config and an external agent has tools on
  an endpoint nothing on the internet can reach.
- Close the loop back to episode 1: the first tool it gets is the classifier, which has been running this way since
  before anyone called it an agent.

**Risk to name, as the plan does:** every identity the appetizer ever minted can dial these, and identities go to
anyone who asks. `dummy-model` by default, MCP tools allowlisted read-only.

---

## Phase 3, whenever it lands

A `ziti:` transport upstream in both gateways, beside their zrok and Agora paths, deletes the appetizer's copy of the
wiring. Worth showing the code that disappears.
