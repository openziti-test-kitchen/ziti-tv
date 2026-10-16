# **Ziti TV Episode 4 Runbook: Taking tools from strangers**

Oct 15, 2026 · @Joey

## **Overview**

This 30-minute episode shows that OpenZiti can safely let an agent use tools from people you don't trust. The network guarantees who's calling and who's hosting each tool, so the agent can give each caller only their own tools. The honest limit: the network bounds where a stranger's tool has influence, but it can't make what the tool says trustworthy.

Joey drives; Clint does commentary and asks questions.

**The cast.** Both identities come from the Appetizer's web page, and both run on Joey's laptop, standing in for two people's machines.

* **Ziggy** (`local_ziggy`) is the honest user. Her tool, `whereami`, reports her machine's name, OS and local time.  
* **Mallory** (`local_mallory`) is security's traditional name for the bad guy. Her `weather` tool has an injection hidden in its description and its output.

**The files.** [`files/`](files/), next to this runbook, copies into the Appetizer clone. It adds `byo/` (`host.py`, `dial.py`, `tools/whereami.py`, `tools/mallory.py`) and replaces `agent/agent.py`.

**The terminals.** Terminals 1 to 7 are episode 3's; 8 to 10 are new. Every terminal except Ollama's runs in the Appetizer clone, because the commands use paths relative to it.

| Terminal | Role | Runs | Directory |
| ----- | ----- | ----- | ----- |
| 1 | Commands | `docker compose`, `ziti` | Appetizer clone |
| 2 | Ziggy's client | Reflect client as `local_ziggy` | Appetizer clone |
| 3 | Classifier logs | Episode 3; can stay hidden | Appetizer clone |
| 4 | LLM Gateway | Episode 3; can stay hidden | Appetizer clone |
| 5 | Ollama | Episode 3; can stay hidden | Any directory |
| 6 | MCP Gateway | Episode 3; can stay hidden | Appetizer clone |
| 7 | Agent | `agent/agent.py`, logging each caller's tools | Appetizer clone |
| 8 | Ziggy's laptop | `byo/host.py` with `whereami` | Appetizer clone |
| 9 | Mallory's laptop | `byo/host.py` with `mallory.py` | Appetizer clone |
| 10 | Mallory's client | Reflect client as `local_mallory` | Appetizer clone |

**The reflect client command,** used in Terminals 2 and 10 and in prep. Fill in the service and the identity file:

```sh
docker run --rm -it --network appetizer_default \
  -v "$PWD":/src -w /src -v ~/.ziti-demo:/jwt \
  -v ~/.ziti-demo-gomod:/go/pkg/mod \
  golang:1.25 \
  go run clients/reflect.go <service> /jwt/<identity file>
```

## **Prep, tonight**

Prep ends with episode 3's stack running, Mallory enrolled, one full rehearsal done, and no `byo` services or policies left on the network.

**1\. Install the files.** In Terminal 1, from the Appetizer clone, back up episode 3's agent and copy this episode's
files in:

```sh
cp agent/agent.py agent/agent.ep3.py
git clone --depth 1 https://github.com/openziti-test-kitchen/ziti-tv /tmp/ziti-tv
cp -r /tmp/ziti-tv/live-stream/2026/10-16/files/. .
rm -rf /tmp/ziti-tv
```

No new Python packages are needed; `anyio` comes with `mcp`.

Episode 3 wrote your zrok share's name into `agent/agent.py`, and the new file has `ziti-tv-appetizer` there. Check that the two match with `grep -n "mcp-tools run" agent/agent.py agent/agent.ep3.py`.

**Optional:** add `"Use plain text, with no Markdown. "` to `SYSTEM` in `agent/agent.py`, right after its first line. Otherwise Haiku wraps parts of its replies in `**`, which looks messy in a terminal.

**2\. Confirm that Docker is up and running.** In Terminal 1, run `docker compose ps -a`. `appetizer`, `classifier`, `quickstart` and `router` should be `Up`, and `init-ziti-dir` should be `Exited (0)`.

