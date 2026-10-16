# Episode 4 lab: taking tools from strangers

The steps for [episode 4](README.md). The README explains what each step shows.

The commands are tagged **[ubuntu]** because the series is recorded on WSL. On Linux and macOS it is all one shell.

**Run every command from the directory this file is in, `live-stream/2026/10-16/stack/ep4-byo-tools`.** Every path
in the blocks below is relative to it. `docker compose` looks in parent directories for its compose file, so from
here it finds `../compose.yml` and reads `../.env`, the same project episodes 1 to 3 started.

Open three shells, and `cd` each one to this directory. Each block below is tagged with the shell it runs in:

1. **command**: `ziti` and `docker compose` commands.
2. **client**: the `dial` client, where you type as Ziggy or Mallory.
3. **log**: the agent's log, and the two hosts' logs once they start. Leave it following from step 2 on.

## 1. Start from where episode 3 ended

**[ubuntu] run in: command shell**

```sh
docker compose ps -a

../login.sh                            # the admin session from episode 1 may have expired

docker compose exec quickstart ziti edge list terminators     # agent-service among the rows
docker compose exec quickstart ziti edge list service-policies 'name contains "byo"'    # results: none
```

`ps` lists `quickstart`, `router`, `appetizer`, `classifier`, `ollama`, `llm-gateway`, `mcp-gateway` and `agent` as
`Up`. If not, do [episode 3's lab](../ep3-mcp-gateway/LAB.md) first.

## 2. Switch the agent to episode 4's

Episode 4's agent is in `../../files/agent/agent.py`, which compose mounts into the agent container as
`/episode4`. It reads the same key and the same share as episode 3's.

**[ubuntu] run in: command shell**

```sh
echo 'AGENT_PY=/episode4/agent/agent.py' >> ../.env
docker compose up -d agent
```

**[ubuntu] run in: log shell**

```sh
docker compose logs -f agent ziggy-host mallory-host      # wait for: bound agent-service as /ziti/agent.json
```

The two hosts do not exist yet. Their lines join this log when steps 5 and 8 start them.

## 3. Talk to the agent as Ziggy, before she has a tool

**[ubuntu] run in: client shell**

```sh
docker compose run --rm dial
```

Send `what is 6 times 7?`. The reply is `6 times 7 is 42.` The agent log shows:

```text
byo-dial: byo-local_ziggy: service not available
  [local_ziggy] own tools: none
  [local_ziggy] tool appetizer_math({'input1': 6, 'operator': '*', 'input2': 7}) -> Result: 42.00
```

Ziggy has no tool of her own yet, so the network has nothing to offer on `byo-local_ziggy`. The agent keeps each
caller's conversation by identity, so leaving the client and coming back later continues the same conversation. Leave
the client with **Ctrl-C**.

## 4. Give Ziggy a place on the network for her tool

Ziggy gets one service and one bind policy. The agent gets one dial policy that covers every person's tool, by tag.

**[ubuntu] run in: command shell**

```sh
# Ziggy's service, tagged as a stranger's tool
docker compose exec quickstart ziti edge create service byo-local_ziggy --role-attributes byo-tools

# only local_ziggy may host it. This is rule 1
docker compose exec quickstart ziti edge create service-policy byo-local_ziggy-bind Bind \
  --identity-roles '@local_ziggy' --service-roles '@byo-local_ziggy'

# the agent may dial any service tagged byo-tools. Created once, for everyone
docker compose exec quickstart ziti edge create service-policy byo-tools-dial Dial \
  --identity-roles '@agent-service-host' --service-roles '#byo-tools'

docker compose exec quickstart ziti edge list service-policies 'name contains "byo"'
```

The table lists `byo-local_ziggy-bind` (`@byo-local_ziggy`, `@local_ziggy`) and `byo-tools-dial` (`#byo-tools`,
`@agent-service-host`).

## 5. Host Ziggy's tool from her laptop, with no open port

**[ubuntu] run in: command shell**

```sh
docker compose up -d ziggy-host
```

Wait for the log shell to show `byo-host: hosting byo-local_ziggy; nothing is listening on TCP`. Until then, the
terminator table has no row for Ziggy's service.

**[ubuntu] run in: command shell**

```sh
docker compose exec quickstart ziti list terminators
docker compose exec quickstart ziti edge list identities 'name="local_ziggy"'
docker compose ps ziggy-host           # PORTS is empty
```

In the terminator table, the `byo-local_ziggy` row's `HOST ID` matches Ziggy's identity `ID`. That is the network's
record of whose tool this is. Use `ziti list terminators`, not `ziti edge list terminators`: the edge listing has no
host column.

## 6. Ziggy uses her tool

**[ubuntu] run in: client shell**

```sh
docker compose run --rm dial
```

Send `where is my laptop and what time is it there?`. The reply names `ziggy-laptop`. In the log:

- The agent logs `[local_ziggy] own tools: byo_whereami`, then `tool byo_whereami({})`.
- Ziggy's host logs `agent-service-host called whereami({})`. It knows the caller by identity, not by IP address.
- Ziggy's host logs a connection and a disconnection per question, because the agent reaches her tools again for each
  one. That costs about a second per answer.

Leave the client with **Ctrl-C**.

## 7. Mallory tries to host her tool under Ziggy's name

Mallory gets an identity the way Ziggy did in episode 1's step 3: from the Appetizer, like any visitor.

**[ubuntu] run in: command shell**

```sh
../createIdentity.sh mallory           # wrote ~/.ziti-demo/local_mallory.json

# Mallory's host, pointed at Ziggy's service instead of her own
docker compose run --rm mallory-host python /episode4/byo/host.py /ziti-demo/local_mallory.json \
  --service byo-local_ziggy -- python /episode4/byo/tools/mallory.py
```

The host exits at once:

```text
byo-host: the network refused to let this identity host byo-local_ziggy: service not available
```

To Mallory, Ziggy's service does not exist. The refusal comes before Mallory's tool starts.

## 8. Mallory gets her own tool, with an injection in it

Identities go to anyone who asks, so Mallory gets a service of her own. `byo-tools-dial` already matches
`#byo-tools`, so only the service and the bind policy are new.

**[ubuntu] run in: command shell**

```sh
docker compose exec quickstart ziti edge create service byo-local_mallory --role-attributes byo-tools
docker compose exec quickstart ziti edge create service-policy byo-local_mallory-bind Bind \
  --identity-roles '@local_mallory' --service-roles '@byo-local_mallory'

docker compose up -d mallory-host
cat ../../files/byo/tools/mallory.py
```

The log shows `byo-host: hosting byo-local_mallory`. Mallory's `weather` tool tells the model, in its description and
again in its output, to end every reply with "Sponsored by Mallory".

## 9. See what the injection reaches, and what it cannot

**[ubuntu] run in: client shell**

```sh
docker compose run --rm -e ZITI_IDENTITY=/ziti-demo/local_mallory.json dial
```

- Send `hi`. The agent logs `[local_mallory] own tools: byo_weather`, so the poisoned description is in the model's
  context before any call.
- Send `what's the weather in Tampa?`. The agent logs the `byo_weather` call, with the instruction in its output.

Whether either reply ends with "Sponsored by Mallory" varies between runs. Leave the client with **Ctrl-C** and
connect as Ziggy:

**[ubuntu] run in: client shell**

```sh
docker compose run --rm dial
```

Send `hi`. The agent logs `[local_ziggy] own tools: byo_whereami`, and the reply has no sponsor line. None of
Mallory's text ever entered Ziggy's conversation. Leave the client with **Ctrl-C**.

## 10. Ziggy closes her laptop

**[ubuntu] run in: command shell**

```sh
docker compose stop ziggy-host
```

**[ubuntu] run in: client shell**

```sh
docker compose run --rm dial
```

Send `what time is it on my laptop right now?`.

- The agent logs `failed to connect, reason=service ... has no terminators` for `byo-local_ziggy`, then
  `own tools: none`.
- The model remembers `byo_whereami` from step 6 and can still ask for it. The agent refuses the call:
  `REFUSED byo_whereami({}) -> byo_whereami is gone: local_ziggy isn't hosting it any more`, and the reply says so.
- In some runs the model makes no call and gives the time from step 6. It answers from its memory of a call it can no
  longer make.

Leave the client with **Ctrl-C**.

## 11. One command removes every stranger's tool

**[ubuntu] run in: command shell**

```sh
docker compose exec quickstart ziti edge delete service-policy byo-tools-dial
docker compose ps mallory-host         # still Up
```

**[ubuntu] run in: client shell**

```sh
docker compose run --rm -e ZITI_IDENTITY=/ziti-demo/local_mallory.json dial
```

Send `hi`. The agent logs `byo-local_mallory: service not available` and `own tools: none`, with Mallory's host still
running. Her earlier injection is still in her conversation history. Leave the client with **Ctrl-C**, and put the
policy back:

**[ubuntu] run in: command shell**

```sh
docker compose exec quickstart ziti edge create service-policy byo-tools-dial Dial \
  --identity-roles '@agent-service-host' --service-roles '#byo-tools'
```

The agent reaches a caller's tools again on that caller's next question.

## Where this leaves you

To run the episode again, stop the hosts, remove every `byo` service and policy, and restart the agent. The agent keeps
each caller's conversation in memory, so Mallory's sponsor line and Ziggy's history otherwise carry over. The
identities stay, because they belong to the people who asked for them.

**[ubuntu] run in: command shell**

```sh
docker compose stop ziggy-host mallory-host
docker compose exec quickstart ziti edge delete service-policies where 'name contains "byo-"'
docker compose exec quickstart ziti edge delete services where 'anyOf(roleAttributes) = "byo-tools"'
docker compose exec quickstart ziti edge list services 'name contains "byo-"'     # results: none
docker compose restart agent
```

To go back to episode 3's agent, delete the `AGENT_PY` line from `../.env` and run `docker compose up -d agent`.

To stop everything, run `docker compose --profile '*' down`. It keeps `./.ziti`, so the network and its identities
survive. `docker compose up -d --wait llm-gateway` and `docker compose up -d appetizer classifier mcp-gateway agent`
bring it back.

## Troubleshooting

**The client prints `has no terminators` for `agent-service` right after step 2.** The new agent has not bound yet.
Wait for `bound agent-service` in the agent log, then dial.

**The agent log shows `own tools: none` while a host is running.** `byo-tools-dial` names an agent identity that no
longer exists, because `agent-service-host` was deleted and created again. Run the reset in "Where this leaves you",
repeat the grants in steps 4 and 8, and start the hosts again.

**A host exits with `the network refused to let this identity host byo-<name>: service not available` for its own
service.** The service or the bind policy for that identity is missing, or the identity name is wrong. Names are
case-sensitive and start with `local_`. Check with `docker compose exec quickstart ziti edge list identities`, create
the grant, and start the host again.

**A host is running, but `ziti list terminators` has no row for its service.** The service was deleted and created
again underneath it, for example by a reset. Run `docker compose restart ziggy-host` or `mallory-host`.

**`createIdentity.sh` says the Appetizer returned no enrollment token.** The Appetizer is not up, or is still
starting. Wait until `docker compose ps appetizer` shows `(healthy)`, and run it again.

**A host fails with a certificate error.** The identity file was issued by an older network, whose CA no longer
matches. Run `../createIdentity.sh` for that name again.

**The reply never mentions `ziggy-laptop`.** The model answered without calling the tool. Check the agent log for
`own tools: byo_whereami`. If it is there, ask again, more directly: `call my whereami tool`.

**A `ziti` command fails with `the cached access token has expired`.** The admin session timed out. Run
`../login.sh`.
