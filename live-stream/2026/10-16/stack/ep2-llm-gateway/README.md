# Episode 2: a second opinion for the classifier, through LLM Gateway

Episode 1's classifier is fast, free and gives the same answer every time. It is also confidently wrong about messages
like this one:

> nobody here wants you around and everyone knows it

The model calls that `non-offensive`, at 84%. It was trained to spot insult vocabulary, and the sentence has none. This
episode keeps the classifier on that job, and when it is unsure, it asks an LLM for a second opinion. The question goes
to [LLM Gateway](https://github.com/openziti/llm-gateway), an open source OpenAI-compatible gateway, which decides
which LLM answers: a small model on your machine for everyday messages, and Claude for the subtle ones. None of the
Appetizer's code changes, and none of the classifier's: the second opinion has been in `classifier.py` since episode
1, switched off.

**The app decides whether to ask an LLM. The gateway decides which LLM answers.**

You end up with:

- LLM Gateway and Ollama in the compose project, with Claude behind the gateway.
- A virtual key for each caller, so the classifier never holds your Anthropic key and cannot use a model it was not
  given.
- Semantic routing that sends a subtle insult to Claude and a compliment to the local model.
- The classifier blocking the message it passed in episode 1.

This episode starts from the stack [episode 1](../ep1-classifier/README.md) leaves running. It adds jq on the host, a
Claude API key and about 4 GB of models. The steps are in [LAB.md](LAB.md). This page explains what they show.

## The pieces

| Piece | What it is | Where it runs |
| --- | --- | --- |
| LLM Gateway | A proxy that speaks the OpenAI chat-completions API and forwards each request to a provider. | `llm-gateway` container |
| Ollama | Runs the local models: `gemma3:4b` answers and breaks ties, `nomic-embed-text` makes embeddings. | `ollama` container |
| Claude Haiku 4.5 | The model for subtle messages, through the Anthropic API. | Anthropic |
| Virtual keys | `sk-gw-` keys the gateway issues, one per caller, each limited to some models and routes. | `.env` |
| `ask`, `judge` | Shell functions that send one request to the gateway, so nobody types JSON. | `helpers.sh`, on the host |
| Classifier | Episode 1's, unchanged. An empty `CLASSIFIER_GATEWAY_URL` kept its second opinion off. | `classifier` container |

`ollama-pull` is a one-shot container that pulls the two models before the gateway starts. The gateway listens on the
compose network as `llm-gateway:8080`, which is where the classifier reaches it, and on `127.0.0.1:8080` on the host,
for `ask` and `judge`. It is not on the OpenZiti network. Putting a gateway on the overlay is episode 3.

## What you do

1. Get a Claude API key from a workspace with a spending limit.
2. Generate three virtual keys and put every key in `.env`.
3. Start Ollama and LLM Gateway.
4. Show that a key limits what its caller may use.
5. Send the classifier's exact request for three phrases, and read why each went where it did.
6. Switch the second opinion on, and send five messages that each take a different path.
7. Move the subtle route to a local model with a one-line change.
8. Stop Ollama, and see what fails and what keeps working.

## Who decides what

The classifier asks only when its verdict is clean and its confidence is below `ESCALATE_BELOW`, 0.9. A confident
`offensive` stands, and a swear word never reaches the classifier, because the Appetizer's word filter rejects it
first. Most messages never leave the classifier, and cost nothing.

When it asks, it sends `"model": "auto"`. It does not pick a model, and it does not know Claude exists. That is what
lets whoever runs the gateway move a route to another model, or another provider, without touching the caller. It also
sends `"max_tokens": 5`: the answer is one word, and the cap bounds what a single call can cost.

Any failure, whether the gateway is down, a backend is down, a key is refused or the budget is spent, makes the
classifier keep its own verdict. That is the same fail-open choice the Appetizer made in episode 1.

## Keys

The gateway holds the one Anthropic key. Each caller gets a virtual key of its own, in `llm-gateway.yml`:

| Key | May use |
| --- | --- |
| `classifier` | `gemma3:*` and `claude-haiku-4-5-*`, on the `general` and `subtle` routes |
| `you` | anything, for trying the gateway with `ask` |
| `agent` | `claude-haiku-4-5-*`, on the `tools` route only. Episode 3's agent uses it. |

A refused model is refused before anything leaves your machine. LLM Gateway has no per-key spending limits yet, so the
spending limit lives in the Claude Console workspace. Claude Haiku 4.5 costs $1 per million input tokens and $5 per
million output tokens at the time of writing; an escalation is about 150 tokens in and a few out, about $0.0002.

## Routing

`llm-gateway.yml` has two routes for the classifier, each with five example phrases. None of them is a phrase the lab
tests with.

| Route | For | Model |
| --- | --- | --- |
| `general` | everyday messages: chat, compliments, questions | `gemma3:4b`, local |
| `subtle` | messages that exclude, silence or belittle someone without insults | Claude Haiku 4.5 |

A request for `auto` goes through three layers:

1. **Embeddings.** The gateway embeds the last user message with `nomic-embed-text` and scores it against every
   route's examples. `comparison: max` scores against the closest example rather than the average. 0.85 or more is a
   match.
2. **Tie-breaker.** Between 0.65 and 0.85 is ambiguous, and `gemma3:4b` reads the message and the route descriptions
   and picks one.
3. **Default.** Below 0.65 is no match, and the message goes to `default_route`, `general`.

Only the last user message is embedded. That is why the classifier puts its instructions in the system message and the
text being judged, alone, in the user message. Every routed request logs a `cascade=[...]` line that shows each layer's
score and decision.

## One box under everything

The embeddings, the tie-breaker and the `general` route all run on Ollama. When Ollama stops, the router cannot embed
the message, falls back to `general`, and that fails too. The request never reaches Claude, though Claude is up the
whole time. The classifier keeps its own verdict, so the Appetizer degrades instead of failing.

## In your own application

- Keep the "whether" in your app. Your code knows when a cheap, deterministic answer is good enough.
- Hand the "which" to the gateway. Ask for `auto` or a route, not a vendor's model name.
- Give every caller its own virtual key, limited to what it needs.
- Write route examples that describe categories, not test cases, and read the `cascade` lines.
- Know what shares a box.

This is the compose version of Joey's
[original walkthrough](https://github.com/AccordionGuy/openziti-appetizer-meets-llm-gateway), which also tours
round-robin pools and failover with LLM Gateway's `dummy-model` backend.