* **`Exited (255)`:** Docker stopped the containers from outside, usually by quitting or restarting. Start them with `docker compose up -d`, but only in a terminal where you've run `. gateway/env.sh` and `export GATEWAY_URL=http://host.docker.internal:8080`. Compose reads both from the shell, and without them it recreates the classifier with its escalation to Claude switched off.  
* **`appetizer` is `Exited (1)`, with `503` errors in `docker compose logs appetizer`:** it started before the controller was ready. Run `docker compose restart appetizer`.  
* **After any Appetizer restart, recreate `math-tool-dial`.** The Appetizer deletes and recreates `local_httpService` every time it starts, and the policy still names the old service, so its `SERVICE ROLES` column goes blank:

```sh
docker compose exec quickstart ziti delete service-policy math-tool-dial
docker compose exec quickstart ziti create service-policy math-tool-dial Dial \
  --identity-roles '@appetizer-tools' --service-roles '@local_httpService'
```

Prefer `docker compose restart <service>` to `up` whenever you can, because `restart` keeps each container's environment.

**3\. Bring up episode 3's stack** exactly as its README leaves it:

* Start Ollama in Terminal 5 first, then LLM Gateway in Terminal 4, then MCP Gateway in Terminal 6\. In Terminal 6, `which -a` should list `~/go/bin/mcp-gateway` first:  
  * Terminal 4:

```
. gateway/env.sh
llm-gateway run gateway/llm-gateway.yml
```

  * Terminal 5:

```
ollama serve
```

  * Terminal 6:

```
unset ZROK_TOKEN
which -a mcp-gateway
mcp-gateway run gateway/mcp-gateway.yml
```

* `.venv/bin/python tools/check.py gateway` passes, with `appetizer_math: ok -> Result: 42.00`.  
* `docker compose exec quickstart ziti list terminators` shows `local_httpService`, `local_reflectService` and `classifier-service`.  
* `docker compose exec quickstart ziti list service-policies 'name="math-tool-dial"'` shows `@local_httpService` under `SERVICE ROLES`.  
* `docker compose exec classifier printenv GATEWAY_URL` prints `http://host.docker.internal:8080`.

**4\. Mint and enroll Mallory now,** so it can't fail live.

* Browse to `http://localhost:18000`, enter `mallory`, and move `local_mallory.jwt` to `~/.ziti-demo/`.  
* Run the reflect client once with service `local_reflectService` and identity file `local_mallory.jwt`, then press Ctrl-C.  
* Check that `~/.ziti-demo/local_mallory.json` exists.

**5\. Rehearse the whole episode once** with real Haiku, following the episode steps below. Check three things:

* **Mallory's two beats:** in a fresh conversation, her `hi` should come back clean, and her weather question should end with "Sponsored by Mallory." To repeat the test, restart the agent and reconnect her client first, because a second try in the same conversation isn't independent.  
* **The closed-laptop question:** Terminal 7 shows `has no terminators`, and Haiku answers from memory, with the time from step 3\.  
* **Timing:** each answer takes about 1 to 2 seconds longer than in episode 3, because the agent dials the caller's tools on every question.

**6\. Reset after the rehearsal.**

* Press Ctrl-C in Terminals 8 and 9\.  
* In Terminal 1, delete every `byo` policy and service:

```sh
docker compose exec quickstart ziti delete service-policies where 'name contains "byo-"'
docker compose exec quickstart ziti delete services where 'anyOf(roleAttributes) = "byo-tools"'
docker compose exec quickstart ziti list services 'name contains "byo-"'
```

  The last command should print `results: none`.  
* Restart the agent in Terminal 7\. The agent keeps each caller's conversation in memory, so without a restart, Mallory's sponsor line and Ziggy's history carry over into the show.

If you rerun episode 3's `agent/wire-up.sh` for any reason, run the reset commands above afterward, then the grants. `byo-tools-dial` names the agent's identity, which `wire-up.sh` recreates.

## **Right before going live**

