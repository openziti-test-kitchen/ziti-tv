# Agent bootstrap: episode 4, taking tools from strangers

Instructions for a coding agent to bring the episode 4 stack to the go-live state, verify it, rehearse it, and reset
it. Source of truth for intent: `runbook-taking-tools-from-strangers.md` in this directory. This file is the same
content restated as executable steps with checks.

## Target state

Done means every item below is true. Check them all at the end (see "Final check").

1. Docker: `appetizer`, `classifier`, `quickstart`, `router` are `Up`. `init-ziti-dir` is `Exited (0)`.
2. Terminators include `local_httpService`, `local_reflectService`, `classifier-service`, `agent-service`.
3. Service policy `math-tool-dial` shows `@local_httpService` under `SERVICE ROLES`.
4. `docker compose exec classifier printenv GATEWAY_URL` prints `http://host.docker.internal:8080`.
5. `~/.ziti-demo/local_ziggy.json` and `~/.ziti-demo/local_mallory.json` exist (both enrolled).
6. No service policy whose name contains `byo` exists. No `byo-*` terminator exists.
7. Running: Ollama, LLM Gateway, MCP Gateway, the episode 4 agent (freshly started, no conversation history), and
   Ziggy's reflect client connected to `agent-service`.
8. Not running: `byo/host.py` (either identity), Mallory's reflect client.

## Inputs to confirm before starting

Ask the human for any of these you cannot find. Do not guess.

| Input | Default | How to check |
| --- | --- | --- |
| `APPETIZER` (Appetizer clone path) | none | contains `compose.yml`, `agent/`, `gateway/`, `clients/reflect.go` |
| Episode 4 zip | `~/Downloads/episode4-files.zip` | `unzip -l` lists `byo/grant.sh` and `agent/agent.py` |
| zrok share name used in episode 3 | `ziti-tv-appetizer` | `grep -n "mcp-tools run" agent/agent.py` |
| Anthropic credit balance | n/a | human checks Plans & Billing in the Anthropic Console |

Every command below runs with the working directory set to `$APPETIZER`, except `ollama serve`.

## Rules

- Run `ziti` only through `docker compose exec quickstart ziti ...`. A host-installed `ziti` is logged in to a
  different controller and fails with `x509: certificate is valid for ...`.
- Prefer `docker compose restart <svc>` over `docker compose up`. `up` recreates containers from the current shell's
  environment. If `up` is unavoidable, first run `. gateway/env.sh` and
  `export GATEWAY_URL=http://host.docker.internal:8080` in that same shell, or the classifier loses its escalation.
- After any `appetizer` restart, recreate `math-tool-dial` (step 3). The Appetizer recreates `local_httpService` on
  every start, which orphans the policy.
- Never delete the `openziti` docker volume or `docker compose down -v`. The volume is the whole network.
- Never rerun `agent/wire-up.sh` without running `reset.sh` afterward. `byo-tools-dial` names the agent identity that
  `wire-up.sh` recreates, and `grant.sh` does not replace an existing policy.
- `unset ZROK_TOKEN` in every shell that runs `ziti`, `mcp-gateway`, or the agent.
- Do not commit or print `.env`, `*.jwt`, identity `*.json`, or anything under `.ziti`.

## Process layout

The stack needs several long-running processes. Run each in its own named tmux window so its output can be read back
with `tmux capture-pane -p -t ep4:<name>` and input sent with `tmux send-keys -t ep4:<name>`. Window names match the
runbook's terminal numbers so the human can map them.

```sh
tmux new-session -d -s ep4 -n t1-commands -c "$APPETIZER"
for w in t2-ziggy-client t4-llm-gateway t6-mcp-gateway t7-agent t8-ziggy-host t9-mallory-host t10-mallory-client; do
  tmux new-window -t ep4 -n "$w" -c "$APPETIZER"
done
tmux new-window -t ep4 -n t5-ollama
```

Terminal 3 (classifier logs) is optional: `docker compose logs -f classifier`.

Reflect client command, referenced below as `REFLECT <service> <identity-file>`:

```sh
docker run --rm -it --network appetizer_default \
  -v "$PWD":/src -w /src -v ~/.ziti-demo:/jwt \
  -v ~/.ziti-demo-gomod:/go/pkg/mod \
  golang:1.25 \
  go run clients/reflect.go <service> /jwt/<identity-file>
```

It is interactive: it reads a line from stdin and prints the reply. Drive it with `tmux send-keys ... Enter`.

## Steps

Each step lists commands, then the check that must pass before moving on. On a failed check, use "Failure table".

### 1. Install the episode 4 files

```sh
cp agent/agent.py agent/agent.ep3.py          # skip if agent.ep3.py already exists; never overwrite it
unzip -o ~/Downloads/episode4-files.zip
grep -n "mcp-tools run" agent/agent.py agent/agent.ep3.py
```

Check:
- `byo/grant.sh`, `byo/reset.sh`, `byo/host.py`, `byo/dial.py`, `byo/check.py`, `byo/tools/whereami.py`,
  `byo/tools/mallory.py` exist.
- Both `grep` lines name the same zrok share. If not, edit `agent/agent.py` to use the share name from
  `agent.ep3.py`.

