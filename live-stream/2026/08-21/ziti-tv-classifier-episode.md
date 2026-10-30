# 2026-08-21: make the classifier real

Episode 1 of the arc in [`season-arc.md`](../season-arc.md). Starts from a working appetizer — the 08-14 walkthrough
gets you there. Do that before recording.

## The bug that opens the episode

`overlay/reflectServer.go:241` hardcodes the classifier URL:

```go
url := "http://classifier-service:80/api/v1/classify"
```

Unprefixed. A `local` instance creates `local_*` services, so `classifier-service` does not exist on it and
`IsOffensive` always returns `COULD_NOT_CLASSIFY` — the amber "can't be qualified at this time for offensiveness"
every viewer of the last episode saw.

Fix: route it through `common.PrefixedName`, or make it an env var.

## What the classifier contract actually is

- Request: `{"text": "..."}`
- Response: `[{"label": "Offensive", "score": 0.97}]`

That is a HuggingFace text-classification pipeline, not a chat API. `reflectServer.go:268-281` unmarshals an array and
matches `label == "Offensive"`.

`goaway.IsProfane` at `:128` runs first and short-circuits before the model is consulted. Say that out loud, or the
demo appears to show the model catching something it never saw.

Three outcomes drive the UI at `:139-159`: `OFFENSIVE` is red and fires a Mattermost poll asking humans whether it was
actually offensive; `NOT_OFFENSIVE` is green; `COULD_NOT_CLASSIFY` is amber and relays anyway.

## What gets built

- A hate-speech classifier behind `classifier-service`, served by ollama or a HF pipeline.
- Bound as a dark service, so the model has no address either. Two dark services talking by name.

## The decision to make on camera

ollama's `/api/generate` does not return `[{label,score}]`. Either write a shim that adapts it, or change
`IsOffensive` to parse a chat response. That difference is the difference between a classifier and an LLM.

## Payoff

Send something clean: green, relayed. Send something offensive: red, blocked, Mattermost poll fires. The amber message
is gone.

## Say out loud

The human-in-the-loop poll has been in this code for two years. Ask the audience what that is, if not the feedback
loop everyone is now building for their models.
