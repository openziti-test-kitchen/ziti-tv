# Ziti TV, October 16, 2026: Taking tools from strangers

Episode 3 gave the Appetizer an agent whose tools are dark services, with one OpenZiti dial policy per tool. This
episode lets people who are not you bring their own tools to that agent, and shows what the network can and cannot
promise about them.

**The network decides whose tool it is. It cannot decide whether the tool is honest.**

You end up with:

- **Ziggy**, an honest user, hosting a `whereami` tool from her own machine. The agent uses it when Ziggy asks, and
  never when anyone else does.
- **Mallory**, who tries to host her tool under Ziggy's name and is refused by the network. She then hosts her own
  tool, with a prompt injection in its description and its output.
- A demonstration that the network keeps Mallory's injection inside Mallory's own conversation, but cannot make her
  tool's text trustworthy.

## Where to start

Everything runs in one docker compose project, in [stack/](stack/README.md). The host needs Docker, git, curl and jq,
a Claude API key and a [zrok](https://docs.zrok.io) account.

- Starting from an empty directory: do episodes 1 to 3 first. [stack/README.md](stack/README.md) lists them in order,
  each with a README that explains it and a LAB with the steps.
- With episode 3's stack still running: go straight to
  [episode 4's README](stack/ep4-byo-tools/README.md) and its [LAB](stack/ep4-byo-tools/LAB.md).

## What is here

| Path | What it holds |
| --- | --- |
| `stack/` | The four episodes as one compose project, each episode in its own directory. |
| `files/` | Episode 4's code: the agent, `byo/host.py`, `byo/dial.py`, and the two tools. |
| `episode-drift.md` | Where episodes 1 to 3's original repositories disagree with each other, and what `stack/` does about each. |