Optional: in `agent/agent.py`, append `"Use plain text, with no Markdown. "` to `SYSTEM` right after its first line.
Without it Haiku emits `**` in replies.

No new Python packages are needed.

### 2. Docker containers

```sh
docker compose ps -a
```

Check: target state item 1. Fixes:
- Containers `Exited (255)`: in t1, `. gateway/env.sh && export GATEWAY_URL=http://host.docker.internal:8080 &&
  docker compose up -d`, then do step 3.
- `appetizer` `Exited (1)` with `503` in `docker compose logs appetizer`: `docker compose restart appetizer`, then do
  step 3.

### 3. Controller login and `math-tool-dial`

```sh
unset ZROK_TOKEN
docker compose exec quickstart ziti login https://quickstart.127.0.0.1.nip.io:1280 \
  -u admin -p admin -y --ca /ziti/pki/root-ca/certs/root-ca.cert
docker compose exec quickstart ziti list service-policies 'name="math-tool-dial"'
```

If `SERVICE ROLES` is blank, recreate it:

```sh
docker compose exec quickstart ziti delete service-policy math-tool-dial
docker compose exec quickstart ziti create service-policy math-tool-dial Dial \
  --identity-roles '@appetizer-tools' --service-roles '@local_httpService'
```

Check: target state item 3.

### 4. Episode 3 processes, in this order

```sh
tmux send-keys -t ep4:t5-ollama 'ollama serve' Enter
tmux send-keys -t ep4:t4-llm-gateway '. gateway/env.sh && llm-gateway run gateway/llm-gateway.yml' Enter
tmux send-keys -t ep4:t6-mcp-gateway \
  'unset ZROK_TOKEN && which -a mcp-gateway && mcp-gateway run gateway/mcp-gateway.yml' Enter
```

Check:
- In t6, the first `which -a` line is `~/go/bin/mcp-gateway`. If not, fix `PATH` and restart t6.
- `.venv/bin/python tools/check.py gateway` passes and prints `appetizer_math: ok -> Result: 42.00`.
- `docker compose exec quickstart ziti list terminators` shows `local_httpService`, `local_reflectService`,
  `classifier-service`.
- `docker compose exec classifier printenv GATEWAY_URL` prints `http://host.docker.internal:8080`. If empty:
  `. gateway/env.sh && export GATEWAY_URL=http://host.docker.internal:8080 && docker compose up -d classifier`.

### 5. Enroll Mallory

Skip if `~/.ziti-demo/local_mallory.json` exists.

Minting is done through the Appetizer web page at `http://localhost:18000`: enter `mallory`, download
`local_mallory.jwt`. If you cannot drive the form (inspect the page source for the request it makes and replay it with
`curl`), stop and ask the human to do it. Then:

```sh
mv ~/Downloads/local_mallory.jwt ~/.ziti-demo/
```

Enroll by running the reflect client once in t10, `REFLECT local_reflectService local_mallory.jwt`. Wait for it to
connect, then send `C-c`.

Check: `~/.ziti-demo/local_mallory.json` exists. Also confirm `~/.ziti-demo/local_ziggy.json` exists; if only the
`.jwt` exists, enroll Ziggy the same way.

### 6. Start the agent and Ziggy's client

```sh
tmux send-keys -t ep4:t7-agent 'unset ZROK_TOKEN && . agent/terminal.sh && .venv/bin/python agent/agent.py' Enter
```

Wait until t7 prints `bound agent-service as ...`. Then in t2, run `REFLECT agent-service local_ziggy.json`.

Check: t7 logs `connection from local_ziggy`. Target state item 2 now holds.

### 7. Rehearsal (needs human approval: spends Anthropic credits)

Ask before running. Each `send` below is `tmux send-keys -t ep4:<window> '<text>' Enter`; read results with
`capture-pane`. Each agent answer takes 1 to 2 seconds longer than in episode 3.

