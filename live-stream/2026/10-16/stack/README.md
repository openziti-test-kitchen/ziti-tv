# The Appetizer agent arc, as one docker compose project

This directory holds the four episodes that turn the [OpenZiti Appetizer](https://openziti.io/docs/learn/appetizer/)'s
dead classifier call into an agent whose tool permissions are OpenZiti service policies. Each episode runs in docker
compose, so the host needs Docker, git, curl and, from episode 2 on, jq. Episode 2 adds a Claude API key, and episode 3
a zrok account. The `zrok2` CLI runs in a container.

Do the episodes in order. Each one starts from the stack the one before it leaves running, and adds its own services
and policies with `docker compose exec quickstart ziti ...`:

1. [Episode 1: the classifier](ep1-classifier/README.md), with the steps in [LAB.md](ep1-classifier/LAB.md). The
   Appetizer reaches an offensive-speech classifier as an OpenZiti service with no open port.
2. [Episode 2: LLM Gateway](ep2-llm-gateway/README.md), with the steps in [LAB.md](ep2-llm-gateway/LAB.md). The
   classifier asks an LLM for a second opinion when it is unsure.
3. [Episode 3: MCP Gateway and the agent](ep3-mcp-gateway/README.md), with the steps in
   [LAB.md](ep3-mcp-gateway/LAB.md). An agent whose tools are dark services, one dial policy per tool.
4. [Episode 4: taking tools from strangers](ep4-byo-tools/README.md), with the steps in
   [LAB.md](ep4-byo-tools/LAB.md). Strangers bring their own tools to the agent, and the network decides whose each
   one is.

| Path | What it holds |
| --- | --- |
| `compose.yml` | Every service in all four episodes. Each episode's README says which ones it starts. |
| `default.env` | The settings, with placeholders. Copy it to `.env`. |
| `runtime.Dockerfile` | The image for LLM Gateway, MCP Gateway, the agent and the clients. |
| `ziti/` | The edge router's config and bootstrap. |
| `ep1-classifier/` | The classifier and its image. |
| `ep2-llm-gateway/` | LLM Gateway's config, and shell helpers for calling it. |
| `ep3-mcp-gateway/` | MCP Gateway's config, the tool server and the agent. |
| `ep4-byo-tools/` | Episode 4's walkthrough. Its code is in `../files/`. |
| `../files/` | Episode 4's tool hosts, client and agent. |

`./.ziti` holds the whole network: the controller's PKI, its database and every identity. `docker compose down` keeps
it. Deleting it means a new network, and every identity enrolled against the old one stops working.

The files under `ep*/` come from Joey's episode repositories, with paths changed to fit the containers.
[`../episode-drift.md`](../episode-drift.md) lists where those repositories disagree with each other, and what this
directory does about each.