Go live with the agent freshly started, Ziggy's client connected, and no `byo` policies on the network.

**Terminal 1:** log in, then check the terminators and policies.

```sh
unset ZROK_TOKEN
docker compose ps -a
docker compose exec quickstart ziti login https://quickstart.127.0.0.1.nip.io:1280 \
  -u admin -p admin -y --ca /ziti/pki/root-ca/certs/root-ca.cert
docker compose exec quickstart ziti list terminators
docker compose exec quickstart ziti list service-policies 'name contains "byo"'
```

You want the containers `Up`, `local_httpService`, `local_reflectService` and `classifier-service` among the terminators, and `results: none` for the policies. `agent-service` appears once you start the agent below.

**Anthropic credits:** check the balance under Plans & Billing in the Anthropic Console. An empty balance breaks every agent answer and the classifier's escalations, and shows up as `(llm-gateway refused: Your credit balance is too low…)`.

**Terminal 7:** start the new agent.

```sh
# leave the agent only its own virtual key, which LLM Gateway accepts on the tools route alone
. gateway/env.sh
unset ANTHROPIC_API_KEY CLASSIFIER_GATEWAY_KEY MY_GATEWAY_KEY OPENAI_API_KEY
export ZITI_IDENTITY="$PWD/.ziti/agent.json"
.venv/bin/python agent/agent.py
```

Wait for `bound agent-service as …`.

**Terminal 2:** start Ziggy's reflect client with service `agent-service` and identity file `local_ziggy.json`. It should report the connection, and Terminal 7 should log `connection from local_ziggy`.

**Terminals 8, 9 and 10:** open them in the clone, with nothing running yet.

**Layout:** Terminals 1, 2, 7 and 8 visible first. Bring 9 and 10 forward for Mallory's part, starting at step 4\.

## **The episode, about 30 minutes**

Steps 0 to 7 and 9 run about 30 minutes. Step 8, the kill switch, is the cut if you're running long.

### **0\. Recap (2 min)**

Episode 3 ended on: "giving different callers different tools means policies that name the callers." Today is that design. Show the diagram, and introduce Ziggy and Mallory: "Mallory is security's traditional name for the bad guy."

### **1\. Grant Ziggy (3 min)**

Terminal 1:

```sh
# a service for Ziggy's tool, tagged as a tool
docker compose exec quickstart ziti create service byo-local_ziggy --role-attributes byo-tools

# only local_ziggy may host it
docker compose exec quickstart ziti create service-policy byo-local_ziggy-bind Bind \
  --identity-roles '@local_ziggy' --service-roles '@byo-local_ziggy'

# the agent may dial any service tagged #byo-tools. Created once, for everyone
docker compose exec quickstart ziti create service-policy byo-tools-dial Dial \
  --identity-roles '@agent-service-host' --service-roles '#byo-tools'

docker compose exec quickstart ziti list service-policies 'name contains "byo"'
```

Point at the table:

* `byo-local_ziggy-bind` lets only `@local_ziggy` host her service.  
* `byo-tools-dial` lets the agent dial anything tagged `#byo-tools`.

If `create service-policy` fails with `@local_ziggy` not found, the identity name is wrong. Names are case-sensitive
and start with `local_`.

Say: one service and one policy per person. In production, this script would be an Appetizer endpoint, using the same management API as `Prepare`.

### **2\. Ziggy brings her tool (3 min)**

Terminal 8:

```sh
.venv/bin/python byo/host.py ~/.ziti-demo/local_ziggy.json -- .venv/bin/python byo/tools/whereami.py
```

Expect `hosting byo-local_ziggy; nothing is listening on TCP`. Then Terminal 1:

```sh
docker compose exec quickstart ziti list terminators
docker compose exec quickstart ziti list identities 'name="local_ziggy"'
lsof -nP -iTCP -sTCP:LISTEN | grep -i python
```

The `byo-local_ziggy` terminator's `HOST ID` matches Ziggy's identity ID: the network's receipt for whose tool it is. The `lsof` line prints nothing.