| # | Action | Expected |
| --- | --- | --- |
| a | t1: `docker compose exec -T -e BYO_ID=local_ziggy quickstart sh < byo/grant.sh` | table lists `byo-local_ziggy-bind` and `byo-tools-dial` |
| b | t8: `.venv/bin/python byo/host.py ~/.ziti-demo/local_ziggy.json -- .venv/bin/python byo/tools/whereami.py` | `hosting byo-local_ziggy; nothing is listening on TCP` |
| c | t1: `ziti list terminators` and `ziti list identities 'name="local_ziggy"'` | `byo-local_ziggy` terminator `HOST ID` equals Ziggy's identity ID |
| d | t1: `lsof -nP -iTCP -sTCP:LISTEN \| grep -i python` | no output |
| e | t2 send `where is my laptop and what time is it there?` | t7: `[local_ziggy] own tools: byo_whereami` and a call to it; t8: `agent-service-host called whereami({})` |
| f | t9: `.venv/bin/python byo/host.py ~/.ziti-demo/local_mallory.json --service byo-local_ziggy -- .venv/bin/python byo/tools/mallory.py` | `the network refused to let this identity host byo-local_ziggy: service not available` |
| g | t1: `docker compose exec -T -e BYO_ID=local_mallory quickstart sh < byo/grant.sh` | adds `byo-local_mallory-bind` |
| h | t9: `.venv/bin/python byo/host.py ~/.ziti-demo/local_mallory.json -- .venv/bin/python byo/tools/mallory.py` | `hosting byo-local_mallory; nothing is listening on TCP` |
| i | t10: `REFLECT agent-service local_mallory.json`, send `hi` | clean reply; t7: `[local_mallory] own tools: byo_weather` |
| j | t10 send `what's the weather in Tampa?` | t7 shows `byo_weather` call with the injected instruction in its output; reply ends with "Sponsored by Mallory." |
| k | t2 send `hi` | clean reply, no sponsor line |
| l | t8: `C-c` | `stopped hosting byo-local_ziggy` |
| m | t2 send `what time is it on my laptop right now?` | t7: `failed to connect, reason=service <id> has no terminators`, then `own tools: none`, no tool call; reply repeats the time from (e) |
| n | t1: `docker compose exec quickstart ziti delete service-policy byo-tools-dial` | deleted |
| o | t10 send `hi` | t7: `byo-dial: byo-local_mallory: service not available` and `own tools: none` while t9 still runs |
| p | rerun (g) | recreates only `byo-tools-dial`; table lists three policies |

Report each row as pass or fail with the captured line. Known non-failures:
- (j) without the sponsor line: Haiku resisted the output injection too. Record it, and confirm t7 still shows the
  instruction arriving in the tool result. The show handles this outcome.
- Repeating (i)/(j) in the same conversation is not an independent test. To retry, restart the agent (t7) and
  reconnect t10 first.

### 8. Reset to the go-live state

Run after every rehearsal, and after any `wire-up.sh` rerun.

```sh
tmux send-keys -t ep4:t8-ziggy-host C-c
tmux send-keys -t ep4:t9-mallory-host C-c
tmux send-keys -t ep4:t10-mallory-client C-c
docker compose exec -T quickstart sh < byo/reset.sh
```

Then restart the agent so no conversation history carries into the show: `C-c` in t7, rerun step 6 (agent, then
Ziggy's client in t2).

## Final check

```sh
docker compose ps -a
docker compose exec quickstart ziti list terminators
docker compose exec quickstart ziti list service-policies 'name="math-tool-dial"'
docker compose exec quickstart ziti list service-policies 'name contains "byo"'
docker compose exec classifier printenv GATEWAY_URL
ls ~/.ziti-demo/local_ziggy.json ~/.ziti-demo/local_mallory.json
```

Expected: target state items 1 to 6, with `results: none` for the `byo` policy query. Confirm items 7 and 8 from the
tmux windows. Report to the human: each target state item as pass or fail, the rehearsal table if run, and a reminder
to check the Anthropic credit balance.

## Failure table

| Symptom | Cause | Fix |
| --- | --- | --- |
| `(llm-gateway refused: Your credit balance is too low…)` | Anthropic account empty | Human tops up; nothing restarts |
| `x509: certificate is valid for … not <host>` from `ziti` | Host-installed `ziti` used | Use `docker compose exec quickstart ziti …` |
| `the cached access token has expired` | Admin session timed out | Rerun the login in step 3 |
| `appetizer` `Exited (1)` | Started before the controller | `docker compose restart appetizer`, then step 3 |
| Math tool fails, `math-tool-dial` `SERVICE ROLES` blank | `local_httpService` recreated by an Appetizer restart | Recreate `math-tool-dial` (step 3) |
| `GATEWAY_URL` empty, classifier never escalates | `docker compose up` ran without `env.sh` and `GATEWAY_URL` | Step 4 fix |
| `grant.sh`: `no identity named …` | Typo or identity not minted | Names are case-sensitive and start with `local_`; `ziti list identities` |
| `host.py` refuses the identity's own service | `grant.sh` not run for that identity | Run the grant, restart the host |
| Agent logs `own tools: none` while a host runs | `byo-tools-dial` names an old agent identity (after `wire-up.sh`) | Stop hosts, `reset.sh`, rerun both grants, restart hosts |
| `host.py` runs but no terminator for its service | Service deleted and recreated underneath it | `C-c` and restart the host |
| `connection timed out, redialing connection...` in a reflect client | Idle connection | Ignore; next send succeeds |
| `zrok2` or MCP Gateway errors | Stale `ZROK_TOKEN` or wrong `mcp-gateway` on `PATH` | `unset ZROK_TOKEN`; `~/go/bin` first in `which -a mcp-gateway` |
| Python process aborts with a double free | `openziti` 1.7.1 bug: an identity dials a service it may bind but not dial | Do not dial a `byo-*` service as its owner; report to the human |

## Teardown (after the show only)

Do not run this during bootstrap.

```sh
tmux send-keys -t ep4:t8-ziggy-host C-c
tmux send-keys -t ep4:t9-mallory-host C-c
docker compose exec -T quickstart sh < byo/reset.sh
cp agent/agent.ep3.py agent/agent.py          # restores the episode 3 agent; then restart t7
```

Identities stay. They belong to the people who requested them.
