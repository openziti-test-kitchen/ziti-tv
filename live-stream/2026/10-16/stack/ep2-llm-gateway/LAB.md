# Episode 2 lab: LLM Gateway

The steps for [episode 2](README.md). The README explains what each step shows.

The commands are tagged **[ubuntu]** because the series is recorded on WSL, and **[brave]** for the browser. On Linux
and macOS the commands are all one shell. Use the three shells from episode 1, all in the `stack` directory, and a
fourth for the gateway's log. Each block says which.

## 1. Start from where episode 1 ended

The classifier from episode 1 has to be hosting `classifier-service`.

**[ubuntu]** commands

```sh
cd ziti-tv/live-stream/2026/10-16/stack
docker compose ps -a
docker compose exec quickstart ziti edge list terminators
```

`ps` lists `quickstart`, `router`, `appetizer` and `classifier` as `Up`. The terminators include `classifier-service`.
If they do not, do [episode 1's lab](../ep1-classifier/LAB.md) first. If the login has expired, repeat episode 1's
step 5.

## 2. Get a Claude API key with a spending limit

The Claude Console keeps API keys, billing and spending limits, separate from a Claude chat subscription. Its Default
workspace cannot have a spending limit of its own, so make a workspace for this series.

**[brave]**

1. Open **https://platform.claude.com**, go to **Settings → Workspaces** and click **Add Workspace**. Name it
   `ziti-tv`.
2. In the new workspace's **Limits** tab, set the spend limit to **$5** and add an email notification at **$1**.
3. Go to **API keys**, check that the workspace selector says `ziti-tv`, and create a key. Copy it.

At the limit, the API returns HTTP 400 and the classifier keeps its own verdict.

## 3. Put every key in `.env`

The gateway issues its own keys, so no caller holds the Anthropic key. Make three: one for the classifier, one for
you, and one for episode 3's agent.

**[ubuntu]** commands

```sh
# genkey prints one sk-gw- key. This writes each into .env without showing it
for k in CLASSIFIER MY AGENT; do
  key=$(docker compose run --rm -T --no-deps llm-gateway llm-gateway genkey)
  sed -i "s|^${k}_GATEWAY_KEY=.*|${k}_GATEWAY_KEY=${key}|" .env
done
grep -c '=sk-gw-.\{20\}' .env              # 3

# episode 1 switched the second opinion off with this line
sed -i '/^CLASSIFIER_GATEWAY_URL=$/d' .env
```

Open `.env` in an editor and replace `sk-ant-...` with the key from step 2. Never `cat` this file where people can see
your screen.

## 4. Start Ollama and the gateway

**[ubuntu]** commands

```sh
docker compose up -d --wait llm-gateway    # Ollama, then the two model pulls, then the gateway
```

The first start pulls `gemma3:4b` and `nomic-embed-text`, about 4 GB. The gateway listens only after it has embedded
every route example, so `--wait` returns when it can route.

**[ubuntu]** gateway log

```sh
docker compose logs -f llm-gateway
```

## 5. Load the helpers

`ask` and `judge` build the JSON with jq and send it with curl.

**[ubuntu]** commands

```sh
sudo apt install -y jq

set -a; . ./.env; set +a                   # the keys, for ask and judge
GATEWAY=127.0.0.1:${GATEWAY_PORT:-8080}
. ep2-llm-gateway/helpers.sh               # source it: run with sh, the functions vanish with the child shell
type ask                                   # ask is a function
```

## 6. Show that a key limits its caller

**[ubuntu]** commands

```sh
ask gemma3:4b hi                                               # no key
ask gemma3:4b hi "$CLASSIFIER_GATEWAY_KEY"                     # the classifier's key, an allowed model
ask claude-opus-5-5 hi "$CLASSIFIER_GATEWAY_KEY"               # a model the key does not allow
ask claude-haiku-4-5-20251001 "say hi" "$CLASSIFIER_GATEWAY_KEY"
```

```text
error → API key required
gemma3:4b → Hi there! ...
error → model 'claude-opus-5-5' is not allowed for this API key
claude-haiku-4-5-20251001 → Hi! ...
```

The gateway log shows `key 'classifier' denied access to model 'claude-opus-5-5'`. The last reply came from Claude, for
a caller that has never held the Anthropic key.

## 7. Watch the router choose

`judge` sends the classifier's exact request: `model: "auto"`, the moderator prompt and the classifier's key.

**[ubuntu]** commands

```sh
judge "you are a delight"
judge "nobody here wants you around and everyone knows it"
judge "people like you should not be allowed to speak"

docker compose logs llm-gateway | grep -o 'semantic routing: [^"]*' | tail -3
```

```text
gemma3:4b → CLEAN
claude-haiku-4-5-20251001 → OFFENSIVE
claude-haiku-4-5-20251001 → OFFENSIVE
```

With Ollama on CPU, each takes 10 to 15 seconds: the local model is the slow part, even when Claude answers.

Each log line ends with `cascade=[...]`, which shows the path. Every cascade starts `heuristic:no_match`: the
`has_tools` rule that episode 3 uses did not apply.

| Phrase | Cascade, after `heuristic:no_match` |
| --- | --- |
| `you are a delight` | `semantic:general:0.51:no_match,default:general`: below 0.65, the default route |
| `nobody here wants you around...` | `semantic:subtle:0.68:ambiguous,classifier:subtle:0.95`: the tie-breaker picked subtle |
| `people like you should not...` | `semantic:subtle:0.69:ambiguous,classifier:subtle:0.95`: the same |

Your scores can differ a little. If a subtle phrase lands in `general`, add an example to the `subtle` route in
`ep2-llm-gateway/llm-gateway.yml` that is not one of these phrases, and run `docker compose restart llm-gateway`.

## 8. Switch the second opinion on

Step 3 removed `CLASSIFIER_GATEWAY_URL=`, so the classifier's `GATEWAY_URL` is now `http://llm-gateway:8080`, and it
has a real key. Compose recreates the container with both.

**[ubuntu]** commands

```sh
docker compose up -d classifier
docker compose exec classifier printenv GATEWAY_URL    # http://llm-gateway:8080
```

**[ubuntu]** logs

```sh
docker compose logs -f classifier          # wait for: binding ziti service classifier-service
```

In the client, run `docker compose run --rm reflect` if it is not still running, and send each of these. Watch the
classifier log and the gateway log after each. An escalated message takes as long as `judge` did before the reply
comes back.

| Send | Client | Classifier log |
| --- | --- | --- |
| `you are a delight` | relayed | `clean by=gemma3:4b` |
| `nobody here wants you around and everyone knows it` | not relayed | `OFFENSIVE by=claude-haiku-4-5-20251001` |
| `people like you should not be allowed to speak` | not relayed | `OFFENSIVE by=claude-haiku-4-5-20251001` |
| `you are too stupid to understand this` | not relayed | `OFFENSIVE by=classifier` |
| an English swear word | rejected by the Appetizer | nothing |

The second line is the message that passed in episode 1. The log still shows the classifier's own label,
`non-offensive` at 0.84. It was under 0.9, so it asked, and Claude disagreed. The insult never escalated: the
classifier was confident, so no LLM was asked.

## 9. Move the subtle route with one line

Suppose user messages may not go to a third-party API. Move the `subtle` route to the local model.

**[ubuntu]** commands

```sh
# only the subtle route's model line carries this comment
sed -i '/LAB.md step 9 swaps this line/s#claude-haiku-4-5-20251001#"gemma3:4b"#' ep2-llm-gateway/llm-gateway.yml
grep -n 'step 9' ep2-llm-gateway/llm-gateway.yml

docker compose restart llm-gateway
docker compose up -d --wait llm-gateway    # returns when it routes again
```

In the client, send `nobody here wants you around and everyone knows it` again. The gateway log shows
`route='subtle' model='gemma3:4b'`, and the classifier log shows `by=gemma3:4b`. The classifier and the Appetizer did
not change. The classifier asked for `auto`, so the gateway can move the route anywhere.

Put Claude back:

**[ubuntu]** commands

```sh
sed -i '/LAB.md step 9 swaps this line/s#"gemma3:4b"#claude-haiku-4-5-20251001#' ep2-llm-gateway/llm-gateway.yml
docker compose restart llm-gateway
docker compose up -d --wait llm-gateway
```

## 10. Take the backend away

**[ubuntu]** commands

```sh
docker compose stop ollama
```

In the client, send `nobody here wants you around and everyone knows it`. It is relayed. The classifier log shows why:

```text
escalation refused (500): {"error":{"message":"request failed: Post \"http://ollama:11434/v1/chat/completions\": dial tcp: lookup ollama on 127.0.0.11:53: server misbehaving" ...
clean by=classifier {'label': 'non-offensive', 'score': 0.84...} :: nobody here wants you around and everyone knows it
```

The name `ollama` no longer resolves, because a stopped container leaves the compose network.

**[ubuntu]** commands

```sh
docker compose logs llm-gateway | grep -oE '(embedding match error|semantic routing|provider error)[^"]*' | tail -3
```

The router could not embed the message, fell back to `general`, and `general` is on Ollama too. Claude was never
asked.

**[ubuntu]** commands

```sh
docker compose start ollama                # the models reload on first use
```

## Where this leaves you

Leave the stack running. Episode 3 starts from here: it puts tools on the OpenZiti network behind MCP Gateway, and
gives an agent the third key you made in step 3.

To stop, run `docker compose down`. `docker compose up -d --wait llm-gateway` and `docker compose up -d appetizer
classifier` bring it back. The models stay in the `ollama` volume.

To switch the second opinion off again, put `CLASSIFIER_GATEWAY_URL=` back in `.env` and run
`docker compose up -d classifier`.

## Troubleshooting

**`command not found: ask`.** `helpers.sh` is not loaded in this shell, or it ran in a child shell. Source it:
`. ep2-llm-gateway/helpers.sh`.

**`ask` prints `jq: command not found` or nothing at all.** jq is missing. `sudo apt install -y jq`.

**`ask` prints `error → ...` with no message, or curl fails to connect.** The gateway is not up yet, or `GATEWAY`
points at the wrong port. `docker compose ps llm-gateway` should show `(healthy)`, and `GATEWAY` should match
`GATEWAY_PORT` in `.env`.

**`docker compose up` fails with `Bind for 127.0.0.1:8080 failed: port is already allocated`.** Something else on the
host has 8080. Set `GATEWAY_PORT` in `.env` to a free port, and set `GATEWAY` to match.

**The classifier log shows `by=classifier` for every message.** The classifier still has episode 1's empty
`GATEWAY_URL`. Check that `CLASSIFIER_GATEWAY_URL=` is gone from `.env`, then run `docker compose up -d classifier`.
`docker compose restart` keeps the old environment.

**`escalation refused (401)`.** The classifier's key is the placeholder, or it changed after the gateway started. Check
step 3, then run `docker compose up -d llm-gateway classifier` so both get the same key.

**`escalation refused (403)`.** The route's model is not in the classifier key's `allowed_models`. Widen it in
`llm-gateway.yml`, or route to a model it allows.

**`escalation refused (400)` mentioning usage limits.** The Console spending limit was reached. Raise it, or route
`subtle` to a local model as in step 9.

**`escalation failed ... timed out`, mostly on the first message after a long idle.** Ollama was loading a model.
Compose runs it with `OLLAMA_KEEP_ALIVE=-1`, so this happens only after Ollama itself restarts. Send the message again.

**A subtle message is answered by `gemma3:4b`, and its cascade ends `classifier:error,default:general`.** The
tie-breaker timed out. On CPU, `gemma3:4b` takes 10 to 15 seconds to pick a route, and `timeout_ms` under `classifier`
in `llm-gateway.yml` is 25000 for that reason. On a slower machine, raise it, but keep the whole escalation under the
classifier's 30-second limit. Or point `OLLAMA_URL` at an Ollama with a GPU.

**Every request routes to `general` with `confidence=0.00`.** The thresholds are too strict for your examples, or the
classifier layer is off. Keep `classifier.enabled: true` in `llm-gateway.yml`, and lower `threshold` a little. In
testing, turning that layer off also changed the semantic scores.

**`mapping values are not allowed in this context` when the gateway starts.** A hand edit left a stray `: `, as in
`gemma3: 4b`. Quote the value: `model: "gemma3:4b"`.