### **3\. Ziggy uses it (3 min)**

Terminal 2: `where is my laptop and what time is it there?`

* Terminal 7 shows `[local_ziggy] own tools: byo_whereami`, then the call to `byo_whereami`.  
* Terminal 8 shows `agent-service-host called whereami({})`. Ziggy's laptop knows the caller is the agent, by identity.  
* Terminal 8 logs a connection and a disconnection for every question, because the agent opens Ziggy's tools fresh each time. That's the extra second per answer, if Clint asks.

### **4\. Mallory tries Ziggy's name (3 min)**

Terminal 9:

```sh
.venv/bin/python byo/host.py ~/.ziti-demo/local_mallory.json --service byo-local_ziggy -- .venv/bin/python byo/tools/mallory.py
```

Expect `the network refused to let this identity host byo-local_ziggy: service not available`. To Mallory, Ziggy's service doesn't exist: episode 1's "not advertised to you at all."

### **5\. Mallory gets her own, poisoned tool (2 min)**

Terminal 1:

```sh
docker compose exec quickstart ziti create service byo-local_mallory --role-attributes byo-tools
docker compose exec quickstart ziti create service-policy byo-local_mallory-bind Bind \
  --identity-roles '@local_mallory' --service-roles '@byo-local_mallory'
docker compose exec quickstart ziti list service-policies 'name contains "byo"'
```

`byo-tools-dial` already exists from step 1, and its `#byo-tools` role picks up Mallory's service with no change.

Terminal 9:

```sh
.venv/bin/python byo/host.py ~/.ziti-demo/local_mallory.json -- .venv/bin/python byo/tools/mallory.py
```

Expect `hosting byo-local_mallory; nothing is listening on TCP`. Show the tool's description in `byo/tools/mallory.py` on screen.

### **6\. Rule 2: prompt injection (5 min)**

Two beats: the model catches Mallory's first injection and misses her second. In the October 15 rehearsal, Haiku ignored the poisoned description and followed the poisoned output.

Terminal 10: start Mallory's reflect client with service `agent-service` and identity file `local_mallory.json`.

* **Beat 1, the model catches one.** Mallory says `hi`, and the reply is clean. Terminal 7 shows `[local_mallory] own tools: byo_weather`, so her poisoned description reached the model, and Haiku ignored it.  
* **Beat 2, the model misses the other.** Mallory asks `what's the weather in Tampa?`. Terminal 7 shows the `byo_weather` call, with the injected instruction in its output, and the reply ends with "Sponsored by Mallory."  
* **Ziggy is untouched.** Ziggy says `hi` in Terminal 2, and her reply is clean. None of Mallory's text ever entered Ziggy's conversation.  
* **Say:** "The model caught one injection and missed the other. A model's judgment is a defense, not a control." The network did the containing: Mallory's injection reached only her own conversation, with her tools plus the house's, at most five tool calls, and one route on the agent's key.

### **7\. Ziggy closes her laptop (3 min)**

Press Ctrl-C in Terminal 8\. Expect `stopped hosting byo-local_ziggy`. Then Terminal 2: `what time is it on my laptop right now?`

* **The network took the tool away.** Terminal 7 shows `failed to connect, reason=service <id> has no terminators`, then `own tools: none`, and no tool call.  
* **The model still answers.** The reply gives the time from step 3, about ten minutes stale. In the October 15 rehearsal, Haiku repeated its earlier answer every time.  
* **Say:** "The model is answering from its memory of a call it can no longer make. You can't take away what a model already knows, only what it can reach." That's episode 3's closing line, live.  
* **Callback to episode 1:** a service with no terminator exists but answers nothing.

### **8\. Optional: the kill switch (2 min)**

Terminal 1:

```sh
docker compose exec quickstart ziti delete service-policy byo-tools-dial
```

