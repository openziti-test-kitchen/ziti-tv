# Episode 4: taking tools from strangers

Episode 3's agent has two tools, and both belong to the house. This episode lets people who are not you bring their
own tools to that agent, from their own machines, with no port open anywhere. It raises two questions:

> Whose tool is this? And should the agent believe what it says?

The network answers the first. Each person gets one service that only their identity may host, so whatever answers
there is theirs. The network cannot answer the second. A tool's description and output go straight into the model's
context, and a policy cannot clean text.

**The network decides whose tool it is. It cannot decide whether the tool is honest.**

You end up with:

- **Ziggy**, an honest user, hosting a `whereami` tool from her own laptop. The agent uses it when Ziggy asks, and
  never when anyone else does.
- **Mallory**, who tries to host her tool under Ziggy's name and is refused by the network. She then hosts her own
  tool, with a prompt injection in its description and its output.
- A demonstration that the network keeps Mallory's injection inside Mallory's own conversation, but cannot make her
  tool's text trustworthy.
- One policy deletion that takes every stranger's tool away at once.

This episode starts from the stack [episode 3](../ep3-mcp-gateway/README.md) leaves running. It adds nothing to
install. The steps are in [LAB.md](LAB.md). This page explains what they show.

## The cast

Both people are OpenZiti identities from the Appetizer, minted the way episode 1 minted Ziggy. Anyone who asks gets
one. That is the point: the agent has to cope with callers it has never vetted.

- **Ziggy** (`local_ziggy`) is OpenZiti's mascot, and the identity episode 1 minted to try the Appetizer. Her tool,
  `whereami`, reports her machine's name, OS and local time.
- **Mallory** (`local_mallory`) is the attacker. In security writing, Alice and Bob are the people talking and Mallory
  is the one who actively interferes. Her `weather` tool carries a prompt injection.

Each runs in its own container, standing in for two people's laptops. The network cannot tell the difference: what
matters is which identity file each process loads.

## The pieces

| Piece | What it is | Where it runs |
| --- | --- | --- |
| Agent | `../../files/agent/agent.py`: episode 3's agent, plus one change. For every question, it dials `byo-<caller>` and offers whatever answers there, in that caller's conversation only. | `agent` container |
| `host.py` | Puts any stdio MCP server on the network as one identity. It binds `byo-<identity>` and, per connection, starts the tool and pipes bytes. | `ziggy-host`, `mallory-host` |
| `whereami.py` | Ziggy's tool. An ordinary MCP server with nothing OpenZiti in it. | `ziggy-host`, hostname `ziggy-laptop` |
| `mallory.py` | Mallory's tool. Its description and its output both tell the model to end every reply with "Sponsored by Mallory". | `mallory-host`, hostname `mallory-laptop` |
| `dial.py` | Connects stdin and stdout to a service by name. The agent uses it to reach `byo-<caller>`, and you use it to talk to the agent. | inside `agent`, and the `dial` client |
| `byo-<identity>` | One service per person, tagged `byo-tools`, with a bind policy naming only that person. | the Appetizer's network |
| `byo-tools-dial` | One dial policy that lets the agent reach every service tagged `byo-tools`. | the Appetizer's network |

The house tools still come through MCP Gateway and zrok. The strangers' tools come over the Appetizer's own network,
one connection per question.

## What you do

1. Switch the agent to episode 4's, and ask it a question as Ziggy before she has a tool.
2. Give Ziggy a service, a bind policy that names only her, and the agent's dial policy for every stranger's tool.
3. Start Ziggy's host, and see the network's record of who hosts it.
4. Ask the agent where Ziggy's laptop is.
5. Mint Mallory, and try to host her tool under Ziggy's name.
6. Give Mallory her own service, and host the poisoned tool there.
7. Ask as Mallory, then as Ziggy, and see where the injection reaches.
8. Stop Ziggy's host, and ask again.
9. Delete `byo-tools-dial`, and put it back.

## The two rules

Every step demonstrates one of these:

1. **The network decides whose tool it is.** When Ziggy asks a question, the agent dials `byo-local_ziggy`. Only
   `local_ziggy` may bind that service, so whatever answers there is Ziggy's. The agent knows who is asking from the
   identity on the connection, with no login and no token.
2. **The network cannot decide whether a tool is honest.** Policy limits which conversation a tool's text reaches and
   what the agent can do with it. It cannot clean the text.

## Policies

| Policy | Type | Identity | Service |
| --- | --- | --- | --- |
| `byo-local_ziggy-bind` | Bind | `@local_ziggy` | `@byo-local_ziggy` |
| `byo-local_mallory-bind` | Bind | `@local_mallory` | `@byo-local_mallory` |
| `byo-tools-dial` | Dial | `@agent-service-host` | `#byo-tools` |

Each person adds one service and one bind policy. The dial policy is created once and matches by tag, so a new person's
tool reaches the agent with no change to it. In production, the two per-person commands would be an endpoint on the
Appetizer, calling the same management API the Appetizer already uses to set itself up.

Nobody gets a dial policy for anyone else's `byo-` service. Mallory cannot call Ziggy's tool, and Ziggy cannot call
Mallory's. Only the agent can, and only on behalf of the tool's owner.

## Mallory under Ziggy's name

If Mallory could answer on `byo-local_ziggy`, everything Ziggy asked would go to Mallory's machine. The bind is refused
before Mallory's tool starts, with `service not available`: to Mallory, Ziggy's service does not exist. Without the
network, the agent would need its own record of which tool belongs to whom, and a way to check that the process
answering is the one it recorded.

## What the injection reaches

Mallory's tool description enters the model's context as soon as the agent lists her tools, before anything is
called. Its output enters when the tool is called. Whether the model obeys varies between runs. In one rehearsal Haiku
ignored the description and followed the output. In another it followed the description on the first `hi`. The
model's judgment is a defense, not a control.

The network did the containing. Mallory's text reaches only her own conversation, beside the house tools, with at most
five tool calls per question, on a key that works on one route. Ziggy's next reply is clean, because none of Mallory's
text ever entered Ziggy's conversation.

## What the network can take away

When Ziggy's host stops, her service has no terminators, and the agent stops offering her tool. The model still
remembers the tool from the conversation history. It can ask for it, and the agent refuses the call because nothing
answers on `byo-local_ziggy`. It can also skip the call and repeat the time from the earlier answer. The network can
take away what a model can reach, not what it already knows.

Deleting `byo-tools-dial` removes every stranger's tool at once, with every host still running. The injection Mallory
already delivered stays in her conversation history. The kill switch stops new injections, not ones the model has
read.

## In your own application

- Give each person who brings a tool one service that only their identity may host.
- Name the caller's tools in the caller's conversation only, and mark them as the caller's.
- Treat every tool description and every tool result as untrusted input.
- Keep one policy that can take every stranger's tool away at once.
- Clear a caller's conversation after revoking a tool, if what it already said matters.