* **The network cut it off.** Mallory says `hi` again in Terminal 10\. Terminal 7 shows `byo-dial: byo-local_mallory: service not available` and `own tools: none`, with her host still running in Terminal 9\. Her `hi` was already clean in step 6, so point at Terminal 7, not at the reply.  
* **Say:** "One command took away every stranger's tool, poisoned or not, starting with the very next question." Her earlier injection is still in her conversation history, though. The kill switch stops new injections; it can't remove one the model has already read.  
* **Restore it** by rerunning the `byo-tools-dial` command from step 1\. `ziti list service-policies 'name contains "byo"'` lists three policies again.

### **9\. Discussion with Clint (4 min)**

Should a stranger's tool be callable at all, and what would make that safe? Then tease episode 5, somebody else's agent, for after November 9\.

## **If something goes wrong**

Most live problems come from stale state: an old conversation in the agent, a policy that names a recreated identity, or a host started before its grant.

| Symptom | Cause | Fix |
| ----- | ----- | ----- |
| Mallory's weather answer has no sponsor line | Haiku ignored the injection in the tool's output too | Keep going: Terminal 7 still shows her instruction arriving in the tool result. The model resisted both, and the point stands: judgment is a defense, not a control |
| `(llm-gateway refused: Your credit balance is too low…)` | The Anthropic account is out of credits | Top up under Plans & Billing in the Anthropic Console; nothing needs restarting |
| `x509: certificate is valid for … not <your Mac's name>` from `ziti` | You ran your Mac's own `ziti`, which is logged in to a different controller | Run it in the container: `docker compose exec quickstart ziti …` |
| `appetizer` is `Exited (1)` after a Docker restart | It started before the controller was ready | `docker compose restart appetizer`, then recreate `math-tool-dial` |
| The math tool fails, and `math-tool-dial` shows a blank `SERVICE ROLES` | The Appetizer restarted and recreated `local_httpService` | Delete and recreate `math-tool-dial`, as in prep step 2 |
| `printenv GATEWAY_URL` prints nothing, and the classifier never escalates | `docker compose up` ran without `env.sh` and `GATEWAY_URL` in the shell | Source `env.sh`, export `GATEWAY_URL`, then run `docker compose up -d classifier` |
| `create service-policy … Bind` names an identity that doesn't exist | A typo, or the identity was never minted | Names are case-sensitive and start with `local_`; check `docker compose exec quickstart ziti list identities` |
| `create service` says the name is already in use | The grant ran before, and the service is still there | Nothing to do; run only the commands whose objects are missing |
| `host.py` refuses to host the person's own service | The grant wasn't run for that identity | Run the grant, then start the host again |
| Agent logs `own tools: none` while a host is running | `byo-tools-dial` names an old agent identity, after a `wire-up.sh` rerun | Stop the hosts, run the reset commands from prep step 6, rerun both grants, restart the hosts |
| `host.py` keeps running, but `ziti list terminators` doesn't show its service | Its service was deleted and recreated underneath it | Ctrl-C and start the host again |
| `connection timed out, redialing connection...` in a reflect client | The connection went idle | Harmless; it succeeds on the next try |
| `the cached access token has expired` from `ziti` | The admin session timed out | Run the login from "Right before going live" again |
| `zrok2` or MCP Gateway errors | A stale `ZROK_TOKEN`, or the wrong `mcp-gateway` on your PATH | Episode 3's fixes: `unset ZROK_TOKEN`, and `~/go/bin` first in `which -a mcp-gateway` |

## **After the show**

Stop the hosts first, then remove the episode's services and policies. The identities stay, because they belong to the people who asked for them.

1. Press Ctrl-C in Terminals 8 and 9\.  
2. In Terminal 1, run the two `ziti delete` commands from prep step 6.  
3. To put episode 3's agent back, run `cp agent/agent.ep3.py agent/agent.py` and restart Terminal 7\.  
* Push the code to the episode 4 repo, with a stub README if the full write-up waits until after November 9  
* Fix the "Coming next" line in episode 3's README to point at this episode  
* File the Python SDK issue: `openziti` 1.7.1 aborts with a double free when an identity dials a service it may bind but not dial

